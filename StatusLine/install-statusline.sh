#!/bin/sh
# Claude Code status line installer.
#
# Installs a status line that renders:
#   ~/src | main | 9% | S:37% | W:17% | Opus 5
#   dir   branch  ctx  5h-quota weekly  model
#
# Safe to re-run. Existing settings.json keys are preserved; only "statusLine"
# is added or replaced. Any previous settings.json is backed up first.
#
# Usage:  sh install-statusline.sh

set -eu

CLAUDE_DIR="$HOME/.claude"
SCRIPT_PATH="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# ---------------------------------------------------------------- the script
# Quoted heredoc: nothing below is expanded at install time, so $HOME, $input
# and the escape sequences land in the file verbatim.
cat > "$SCRIPT_PATH" <<'STATUSLINE_EOF'
#!/bin/sh
# Claude Code statusLine script
# Prints: cwd (abbreviated with ~) | git branch (if inside a repo) | context % |
# session quota (S:%) | weekly quota (W:%) | model display name

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
  model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
  ctx_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
  # rate_limits.*.used_percentage is a float and 0 is a valid reading, so the presence check
  # is an explicit "!= null" test (not "// empty", which would still keep 0, and not a shell
  # truthiness test later, which would wrongly drop "0"). floor() (not round()) is used so a
  # quota only reads "100%" once it has genuinely reached 100 -- round() would turn 99.5 into
  # a misleading "100%" while some headroom remains.
  session_pct=$(printf '%s' "$input" | jq -r 'if (.rate_limits.five_hour.used_percentage != null) then (.rate_limits.five_hour.used_percentage | floor) else empty end')
  weekly_pct=$(printf '%s' "$input" | jq -r 'if (.rate_limits.seven_day.used_percentage != null) then (.rate_limits.seven_day.used_percentage | floor) else empty end')
else
  # Portable fallback when jq is not installed (single-line JSON assumed)
  dir=$(printf '%s' "$input" | sed -n 's/.*"current_dir" *: *"\([^"]*\)".*/\1/p' | head -n 1)
  [ -z "$dir" ] && dir=$(printf '%s' "$input" | sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' | head -n 1)
  model=$(printf '%s' "$input" | sed -n 's/.*"display_name" *: *"\([^"]*\)".*/\1/p' | head -n 1)
  # used_percentage appears in both context_window and rate_limits.* (five_hour/seven_day/
  # spend_limit), and a bare greedy match takes the LAST occurrence in the line, which would
  # silently grab a rate_limits value instead of context_window's. context_window is serialized
  # before rate_limits, so everything from "rate_limits" onward is stripped first, leaving only
  # context_window's own used_percentage to match. JSON null (unquoted, no digits) still never
  # matches, so the context segment is correctly omitted in that case, same as before.
  ctx_source=$(printf '%s' "$input" | sed 's/"rate_limits".*//')
  ctx_pct=$(printf '%s' "$ctx_source" | sed -n 's/.*"used_percentage" *: *\([0-9][0-9]*\).*/\1/p' | head -n 1)
  # rate_limits.five_hour/seven_day are nested objects whose key "used_percentage" collides
  # with context_window.used_percentage under single-line key matching, so both quota segments
  # are deliberately omitted here rather than risk printing a value pulled from the wrong object.
  session_pct=""
  weekly_pct=""
fi

branch=""
if [ -n "$dir" ] && git --no-optional-locks -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks -C "$dir" branch --show-current 2>/dev/null)
fi

display_dir=$dir
case "$display_dir" in
  "$HOME") display_dir="~" ;;
  "$HOME"/*) display_dir="~${display_dir#"$HOME"}" ;;
esac

ctx=""
[ -n "$ctx_pct" ] && ctx="${ctx_pct}%"

# "-n" is a string-emptiness test, not a truthiness test, so a floored "0" (a real 0% reading)
# still counts as present here and is not dropped the way an arithmetic truthy check would drop it.
session=""
[ -n "$session_pct" ] && session="S:${session_pct}%"

weekly=""
[ -n "$weekly_pct" ] && weekly="W:${weekly_pct}%"

dim=$(printf '\033[2m')
reset=$(printf '\033[0m')
sep="${dim}|${reset}"

out="$display_dir"
[ -n "$branch" ] && out="$out $sep $branch"
[ -n "$ctx" ] && out="$out $sep $ctx"
[ -n "$session" ] && out="$out $sep $session"
[ -n "$weekly" ] && out="$out $sep $weekly"
[ -n "$model" ] && out="$out $sep $model"

printf '%s' "$out"
STATUSLINE_EOF

chmod +x "$SCRIPT_PATH"
echo "wrote  $SCRIPT_PATH"

# ------------------------------------------------------------- settings.json
# The command is written with an absolute path computed from THIS machine's
# $HOME. Claude Code is not confirmed to expand $HOME inside this string, and a
# path that fails to resolve produces an empty status line with no error, so the
# safe form is a literal path resolved at install time.
COMMAND="sh $SCRIPT_PATH"

if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  echo "backup $BACKUP"
else
  printf '{}\n' > "$SETTINGS"
fi

TMP="$SETTINGS.tmp.$$"

if command -v jq >/dev/null 2>&1; then
  jq --arg cmd "$COMMAND" \
     '.statusLine = {"type":"command","command":$cmd}' \
     "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "patched $SETTINGS (via jq)"
elif command -v python3 >/dev/null 2>&1; then
  SETTINGS="$SETTINGS" COMMAND="$COMMAND" python3 - <<'PY'
import json, os
path = os.environ["SETTINGS"]
with open(path) as fh:
    text = fh.read().strip() or "{}"
data = json.loads(text)
data["statusLine"] = {"type": "command", "command": os.environ["COMMAND"]}
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
  echo "patched $SETTINGS (via python3)"
else
  rm -f "$TMP"
  echo
  echo "!! Neither jq nor python3 found, so settings.json was NOT modified."
  echo "!! Add this block to $SETTINGS by hand:"
  echo
  echo '   "statusLine": {'
  echo '     "type": "command",'
  echo "     \"command\": \"$COMMAND\""
  echo '   }'
  echo
  exit 1
fi

# --------------------------------------------------------------- self-check
echo
echo "verifying..."
PAYLOAD='{"workspace":{"current_dir":"'"$HOME"'/src"},"model":{"display_name":"Opus 5"},"context_window":{"current_usage":{"x":1},"used_percentage":9},"rate_limits":{"five_hour":{"used_percentage":37.4,"resets_at":1},"seven_day":{"used_percentage":17.2,"resets_at":2}}}'
RENDER=$(printf '%s' "$PAYLOAD" | sh "$SCRIPT_PATH")
printf '  sample render: %s\n' "$RENDER"

if ! command -v jq >/dev/null 2>&1; then
  echo
  echo "  NOTE: jq is not installed on this machine."
  echo "  The status line still works, but the S: and W: quota segments will be"
  echo "  absent -- they need jq. Install it (brew install jq / apt install jq)"
  echo "  and they appear on the next session."
fi

echo
echo "Done. The status line appears when you START A NEW Claude Code session"
echo "(the setting is read at startup, not live)."

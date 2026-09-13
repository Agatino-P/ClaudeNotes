# Claude Code Status Line

A status line for Claude Code showing working directory, git branch, context usage, plan quotas, and the active model.

```
~/src | main | 9% | S:37% | W:17% | Opus 5
```

| Segment | Meaning |
|---|---|
| `~/src` | Working directory, home collapsed to `~` |
| `main` | Git branch — green when clean, yellow `main*` when the tree is dirty. Omitted entirely outside a repo. |
| `9%` | How full the context window is right now |
| `S:37%` | Session quota — 5-hour rolling window |
| `W:17%` | Weekly quota — 7-day rolling window |
| `Opus 5` | Active model display name |

## Uncommitted changes

The branch segment doubles as a dirty indicator:

| Working tree | Renders as |
|---|---|
| Clean | `main` in green |
| Uncommitted changes | `main*` in yellow |

Untracked files count as dirty. Both signals carry the same information, so the state still reads on a terminal without color.

Detection is a single `git status --porcelain` piped through `head -n 1`, so it short-circuits instead of enumerating a large diff, and it only runs once the directory is already confirmed to be a repo. Measured cost of a full render including this call is roughly 45 ms.

Colors use standard ANSI SGR codes (`32` green, `33` yellow) rather than fixed RGB, so they follow your terminal palette.

## What the numbers actually mean

The three percentages measure different things and are easy to confuse. Only two of them relate to your plan.

| Shown | Source field | Measures |
|---|---|---|
| `9%` | `context_window.used_percentage` | Share of the context window in use. Falls back toward zero on `/clear` or compaction. Unrelated to billing. |
| `S:37%` | `rate_limits.five_hour.used_percentage` | The 5-hour rolling plan quota. Not this conversation — a wall-clock window. |
| `W:17%` | `rate_limits.seven_day.used_percentage` | The 7-day rolling plan quota. |

Claude Code also exposes `seven_day_opus`, `seven_day_sonnet`, and — gateway accounts only — `spend_limit`. Opus burns its own weekly bucket on top of the general one.

For the full picture at any moment, run `/usage` (aliases `/cost` and `/stats`).

## Install

1. **Copy `install-statusline.sh` to the target machine.** It carries the status line script inside it, so that single file is all you need.

2. **Run it:**

   ```sh
   sh install-statusline.sh
   ```

   It writes `~/.claude/statusline-command.sh`, computes the absolute path for *that* machine's home directory, and patches `~/.claude/settings.json` in place — adding only the `statusLine` key and leaving every other setting untouched. A timestamped backup of the previous settings file is made first. Re-running is safe.

3. **Start a new Claude Code session.** The setting is read at startup, not live, so the bar appears in the next session rather than the one you are in.

## Two things that break a manual copy

### The path in settings.json is absolute

The `command` value is a literal path:

```json
"statusLine": {
  "type": "command",
  "command": "sh /Users/you/.claude/statusline-command.sh"
}
```

On an account with a different username it will not resolve — and a status line command that fails produces an **empty bar with no error**, which is hard to diagnose. Writing `$HOME` there is unverified; the installer sidesteps the question by resolving the real path at install time.

### Without jq, the quota segments vanish

The `S:` and `W:` segments require `jq`. Their fields are nested objects, and the no-`jq` fallback deliberately omits them rather than risk pulling a number from the wrong object — `used_percentage` appears under both `context_window` and `rate_limits`.

Directory, branch, context and model still work without `jq`. Install it (`brew install jq` / `apt install jq`) to get the quotas back. The installer warns if it is missing.

## Verified behavior

Each case below was run against the script with a real payload, not reasoned about.

| Case | Renders | |
|---|---|---|
| Both quotas, in a repo | `~/src \| main \| 8% \| S:0% \| W:45% \| Opus 5` | pass |
| Quota at 99.5% | `W:99%` | pass |
| Quota genuinely at 100% | `W:100%` | pass |
| No `rate_limits` (API key, Bedrock) | `~/src \| main \| 8% \| Opus 5` | pass |
| Only one quota present | `~/src \| main \| 8% \| S:7% \| Opus 5` | pass |
| `spend_limit` present | ignored, as intended | pass |
| Session start, nothing populated | `~ \| Opus 5` | pass |
| No `jq` on PATH | quotas omitted, context correct | pass |
| Clean repo | branch green, no marker | pass |
| Modified file | branch yellow, `main*` | pass |
| Untracked file only | branch yellow, `main*` | pass |
| Detached HEAD | branch segment absent, no stray `*` | pass |

Two rounding details worth knowing:

- A quota uses `floor`, not `round`, so `99.5%` shows as `99%` rather than a misleading `100%`.
- `0%` is treated as a real reading and displayed, not dropped as empty.

## Files

| File | Purpose |
|---|---|
| `install-statusline.sh` | Self-contained installer, with the status line script embedded. This is the one to send. |
| `handoff.md` | This document. |

Once installed, the live copies are `~/.claude/statusline-command.sh` and the `statusLine` block in `~/.claude/settings.json`.

---

Payload field names were read from the Claude Code 2.1.270 binary rather than from documentation. They are correct for that version; a future release could rename them. If a segment silently disappears after an update, that is the first thing to check.

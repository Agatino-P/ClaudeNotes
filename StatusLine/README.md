# StatusLine

A Claude Code status line showing working directory, git branch, context usage, plan quotas and the active model.

```
~/src | main | 9% | S:37% | W:17% | Opus 5
```

## To set this up on another machine

Copy `install-statusline.sh` to that machine and run:

```sh
sh install-statusline.sh
```

That single file is all you need — the status line script is embedded inside it. The installer writes the script to `~/.claude/statusline-command.sh`, resolves the correct absolute path for that machine's home directory, and patches `~/.claude/settings.json` without disturbing existing settings. Start a new Claude Code session to see the bar.

See [`handoff.md`](handoff.md) for what each segment means, the two portability traps, and verified behavior.

# Settings

Notes on individual Claude Code settings — what a key does, when it matters, and the behavior that is not obvious from its name.

Settings live in `~/.claude/settings.json` (user scope) or a project's `.claude/settings.json`. `/config` edits the common ones interactively; anything not exposed there is edited in the file.

| Setting | What it does |
|---|---|
| [`autoContinueAtUsageLimit`](auto-continue-at-usage-limit.md) | Waits out a usage limit and resumes the interrupted task automatically, instead of leaving the session parked on a dialog. |

Details in these notes were read from the shipped Claude Code binary rather than from documentation, with the version and date recorded in each file. Keys and behavior can change between releases — check before relying on one.

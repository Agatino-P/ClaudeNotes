# `autoContinueAtUsageLimit`

Resume an interrupted task automatically once a usage limit resets, instead of leaving the session waiting for you to come back and answer a dialog. Off by default — it does nothing until you turn it on.

```json
// ~/.claude/settings.json
{
  "autoContinueAtUsageLimit": true
}
```

Claude Code's own description of the setting:

> When a claude.ai usage limit stops your session, wait for the limit to reset and continue the task automatically. When off, the limit dialog offers the wait as a choice instead.

## Why it matters

Hitting a limit mid-task normally costs you the gap between when the limit hit and when you next look at the terminal. If it hits while you are asleep or in a meeting, that is hours of dead time on a task that was ready to continue — the limit itself may have reset long before you returned.

With the setting on, the session waits out the reset and picks the task back up on its own.

## It is not Desktop-only

The weekly newsletter announced this as a Claude Code **Desktop** feature, which reads as though the CLI is excluded. It is not. Desktop gained a *checkbox on the limit card* — a UI affordance that needs a UI — while the CLI exposes the same behavior through the settings key above. Same capability, different surface.

Worth remembering that Claude Code Desktop **is** Claude Code: the product ships as a CLI, a desktop app, a web app, and IDE extensions. "On Desktop" in release notes means one surface of Claude Code, not a different product.

## When the automatic continue is cancelled

Arming it is not a guarantee. Claude Code cancels a pending auto-continue in five situations, each with its own message:

| Situation | What happens instead |
|---|---|
| The session moves to the background | Task will not resume on its own |
| Claude Code is relaunched during the wait | Send a prompt after the reset to continue |
| The session moves to Claude Desktop | Continue it there |
| The session is sent to the cloud | Continue it in the cloud session |
| Claude Code exits during the wait | Send a prompt after the reset to continue |

The common thread: the wait lives in the running process. Anything that moves or restarts that process drops it. So this helps with *"I walked away"*, not with *"I quit and came back tomorrow"*.

## Re-arming it

If an automatic continue is cancelled, the session says so and tells you the remedy:

> Automatic continue cancelled. Your session will wait for you instead; `/rate-limit-options` can arm it again.

`/rate-limit-options` ("Show options when rate limit is reached") is a hidden command — it will not appear in the `/` menu, but it runs if you type it. The same menu carries a separate option to continue immediately at lower priority after hitting a session limit, rather than waiting for the reset.

## Seeing a limit coming

This pairs with quota segments in a status line. [`../StatusLine/`](../StatusLine/) renders the 5-hour and 7-day quotas as `S:` and `W:`, so an approaching limit is visible before it stops anything — and with `autoContinueAtUsageLimit` on, hitting one becomes a pause rather than a halt.

## Off by default — you have to enable it

The key is absent from a fresh config, and the behavior you get without it is the *off* behavior: the session stops at the limit and the dialog offers waiting as a choice you have to accept.

Nothing happens automatically until you add the key and set it to `true`. Then start a new session — settings are read at startup, so turning it on mid-session does not affect the session you are in.

---

Verified against the Claude Code 2.1.270 binary on 14 September 2026 — the setting name, its description, the five cancellation cases, and the `/rate-limit-options` command were all read from the shipped build rather than from documentation. A future release could change them.

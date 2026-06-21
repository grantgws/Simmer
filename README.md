# Simmer

Simmer is a lightweight macOS menu bar app that surfaces the live status of your
[Claude Code](https://claude.com/claude-code) sessions. See at a glance whether
Claude is working, waiting on you, or finished — and jump straight to the session
that needs attention.

![Simmer](assets/simmer-demo.gif)

▶ **[Watch the full demo](assets/simmer-promo.mp4)** (with sound)

<video src="https://github.com/grantgws/Simmer/raw/main/assets/simmer-promo.mp4" controls width="100%"></video>

## Features

- **At-a-glance status** in the menu bar — working, action needed, done, or idle.
- **Multiple sessions** tracked at once. The menu bar reflects the most urgent
  session; the dropdown lists every session with its current state.
- **Audible and visual alerts** when a session needs input or finishes.
- **Jump to a session** — click any session to bring its terminal window forward.
- **Local only.** No account, no network, no telemetry. All state stays on your Mac.

## Requirements

- macOS 13 or later
- [Claude Code](https://claude.com/claude-code)
- Xcode (to build from source)

## Install

```sh
gh repo clone grantgws/Simmer && cd Simmer && ./install.sh
```

`install.sh` builds a release binary and installs it to `/Applications`.
Alternatively, open `Simmer.xcodeproj` in Xcode and run.

After installing:

1. Open the menu bar item and choose **Connect to Claude Code**. This registers
   Simmer's hooks in `~/.claude/settings.json`.
2. Restart any running Claude Code sessions so the hooks take effect.
3. Optionally enable **Launch at Login**.

## How it works

Claude Code emits [hooks](https://docs.claude.com/en/docs/claude-code/hooks) on
session events — prompt submitted, tool use, awaiting input, and turn complete.
Simmer installs a small hook script that records each session's state to a
per-session file in `~/.claude/simmer/sessions/`. The app watches that directory
and renders the aggregate status.

Connecting writes Simmer's hooks to `~/.claude/settings.json` (backing the file
up first and refusing to modify it if it can't be parsed). Disconnecting removes
those hooks cleanly, so uninstalling never leaves Claude Code in a broken state.

## Permissions

- **Notifications** — to alert you when a session needs input.
- **Automation (Terminal)** — used only when you click a session to focus its
  terminal window. Simmer can raise a window; it cannot read or type anything.

## Uninstall

Choose **Disconnect from Claude Code** in the menu (this removes Simmer's hooks),
then quit Simmer and move it to the Trash.

## Building and releasing

See [SIGNING.md](SIGNING.md) and [RELEASING.md](RELEASING.md).

## License

[MIT](LICENSE). Not affiliated with or endorsed by Anthropic. "Claude" and
"Claude Code" are trademarks of Anthropic.

# Simmer — brief

A macOS menu bar app that mirrors what Claude Code is doing, in the spirit of
a "Dynamic Island for the Mac."

- **Working** → shows "✳ Simmering…" (cycles cute spinner words)
- **Needs you** → "🔔 Action needed" (permission prompt / waiting on input)
- **Finished** → "✓ Done", then fades back to idle

## How the signal works
The app cannot read Claude Code's internals. Instead:
1. Claude Code **hooks** run `hooks/set-status.sh <state>` on key events.
2. That script writes `~/.claude/menubar-status.json`.
3. The app polls that file twice a second and updates the menu bar.

## Status: v1 menu bar works and builds.
Notch "island" panel is a later phase (a custom borderless window under the
MacBook notch — not an OS feature, has to be drawn by hand).

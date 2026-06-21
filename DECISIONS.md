# Simmer — decisions

- **Xcode project, not script build.** Started as a one-file `swiftc` build;
  switched to a real `.xcodeproj` at Grant's request so it opens/runs in Xcode
  like Grumbly. (2026-06-16)
- **Menu-bar-only app.** `LSUIElement = YES` → lives in the menu bar, no Dock
  icon. Uses SwiftUI `MenuBarExtra` (macOS 13+).
- **File-based signal, not direct integration.** Claude Code has no API to ask
  "what are you doing." Hooks → status file → app polling is the simplest
  reliable bridge, and fully reversible (delete hooks = no trace).
- **"Action needed" = the `Notification` hook.** That event fires precisely when
  Claude Code is waiting on the user (permission or input). Cleanest trigger.
  `Stop` = done; prompt-submit / tool-use = working.
- **Polling at 0.5s**, not file-watching. Trivial cost, no edge cases.
- **Hook marker is slash-free (`set-status.sh`).** Swift's JSONSerialization
  escapes `/` to `\/`, so a slash-containing marker never matches the serialized
  settings. Detection (`isConnected`) and `stripOurHooks` both match `set-status.sh`.
- **Installed hook script is embedded as base64**, decoded on install — avoids
  Swift multiline-literal indentation mangling the embedded Python (that bug
  produced a broken installed script that silently wrote nothing).
- **Connection status is published from the monitor** (re-checked each 0.5s tick)
  so the dropdown shows live "✓ Connected" / "Set up" without manual refresh.
- **settings.json safety:** connect/disconnect back up the file first
  (`settings.simmer-backup.json`) and REFUSE to write if it exists but can't be
  parsed — so a malformed file is never wiped. UI shows a warning in that case.
- **Lightweight update check:** on dropdown open, asks GitHub for the latest
  release; if newer than the installed `CFBundleShortVersionString`, shows
  "Update available — download". No auto-installer. Set `Updates.repo` to the
  real repo. Release flow + how to add IDEs in `RELEASING.md`; `scripts/release.sh`.
- **Quick reply (keystroke-into-Terminal) was CUT.** Couldn't show the option
  text from afar (so blind-tapping 1/2/3 was useless), and it carried the scary
  Accessibility permission. Dropping it makes Simmer a pure "watch + notify" app
  with no ability to touch anything — a much cleaner trust story for launch.
- **Session names = Claude's terminal tab title** when available (e.g. "Explore
  Mac app…"), read via AppleScript (`custom title of tab`) on dropdown open — no
  polling. Falls back to working-folder name (home → "Home", via OS home dir, no
  hardcoded username), and disambiguates same-named sessions by tty. Titles are
  Terminal.app-only (the hook doesn't get the title; AppleScript does).
- **Click a roster row → focuses that Terminal tab.** Hook records the tty (walks
  the process tree, since stdin is a pipe) + TERM_PROGRAM; clicking runs Apple
  Events to select the matching tab. Automation permission (focus-only, can't
  type) — much milder than the cut Accessibility/keystroke feature. Terminal.app
  gets exact-tab focus; other terminals just get app-activate for now.
  - Gotchas learned: (1) raise the window BY ID (`set frontmost of window id …`),
    not via the loop variable — the latter silently no-ops. (2) Run via an
    `osascript` SUBPROCESS, not `NSAppleScript` — from a menu-bar app the latter
    lets `activate` through but silently fails window targeting.
- **Dropdown is now a per-session roster** (project name + colored status dot).
  Sessions delete their own file on close via a `SessionEnd` hook (`end` arg);
  the app also drops any file older than 30 min as a stale/crash safety net, so
  the roster only lists genuinely live sessions (no ghosts).
- **Alert sound = a soft chiptune.** Clawd is 8-bit, so the sound is chiptune.
  Chose a 3-note rising triangle-wave arpeggio (C5-E5-G5), low-passed and quiet
  (~14% vol) so it isn't piercing — square waves were "ouch." File:
  `Simmer/Resources/clawd-alert.wav`, regenerable via `gen_clawd_sound.py`.
- **Two chimes, by direction.** Action = a RISING arpeggio ("needs you").
  Done = a DESCENDING settle G5-E5-C5 (`clawd-done.wav`, `gen_done_sound.py`),
  softer (~12% vol). Rising vs falling lets you tell them apart without looking.
  (Reversed the earlier "done stays silent" call — Grant wanted a done sound.)
  Both fire once, on the rising edge into their state.
- **Sprite = exact Clawd.** Transcribed from Anthropic's mascot SVG (15x16
  viewBox, creature occupies 15w x 9h): torso, two stub arms, four legs, two
  black eyes. Body color `#DE886D`. Drawn as filled rects at the target point
  size (resolution-independent, crisp at any scale). Menu bar icon 14pt tall,
  panel 30pt. Source: marciogranzotto/clawd-tank `clawd-static-base.svg`.

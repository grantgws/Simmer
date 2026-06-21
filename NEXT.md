# Simmer — next actions

## Done
- ✅ Menu bar app builds & runs (Xcode project, opens like Grumbly)
- ✅ Clay Claude critter sprite (drawn in code) in menu bar + panel
- ✅ Status states: working (cycling words) / action / done / idle
- ✅ Click-to-reply buttons (1/2/3/⏎/Esc) that keystroke into Terminal
- ✅ Hooks wired into ~/.claude/settings.json (working/action/done)
- ✅ Hardened runtime off so Apple Events work for the keystroke feature

## To test (Grant)
1. **Restart Claude Code** — hooks load at session start, so open a NEW
   `claude` session for the critter to react to real activity.
2. Open `Simmer.xcodeproj`, hit Run (or make it a login item).
3. First time you tap 1/2/3, macOS asks for **Accessibility** + **Automation**
   permission → grant both in System Settings. (Status display works without
   them; only the click-to-reply needs them.)

## Roadmap — items 1–4 DONE (this session)
1. ✅ **Notifications + sound** — chime (`clawd-alert.wav`) + macOS banner fire
   once on the rising edge into "action". (Needs notification permission granted
   on first run; we play our own sound so the banner is silent.)
2. ✅ **Clawd emotes per state** — crafted poses in his pixel style: sleeping
   (idle), working (legs wiggle, 2 frames), action ("!" pops up, amber), eureka
   (arms up, done). NOT pixel-copies of Anthropic's animated SVGs — faithful
   recreations.
3. ✅ **Multi-session** — each session writes `~/.claude/simmer/sessions/<id>.json`
   (keyed by Claude's session_id from the hook stdin). Menu bar shows the most
   urgent via "loudest wins"; dropdown lists each active session by project.
4. ✅ **Calmer working state** — word changes every ~6s (not 2s); leg wiggle
   carries the motion so text doesn't strobe.

## Ship-readiness batch — DONE (this session)
- ✅ **Self-installing hooks** — "Connect to Claude Code" installs the script to
  Application Support and edits settings.json (no hardcoded paths). Verified the
  merge/strip on a copy of real settings: preserves all other keys, migrates old
  Projects-path hooks.
- ✅ **Clean uninstall** — "Disconnect" removes Simmer's hooks.
- ✅ **Narrowed action trigger** — Notification hook now uses `notify`; the script
  classifies the message so only real permission prompts → action (idle-waiting
  ignored). Made live in settings.json now (active after next CC restart).
- ✅ **Opt-in quick reply** — 1/2/3 keystroke buttons OFF by default, behind a
  toggle, with trust copy + "runs entirely on your Mac."
- ✅ **Onboarding + Launch at login** (SMAppService) in the dropdown.
- ✅ **App icon** — Clawd on a cream tile, .icns wired via explicit Info.plist.
- ✅ **README, LICENSE (MIT), SIGNING.md, disclaimer.**

## Launch assets — DONE
- ✅ Demo GIF (`assets/simmer-demo.gif`, regen via `assets/make_gif.swift`) +
  3 stills, embedded at top of README.
- ✅ Launch copy in `MARKETING.md` (X single + thread, Reddit, awesome-list PR).
- Plan: X (GIF native) → awesome-claude-code PR → Reddit → Show HN once polished.

## Needs Grant (can't be automated)
- **Signing + notarization** — needs your Apple Developer account ($99/yr). All
  steps scripted in SIGNING.md. For notarized build: turn hardened runtime back
  ON + add apple-events entitlement so Quick Reply still works.

## Later / nice-to-haves
- Phase 2: notch "island" panel that pops on action needed.
- Auto-detect terminal app instead of hardcoding "Terminal" (iTerm2/Ghostty).
- Best-effort parse of the actual option labels (hook only gives a message,
  not the 1/2/3 choices — may not be reliably possible).
- Click "Action needed" to focus the terminal window.

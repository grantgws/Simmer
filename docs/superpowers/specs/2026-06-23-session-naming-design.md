# Session naming — design

**Date:** 2026-06-23
**Feature:** Double-click a session in the Simmer dropdown to give it a custom name.

## Goal

Let the user attach a human-readable label to a session row in Simmer's dropdown
by double-clicking it and typing a name inline (Finder-style). The label replaces
the auto-derived name (Claude's session title / folder name) in the roster.

## Requirements

- **Double-click to rename, inline.** Double-clicking a session row turns its name
  into an editable text field in place. Enter saves, Esc cancels, an empty value
  clears the name. Single-click still jumps to the session's terminal (unchanged).
- **Keyed by `tty`.** A name attaches to the terminal device, so it rides along
  across the multiple Claude sessions that run in that terminal/pane, and persists
  across Simmer restarts.
- **Terminal/shell agnostic.** Naming must not depend on which terminal emulator or
  shell the session runs in. The `tty` is a POSIX identifier captured identically
  for every terminal/shell by the existing hook (`set-status.sh` walks the process
  tree with `ps -o tty=`). There is **no branching on `term`** anywhere in the
  naming path — store, display, and edit are all terminal-independent. (Contrast:
  `TerminalFocus`, the single-click jump, *is* per-terminal; that is unrelated to
  naming.)
- **Custom name wins.** When present, the custom name takes precedence over Claude's
  session title and the folder name.

## Non-goals

- No per-terminal fallback key when `tty` is empty (would break agnosticism).
- No automatic pruning of names for ttys no longer seen (see Future).
- No syncing/export of names; this is local UI state.

## Architecture

Single file affected: `Simmer/SimmerApp.swift` (plus this spec).

### 1. `SessionNames` store

A small enum wrapping `UserDefaults` (app-private UI state; not Claude data, so it
does not belong in the hook-owned `~/.claude/simmer/sessions/` files):

- Backing: one key, e.g. `"sessionNames"`, holding a `[String: String]` of
  `tty -> name`.
- API:
  - `static func all() -> [String: String]`
  - `static func set(_ raw: String, forTTY tty: String)` — trims whitespace; if the
    result is empty, removes the key (clear); otherwise stores it.
  - `static func clear(forTTY tty: String)`

Rationale for `UserDefaults` over a JSON file: atomic, no IO/parse/write-safety
code, idiomatic for small app-private state. (A `~/.claude/simmer/names.json` file
was considered for inspectability but rejected as unnecessary complexity.)

### 2. `StatusMonitor` changes

- `@Published var names: [String: String]` — loaded from `SessionNames.all()` at
  init so the view re-renders when a name changes.
- `func setName(_ raw: String, forTTY tty: String)` — writes through to
  `SessionNames` and updates `names` so the roster updates live.

### 3. Display precedence

`displayName(_:)` becomes, in order:

1. **Custom name** — `names[s.tty]` (non-empty) → return as-is (no tty-dedup suffix;
   the user chose this label).
2. Claude session title — `titles[s.tty]` (existing).
3. Folder name, tty-disambiguated when two share a name (existing).

### 4. Row UI (inline edit)

Two view-local `@State` values plus focus:

- `@State editingTTY: String?` — the tty currently being edited (nil = none).
- `@State draftName: String` — the in-progress text.
- `@FocusState private var editing: Bool`.

The row's `Button` is replaced by a plain container with the same visuals
(`.contentShape`, `.onHover` hover pill, padding) — a `Button` can't cleanly carry
distinct single- and double-tap actions, so the two tap gestures live on a plain
view instead.

Behavior per row `s`:

- **Not editing** (`editingTTY != s.tty`): render the existing row (status dot ·
  `displayName` · state word). Gestures, stacked so single and double click coexist:
  - `.onTapGesture(count: 2)` → begin editing **only if `!s.tty.isEmpty`**: set
    `editingTTY = s.tty`, `draftName = names[s.tty] ?? ""`, focus the field.
  - `.onTapGesture(count: 1)` → `TerminalFocus.focus(s)` (unchanged jump).
  - Help text → `"Click to jump · double-click to rename"`.
- **Editing** (`editingTTY == s.tty`): the name area becomes a focused `TextField`
  bound to `draftName`.
  - `.onSubmit` (Enter) → `monitor.setName(draftName, forTTY: s.tty)`, then
    `editingTTY = nil`.
  - `.onExitCommand` (Esc) → `editingTTY = nil` without saving.
  - Focus loss → commit (same as Enter), so clicking elsewhere saves.
  - Empty/whitespace draft on commit → clears the name (reverts to title/folder).

## Data flow

```
double-click row (tty non-empty)
  -> editingTTY = tty; draftName = current custom name or ""
  -> TextField focused; user types
  -> Enter / focus-loss
       -> monitor.setName(draftName, forTTY: tty)
            -> SessionNames.set -> UserDefaults  (trim; empty => remove)
            -> monitor.names updated -> @Published triggers re-render
       -> displayName now returns the custom name
  -> Esc -> discard, no write
```

## Edge cases

- **Empty `tty`** (rare; no controlling terminal): row is not editable, double-click
  is a no-op. Consistent with `TerminalFocus`, which also can't target it.
- **Recycled tty (accepted tradeoff):** macOS reuses tty numbers. A stored name
  persists until cleared, so it could label a *later, unrelated* session that lands
  on the same tty. Clearing is one double-click + empty + Enter. Documented, not
  prevented.
- **Two sessions, same custom name:** shown as-is for both (no auto-suffix); it's the
  user's explicit choice.
- **Name + Claude title both present:** custom name wins (precedence above).

## Persistence

`UserDefaults.standard`, key `"sessionNames"`, value `[String: String]`
(`tty -> trimmed name`). Survives app relaunch. Cleared entries remove the key.

## Testing

The project has no XCTest target, and this is AppKit/SwiftUI UI behavior. Plan:

- `xcodebuild` (Debug, macOS) must succeed.
- Manual run: double-click a session → field appears focused; type a name + Enter →
  roster shows it; relaunch Simmer → name persists; double-click + clear + Enter →
  reverts to the auto name; single-click still jumps to the terminal.

The only pure logic (trim → empty-clears) is kept trivial inside `SessionNames.set`.
No test target is added for this feature unless requested.

## Future (out of scope)

- Optional pruning: drop names whose tty hasn't appeared in a long window, to bound
  recycled-tty staleness.

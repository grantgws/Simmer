# Session Naming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user double-click a session row in Simmer's dropdown to give it a custom, terminal/shell-agnostic name that persists across sessions and restarts.

**Architecture:** A `SessionNames` enum persists a `[tty: name]` map in `UserDefaults`. `StatusMonitor` exposes it as `@Published var names` plus a `setName` write-through. `displayName` prefers the custom name. The session row becomes a plain container (not a `Button`) carrying a single-tap (jump) and double-tap (begin inline edit) gesture, with a focused `TextField` shown while editing.

**Tech Stack:** Swift, SwiftUI, AppKit (macOS menu-bar app). Single source file: `Simmer/SimmerApp.swift`.

## Global Constraints

- **Single file:** all code changes are in `Simmer/SimmerApp.swift` (plus this plan/spec). Match the file's existing style (terse comments explaining *why*).
- **Terminal/shell agnostic:** NO branching on `s.term` anywhere in the naming path (store, `setName`, `displayName`, edit UI). The key is always `tty`.
- **Key format:** key on `s.tty` exactly as stored (bare form, e.g. `ttys001`, no `/dev/` prefix) — identical to the existing `titles` dictionary key space.
- **Display precedence:** custom name (`names[s.tty]`) → Claude title (`titles[s.tty]`) → folder name.
- **Persistence:** `UserDefaults.standard`, key `"sessionNames"`, value `[String: String]`.
- **No XCTest target exists** (per spec); verification is `xcodebuild` build success + manual run. Do not add a test target.
- **Build command (the gate for every task):**
  `xcodebuild build -project Simmer.xcodeproj -scheme Simmer -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
  Expected tail: `** BUILD SUCCEEDED **`
- **Commit trailer:** end every commit message with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- **Branch:** work on `feature/session-naming` (already checked out).

---

## File Structure

- **Modify** `Simmer/SimmerApp.swift`:
  - Add top-level `enum SessionNames` (the `UserDefaults` store) above `// MARK: - Monitor` (~line 318).
  - Add `@Published var names` + `func setName(...)` to `StatusMonitor` (~lines 328 / after 384).
  - Change `displayName(_:)` precedence (~lines 701–710).
  - Replace the session-row `Button` with a plain container + gestures + inline `TextField`, and add edit state to `SimmerMenu` (~lines 579, 602–625).

Two tasks: **Task 1** = data + display layer (compiles, no behavior change visible yet). **Task 2** = inline-edit UI (full feature, manually verified).

---

### Task 1: Name store, monitor wiring, and display precedence

**Files:**
- Modify: `Simmer/SimmerApp.swift` (add `SessionNames`; add `names`/`setName` to `StatusMonitor`; update `displayName`)

**Interfaces:**
- Produces (used by Task 2):
  - `enum SessionNames { static func all() -> [String: String]; static func set(_ raw: String, forTTY tty: String); static func clear(forTTY tty: String) }`
  - `StatusMonitor.names: [String: String]` (`@Published`)
  - `StatusMonitor.setName(_ raw: String, forTTY tty: String)`

- [ ] **Step 1: Add the `SessionNames` store**

Insert this top-level enum immediately above the `// MARK: - Monitor` line (~318):

```swift
// MARK: - Custom session names
//
// User-chosen labels for sessions, keyed by tty so a name rides along across the
// sessions that run in a given terminal/pane. Stored in UserDefaults (Simmer's own
// UI state — not Claude data, so it never touches the hook-owned session files).
// Keying on tty (a POSIX id captured the same way for every terminal/shell) keeps
// this terminal/shell agnostic.

enum SessionNames {
    private static let key = "sessionNames"

    static func all() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    static func set(_ raw: String, forTTY tty: String) {
        guard !tty.isEmpty else { return }
        var map = all()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            map.removeValue(forKey: tty)   // empty input clears the name
        } else {
            map[tty] = trimmed
        }
        UserDefaults.standard.set(map, forKey: key)
    }

    static func clear(forTTY tty: String) { set("", forTTY: tty) }
}
```

- [ ] **Step 2: Add `names` to `StatusMonitor`**

Add this property right after the `titles` line (line 328):

```swift
    @Published var names: [String: String] = SessionNames.all()  // tty -> user-chosen name
```

- [ ] **Step 3: Add `setName` to `StatusMonitor`**

Add this method inside `StatusMonitor`, immediately after the `refreshTitles()` method's closing brace (~line 384):

```swift
    /// Persist (or clear, on empty input) a user-chosen name for a tty, and
    /// republish so the roster updates live.
    func setName(_ raw: String, forTTY tty: String) {
        SessionNames.set(raw, forTTY: tty)
        names = SessionNames.all()
    }
```

- [ ] **Step 4: Make the custom name win in `displayName`**

In `displayName(_:)` (~lines 701–710), add the custom-name check as the first precedence. Replace:

```swift
    private func displayName(_ s: SessionStatus) -> String {
        // Prefer Claude's session title (e.g. "Explore Mac app…") when we have it.
        if let title = monitor.titles[s.tty], !title.isEmpty, title != "Claude Code" {
```

with:

```swift
    private func displayName(_ s: SessionStatus) -> String {
        // A user-chosen name always wins.
        if let custom = monitor.names[s.tty], !custom.isEmpty { return custom }
        // Otherwise prefer Claude's session title (e.g. "Explore Mac app…").
        if let title = monitor.titles[s.tty], !title.isEmpty, title != "Claude Code" {
```

(Leave the rest of `displayName` unchanged.)

- [ ] **Step 5: Build**

Run: `xcodebuild build -project Simmer.xcodeproj -scheme Simmer -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -4`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Simmer/SimmerApp.swift
git commit -m "feat: session name store, monitor wiring, display precedence

Add SessionNames (UserDefaults, tty-keyed), StatusMonitor.names/setName,
and make a custom name take precedence over the Claude title and folder
name in the roster. No UI to set names yet (next task).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Inline double-click rename in the roster

**Files:**
- Modify: `Simmer/SimmerApp.swift` (`SimmerMenu`: edit state, helpers, row rebuild)

**Interfaces:**
- Consumes (from Task 1): `monitor.names`, `monitor.setName(_:forTTY:)`.
- Produces: user-visible rename behavior. No new symbols other tasks depend on.

- [ ] **Step 1: Add edit state to `SimmerMenu`**

Add these properties alongside the existing `@State` vars near line 579 (after `@State private var hoveredSession: String?`):

```swift
    @State private var editingTTY: String?
    @State private var draftName: String = ""
    @FocusState private var nameFieldFocused: Bool
```

- [ ] **Step 2: Add edit helper methods**

Add these methods to `SimmerMenu` (e.g. just after the `displayName(_:)` method):

```swift
    private func beginEditing(_ s: SessionStatus) {
        guard !s.tty.isEmpty else { return }   // no stable agnostic key -> not renameable
        draftName = monitor.names[s.tty] ?? ""
        editingTTY = s.tty
        nameFieldFocused = true
    }

    // Save the draft (empty clears) and leave edit mode. Guarded so a cancel
    // (which nils editingTTY first) and the resulting focus-loss don't double-fire.
    private func commitEditing() {
        guard let tty = editingTTY else { return }
        monitor.setName(draftName, forTTY: tty)
        editingTTY = nil
    }
```

- [ ] **Step 3: Add a `sessionRow` view builder**

Add this `@ViewBuilder` method to `SimmerMenu` (next to the helpers from Step 2). It carries the same chrome the old `Button` had, branches the name area between `Text` and `TextField`, and attaches the tap gestures only when *not* editing (so clicks inside the field position the cursor instead of triggering jump/edit):

```swift
    @ViewBuilder
    private func sessionRow(_ s: SessionStatus) -> some View {
        let base = HStack(spacing: 8) {
            Circle().fill(dotColor(s.state)).frame(width: 7, height: 7)
            if editingTTY == s.tty {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.plain)
                    .focused($nameFieldFocused)
                    .onSubmit { commitEditing() }          // Enter saves
                    .onExitCommand { editingTTY = nil }     // Esc cancels (no save)
            } else {
                Text(displayName(s)).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(word(s.state)).foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(hoveredSession == s.id ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hoveredSession = $0 ? s.id : nil }
        .help("Click to jump · double-click to rename")

        if editingTTY == s.tty {
            base
        } else {
            base
                .onTapGesture(count: 2) { beginEditing(s) }
                .onTapGesture(count: 1) { TerminalFocus.focus(s) }
        }
    }
```

- [ ] **Step 4: Use `sessionRow` in the roster `ForEach`**

Replace the existing roster `ForEach` block (lines 602–624) — from `ForEach(monitor.sessions) { s in` through its closing `}` that carries `.padding(.horizontal, -8)` is applied *after* the ForEach, so keep that. Replace just the ForEach body:

```swift
                ForEach(monitor.sessions) { s in
                    Button { TerminalFocus.focus(s) } label: {
                        HStack(spacing: 8) {
                            Circle().fill(dotColor(s.state)).frame(width: 7, height: 7)
                            Text(displayName(s)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(word(s.state)).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .opacity(hoveredSession == s.id ? 1 : 0)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveredSession = $0 ? s.id : nil }
                    .help("Click to jump to this session's terminal")
                }
```

with:

```swift
                ForEach(monitor.sessions) { s in
                    sessionRow(s)
                }
```

- [ ] **Step 5: Commit on focus loss**

So clicking elsewhere saves an in-progress edit, add an `.onChange` for the focus state. Attach it to the root `VStack` (the one that opens at `VStack(alignment: .leading, spacing: 10)` ~line 583) by adding this modifier next to the existing `.onAppear { ... }` (~line 675):

```swift
        .onChange(of: nameFieldFocused) { focused in
            if !focused { commitEditing() }   // no-op if already committed/cancelled
        }
```

- [ ] **Step 6: Build**

Run: `xcodebuild build -project Simmer.xcodeproj -scheme Simmer -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -4`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Manual verification (run the app)**

Build, then launch the freshly built app:

```bash
APP="$(xcodebuild -showBuildSettings -project Simmer.xcodeproj -scheme Simmer -configuration Debug 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/{print $2}')/Simmer.app"
open "$APP"
```

With at least one Claude Code session running, open Simmer's menu-bar dropdown and confirm:
- **Single-click** a session row → its terminal comes forward (unchanged).
- **Double-click** a row → the name becomes a focused text field pre-filled with the current name.
- Type a name + **Enter** → the row shows the custom name.
- **Quit and relaunch** Simmer → the custom name is still shown (persisted).
- Double-click → clear the text → **Enter** → reverts to the Claude title / folder name.
- Double-click → type → **Esc** → no change (cancelled).

- [ ] **Step 8: Commit**

```bash
git add Simmer/SimmerApp.swift
git commit -m "feat: double-click a session to rename it inline

Replace the row Button with a plain container carrying single-tap (jump)
and double-tap (edit) gestures, plus a focused TextField while editing.
Enter saves, Esc cancels, empty clears; focus loss commits.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Double-click inline rename → Task 2 (Steps 1–5).
- Enter saves / Esc cancels / empty clears / focus-loss commits → Task 2 Steps 2, 3, 5.
- Single-click still jumps → Task 2 Step 3 (count:1 gesture).
- Keyed by tty → Task 1 Steps 1–3 (all keyed on tty).
- Terminal/shell agnostic (no `term` branching) → confirmed: no step references `s.term`.
- Custom name precedence → Task 1 Step 4.
- UserDefaults `"sessionNames"` → Task 1 Step 1.
- Empty-tty not renameable → Task 2 Step 2 (`guard !s.tty.isEmpty`).
- Recycled-tty staleness / duplicate names → documented in spec as accepted; no code needed.

**Placeholder scan:** none — every code step shows complete code.

**Type consistency:** `SessionNames.all/set/clear`, `monitor.names`, `monitor.setName(_:forTTY:)`, `beginEditing(_:)`, `commitEditing()`, `sessionRow(_:)`, `editingTTY`, `draftName`, `nameFieldFocused` are used consistently across both tasks.

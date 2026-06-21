# Releasing updates

Simmer has a lightweight in-app update check: on opening the dropdown it asks
GitHub for the latest release and, if it's newer than the installed version,
shows **"Update available — download"** linking to the release page. (It does not
auto-install — it points the user to the new build.)

## One-time setup
- In `Simmer/SimmerApp.swift`, set `Updates.repo` to your GitHub repo, e.g.
  `static let repo = "grantshaver/simmer"`.

## Cutting a release
1. **Bump the version** in Xcode: target *Simmer* → General → Version (e.g.
   `0.1` → `0.2`). This is what the update check compares.
2. Run `scripts/release.sh` — builds `dist/Simmer.zip`.
3. **Notarize** it (see `SIGNING.md`) so users can open it without a warning.
4. **Publish a GitHub release** tagged `v<version>` (e.g. `v0.2`) with the zip:
   ```sh
   gh release create v0.2 dist/Simmer.zip --title "Simmer 0.2" --notes "…"
   ```
5. Done — running copies older than `0.2` will show the update prompt.

> Version compare ignores a leading `v` and compares dot-separated numbers, so
> tags `v0.2` / `0.2` both work, and `0.10` correctly beats `0.9`.

## Adding support for more IDEs / terminals (future)
Terminal-specific behavior is isolated, so adding iTerm2/Ghostty/VS Code mostly
means handling their cases in two spots:
- **`TerminalFocus.focus(_:)`** — clicking a session focuses its window/tab. Add
  the target app's AppleScript (or URL scheme) keyed on `s.term`.
- **`StatusMonitor.refreshTitles()`** — reads the session title from Terminal.app
  via AppleScript. Add the equivalent for other terminals (or skip → falls back
  to the folder name).
- The hook already records `TERM_PROGRAM` (the `term` field), so you can branch
  on it. No hook changes needed for most terminals; the app side does the work.

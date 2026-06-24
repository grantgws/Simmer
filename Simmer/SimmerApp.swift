import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement

// MARK: - Clawd, the Claude Code mascot
//
// Clawd is a pixel crab. The base shape is transcribed from Anthropic's sprite
// (15 wide, body 9 tall: torso, two stub arms, four legs, two black eyes). The
// other poses are crafted in the same pixel style to convey state. Each pixel
// is a filled rectangle drawn at the target size, so it's crisp at any scale.
// 'B' = body, 'E' = eye, 'Z' = sleepy z, '!' = alert mark.

enum Pose: CaseIterable {
    case workingA, workingB, sleeping, action, eureka
}

enum Critter {
    static func grid(_ pose: Pose) -> [String] {
        switch pose {
        case .workingA: return [
            "..BBBBBBBBBBB..", "..BBBBBBBBBBB..", "..BBEBBBBBEBB..",
            "BBBBEBBBBBEBBBB", "BBBBBBBBBBBBBBB", "..BBBBBBBBBBB..",
            "..BBBBBBBBBBB..", "...B.B...B.B...", "...B.B...B.B...",
        ]
        case .workingB: return [
            "..BBBBBBBBBBB..", "..BBBBBBBBBBB..", "..BBEBBBBBEBB..",
            "BBBBEBBBBBEBBBB", "BBBBBBBBBBBBBBB", "..BBBBBBBBBBB..",
            "..BBBBBBBBBBB..", "..B.B.....B.B..", "..B.B.....B.B..",
        ]
        case .sleeping: return [
            ".............Z.", "............Z..", "..BBBBBBBBBBB..",
            "..BBBBBBBBBBB..", "..BBBBBBBBBBB..", "BBBBEBBBBBEBBBB",
            "BBBBBBBBBBBBBBB", "..BBBBBBBBBBB..", "..BBBBBBBBBBB..",
            "...B.B...B.B...", "...B.B...B.B...",
        ]
        case .action: return [
            ".......!.......", ".......!.......", "...............",
            ".......!.......", "..BBBBBBBBBBB..", "..BBBBBBBBBBB..",
            "..BBEBBBBBEBB..", "BBBBEBBBBBEBBBB", "BBBBBBBBBBBBBBB",
            "..BBBBBBBBBBB..", "..BBBBBBBBBBB..", "...B.B...B.B...",
            "...B.B...B.B...",
        ]
        case .eureka: return [
            ".BB.........BB.", "..B.........B..", "..BBBBBBBBBBB..",
            "..BBBBBBBBBBB..", "..BBEBBBBBEBB..", "..BBBBBBBBBBB..",
            "..BBBBBBBBBBB..", "..BBBBBBBBBBB..", "..BBBBBBBBBBB..",
            "...B.B...B.B...", "...B.B...B.B...",
        ]
        }
    }

    static let body  = NSColor(srgbRed: 0xDE/255, green: 0x88/255, blue: 0x6D/255, alpha: 1)
    static let eye   = NSColor.black
    static let zzz   = NSColor(white: 0.55, alpha: 0.8)
    static let alert = NSColor(srgbRed: 0xF4/255, green: 0xB9/255, blue: 0x42/255, alpha: 1)

    private static func color(_ ch: Character) -> NSColor {
        switch ch {
        case "E": return eye
        case "Z": return zzz
        case "!": return alert
        default:  return body
        }
    }

    static func image(_ pose: Pose, cell: CGFloat) -> NSImage {
        let rows = grid(pose)
        let nRows = rows.count
        let nCols = rows.map(\.count).max() ?? 0
        let size = NSSize(width: CGFloat(nCols) * cell, height: CGFloat(nRows) * cell)
        let img = NSImage(size: size, flipped: false) { _ in
            for (r, line) in rows.enumerated() {
                for (c, ch) in line.enumerated() where ch != "." {
                    color(ch).setFill()
                    NSRect(x: CGFloat(c) * cell, y: CGFloat(nRows - 1 - r) * cell,
                           width: cell, height: cell).fill()
                }
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    static let menuImages  = Dictionary(uniqueKeysWithValues: Pose.allCases.map { ($0, image($0, cell: 1.6)) })
    static let panelImages = Dictionary(uniqueKeysWithValues: Pose.allCases.map { ($0, image($0, cell: 3.4)) })
}

// MARK: - State

enum ClaudeState: String {
    case idle, working, action, done
}

let workingWords = [
    "Simmering", "Percolating", "Pondering", "Noodling", "Brewing",
    "Marinating", "Cooking", "Conjuring", "Finagling", "Schlepping",
    "Spelunking", "Whirring", "Mulling", "Tinkering", "Vibing",
]

struct SessionStatus: Identifiable {
    let id: String
    let state: ClaudeState
    let cwd: String
    var tty: String = ""
    var term: String = ""
    var project: String {
        guard !cwd.isEmpty else { return "session" }
        // Use the OS home dir (never a hardcoded username) so this is foolproof
        // for any user: a session running in the home folder shows "Home" rather
        // than the username, otherwise show the working folder's name.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if cwd == home || cwd == home + "/" { return "Home" }
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? "session" : name
    }
}

// MARK: - Sound + notifications

enum Chime {
    private static func load(_ name: String) -> NSSound? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        return NSSound(contentsOf: url, byReference: true)
    }
    static let alert = load("clawd-alert")   // rising — "needs you"
    static let done  = load("clawd-done")    // descending — "finished"
    static func playAlert() { alert?.stop(); alert?.play() }
    static func playDone()  { done?.stop();  done?.play() }
}

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    func fire(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil   // we play our own Clawd chime
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification,
                                withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) {
        h([.banner, .list])
    }
}

// MARK: - Connecting to Claude Code (self-installing hooks)
//
// Simmer installs its own copy of the status script into Application Support and
// edits ~/.claude/settings.json to add hooks pointing at it. This means there
// are NO hardcoded paths and it works on any machine — and "Disconnect" cleanly
// removes the hooks so deleting the app never leaves Claude Code broken.

enum Connection {
    static let appSupport: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Simmer", isDirectory: true)
    static var scriptURL: URL { appSupport.appendingPathComponent("set-status.sh") }
    static let settingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    // The status writer, embedded as base64 so it's written byte-for-byte (no
    // risk of Swift literal indentation mangling the embedded Python).
    static let scriptBodyB64 = "IyEvYmluL2Jhc2gKIyBTaW1tZXIgc3RhdHVzIHdyaXRlciDigJQgY2FsbGVkIGJ5IENsYXVkZSBDb2RlIGhvb2tzLiBXcml0ZXMgVEhJUyBzZXNzaW9uJ3MKIyBzdGF0ZSB0byBpdHMgb3duIGZpbGUgKGtleWVkIGJ5IHNlc3Npb25faWQpIHNvIGNvbmN1cnJlbnQgc2Vzc2lvbnMgZG9uJ3QKIyBjbG9iYmVyLiBBbHNvIHJlY29yZHMgdGhlIHRlcm1pbmFsJ3MgdHR5ICsgYXBwIHNvIHRoZSBtZW51IGJhciBjYW4gZm9jdXMgdGhlCiMgcmlnaHQgdGFiIHdoZW4geW91IGNsaWNrIGEgc2Vzc2lvbi4gQ2xhdWRlIHBpcGVzIHRoZSBldmVudCBKU09OIHRvIHN0ZGluLgojCiMgVXNhZ2U6IHNldC1zdGF0dXMuc2ggPGFyZz4KIyAgIHdvcmtpbmcgfCBkb25lIHwgaWRsZSAgLT4gd3JpdGUgdGhhdCBzdGF0ZQojICAgbm90aWZ5ICAgICAgICAgICAgICAgICAtPiBvbmx5IGEgcGVybWlzc2lvbi9hcHByb3ZhbCBwcm9tcHQgYmVjb21lcyAiYWN0aW9uIjsKIyAgICAgICAgICAgICAgICAgICAgICAgICAgICAgYWxsIG90aGVyIG5vdGlmaWNhdGlvbnMgYXJlIGlnbm9yZWQgKG5vIGZhbHNlIGFsYXJtcykuCiMgICBlbmQgICAgICAgICAgICAgICAgICAgIC0+IHNlc3Npb24gY2xvc2VkOiBkZWxldGUgaXRzIGZpbGUuCkFSRz0iJHsxOi1pZGxlfSIKCiMgRmluZCB0aGUgY29udHJvbGxpbmcgdGVybWluYWwgYnkgd2Fsa2luZyB1cCB0aGUgcHJvY2VzcyB0cmVlIChzdGRpbiBpcyBhIHBpcGUKIyBoZXJlLCBzbyBgdHR5YCB3b24ndCB3b3JrLCBidXQgYW4gYW5jZXN0b3Igb3ducyB0aGUgcmVhbCB0dHlzTk5OKS4KZ2V0X3R0eSgpIHsKICBsb2NhbCBwaWQ9JCQgdAogIGZvciBfIGluIDEgMiAzIDQgNSA2OyBkbwogICAgWyAteiAiJHBpZCIgXSAmJiBicmVhawogICAgdD0kKHBzIC1vIHR0eT0gLXAgIiRwaWQiIDI+L2Rldi9udWxsIHwgdHIgLWQgJyAnKQogICAgY2FzZSAiJHQiIGluCiAgICAgICIifCI/PyIpIDs7CiAgICAgICopIHByaW50ZiAnJXMnICIkdCI7IHJldHVybiA7OwogICAgZXNhYwogICAgcGlkPSQocHMgLW8gcHBpZD0gLXAgIiRwaWQiIDI+L2Rldi9udWxsIHwgdHIgLWQgJyAnKQogIGRvbmUKfQoKU0lNTUVSX1RUWT0iJChnZXRfdHR5KSIgcHl0aG9uMyAtYyAnCmltcG9ydCBzeXMsIGpzb24sIG9zLCB0aW1lCmFyZyA9IHN5cy5hcmd2WzFdCnJhdyA9IHN5cy5zdGRpbi5yZWFkKCkKdHJ5OgogICAgZCA9IGpzb24ubG9hZHMocmF3KSBpZiByYXcuc3RyaXAoKSBlbHNlIHt9CmV4Y2VwdCBFeGNlcHRpb246CiAgICBkID0ge30Kc2lkID0gZC5nZXQoInNlc3Npb25faWQiKSBvciAiZGVmYXVsdCIKY3dkID0gZC5nZXQoImN3ZCIpIG9yICIiCmRkID0gb3MucGF0aC5leHBhbmR1c2VyKCJ+Ly5jbGF1ZGUvc2ltbWVyL3Nlc3Npb25zIikKcGF0aCA9IG9zLnBhdGguam9pbihkZCwgc2lkICsgIi5qc29uIikKCmlmIGFyZyA9PSAiZW5kIjoKICAgIHRyeToKICAgICAgICBvcy5yZW1vdmUocGF0aCkKICAgIGV4Y2VwdCBPU0Vycm9yOgogICAgICAgIHBhc3MKICAgIHN5cy5leGl0KDApCgpzdGF0ZSA9IGFyZwppZiBhcmcgPT0gIm5vdGlmeSI6CiAgICAjIE9ubHkgYSBnZW51aW5lIHBlcm1pc3Npb24vYXBwcm92YWwgcmVxdWVzdCBjb3VudHMgYXMgImFjdGlvbiBuZWVkZWQiLgogICAgIyBFdmVyeSBvdGhlciBub3RpZmljYXRpb24gKGlkbGUgIndhaXRpbmcgZm9yIHlvdXIgaW5wdXQiLCBldGMuKSBpcyBpZ25vcmVkLAogICAgIyBzbyB0aGUgbWVudSBiYXIgZG9lcyBub3QgY3J5IHdvbGYuCiAgICBtc2cgPSAoZC5nZXQoIm1lc3NhZ2UiKSBvciAiIikubG93ZXIoKQogICAgaWYgKCJwZXJtaXNzaW9uIiBpbiBtc2cpIG9yICgiYXBwcm92ZSIgaW4gbXNnKSBvciAoIndhbnRzIHRvIiBpbiBtc2cpOgogICAgICAgIHN0YXRlID0gImFjdGlvbiIKICAgIGVsc2U6CiAgICAgICAgc3lzLmV4aXQoMCkKCnR0eSA9IG9zLmVudmlyb24uZ2V0KCJTSU1NRVJfVFRZIikgb3IgIiIKdGVybSA9IG9zLmVudmlyb24uZ2V0KCJURVJNX1BST0dSQU0iKSBvciAiIgojIEtlZXAgdHR5L3Rlcm0gc3RhYmxlIGlmIGEgbGF0ZXIgZXZlbnQgY291bGQgbm90IHJlY2FwdHVyZSB0aGVtLgppZiAobm90IHR0eSBvciBub3QgdGVybSkgYW5kIG9zLnBhdGguZXhpc3RzKHBhdGgpOgogICAgdHJ5OgogICAgICAgIG9sZCA9IGpzb24ubG9hZChvcGVuKHBhdGgpKQogICAgICAgIHR0eSA9IHR0eSBvciBvbGQuZ2V0KCJ0dHkiLCAiIikKICAgICAgICB0ZXJtID0gdGVybSBvciBvbGQuZ2V0KCJ0ZXJtIiwgIiIpCiAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgIHBhc3MKCm9zLm1ha2VkaXJzKGRkLCBleGlzdF9vaz1UcnVlKQp3aXRoIG9wZW4ocGF0aCwgInciKSBhcyBmOgogICAganNvbi5kdW1wKHsic3RhdGUiOiBzdGF0ZSwgInRzIjogaW50KHRpbWUudGltZSgpKSwgImN3ZCI6IGN3ZCwgInR0eSI6IHR0eSwgInRlcm0iOiB0ZXJtfSwgZikKJyAiJEFSRyIKZXhpdCAwCg=="

    // Events we hook and the script argument each uses.
    private static let eventArgs: [(event: String, arg: String, matcher: Bool)] = [
        ("UserPromptSubmit", "working", false),
        ("PreToolUse",       "working", true),
        ("PostToolUse",      "working", true),
        ("Notification",     "notify",  false),
        ("Stop",             "done",    false),
        ("SessionEnd",       "end",     false),
    ]

    static var isConnected: Bool {
        guard let dict = readSettings(), let hooks = dict["hooks"] else { return false }
        // Marker has no "/" on purpose: JSONSerialization escapes slashes (\/),
        // so a slash-containing marker would never match.
        return contains(hooks, marker: "set-status.sh")
    }

    /// True if settings.json exists but can't be parsed — we must NOT touch it,
    /// or we'd wipe the user's other settings (model, MCP servers, …).
    static var settingsUnreadable: Bool {
        FileManager.default.fileExists(atPath: settingsURL.path) && readSettings() == nil
    }

    @discardableResult
    static func connect() -> Bool {
        guard !settingsUnreadable else { return false }
        installScript()
        backupSettings()
        var dict = readSettings() ?? [:]
        var hooks = (dict["hooks"] as? [String: Any]) ?? [:]
        hooks = stripOurHooks(hooks)
        let cmdBase = "\"\(scriptURL.path)\""
        for e in eventArgs {
            var group: [String: Any] = ["hooks": [["type": "command", "command": "\(cmdBase) \(e.arg)"]]]
            if e.matcher { group["matcher"] = "*" }
            var arr = (hooks[e.event] as? [[String: Any]]) ?? []
            arr.append(group)
            hooks[e.event] = arr
        }
        dict["hooks"] = hooks
        writeSettings(dict)
        return true
    }

    @discardableResult
    static func disconnect() -> Bool {
        guard !settingsUnreadable, var dict = readSettings() else { return false }
        backupSettings()
        if var hooks = dict["hooks"] as? [String: Any] {
            hooks = stripOurHooks(hooks)
            if hooks.isEmpty { dict.removeValue(forKey: "hooks") } else { dict["hooks"] = hooks }
        }
        writeSettings(dict)
        return true
    }

    /// Copy settings.json to a backup before we edit it, so a mistake is recoverable.
    private static func backupSettings() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        let backup = settingsURL.deletingLastPathComponent().appendingPathComponent("settings.simmer-backup.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: settingsURL, to: backup)
    }

    // MARK: helpers

    private static func installScript() {
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        if let data = Data(base64Encoded: scriptBodyB64) {
            try? data.write(to: scriptURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        }
    }

    /// Remove any hook groups that reference a Simmer status script (matches both
    /// the installed Application Support path and older Projects-folder paths).
    private static func stripOurHooks(_ hooks: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (event, value) in hooks {
            guard let arr = value as? [[String: Any]] else { out[event] = value; continue }
            let kept = arr.filter { !contains($0, marker: "set-status.sh") }
            if !kept.isEmpty { out[event] = kept }
        }
        return out
    }

    private static func contains(_ any: Any, marker: String) -> Bool {
        if let data = try? JSONSerialization.data(withJSONObject: any),
           let s = String(data: data, encoding: .utf8) {
            return s.contains(marker)
        }
        return false
    }

    private static func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    private static func writeSettings(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict,
                                                     options: [.prettyPrinted, .sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: settingsURL, options: .atomic)
    }
}

// MARK: - Update check (lightweight: points to the latest GitHub release)

enum Updates {
    // Set this to your GitHub repo ("owner/name") once published.
    static let repo = "grantgws/Simmer"

    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Is `tag` (e.g. "v0.3" or "0.3") a newer version than what's installed?
    static func isNewer(_ tag: String) -> Bool {
        let latest = parse(tag), cur = parse(current)
        for i in 0..<max(latest.count, cur.count) {
            let l = i < latest.count ? latest[i] : 0
            let c = i < cur.count ? cur[i] : 0
            if l != c { return l > c }
        }
        return false
    }

    private static func parse(_ s: String) -> [Int] {
        String(s.drop { !$0.isNumber }).split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}

// MARK: - Launch at login

enum LoginItem {
    static var enabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) {
        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
        catch { NSLog("Simmer login item error: \(error)") }
    }
}

// MARK: - Monitor

final class StatusMonitor: ObservableObject {
    @Published var state: ClaudeState = .idle
    @Published var menuBarText: String = ""
    @Published var detail: String = "Idle"
    @Published var sessions: [SessionStatus] = []
    @Published var menuIcon: NSImage = Critter.menuImages[.sleeping]!
    @Published var panelIcon: NSImage = Critter.panelImages[.sleeping]!
    @Published var connected: Bool = Connection.isConnected
    @Published var titles: [String: String] = [:]   // tty -> Claude's session title
    @Published var names: [String: String] = SessionNames.all()  // session id -> custom name
    @Published var updateURL: URL?                   // set if a newer release exists

    /// Save (or clear, on empty input) a user-chosen name for a session, and
    /// republish so the roster updates immediately.
    func setName(_ raw: String, for sessionID: String) {
        SessionNames.set(raw, for: sessionID)
        names = SessionNames.all()
    }

    /// Ask GitHub for the latest release; if newer than installed, expose its URL.
    func checkForUpdates() {
        guard let api = URL(string: "https://api.github.com/repos/\(Updates.repo)/releases/latest") else { return }
        URLSession.shared.dataTask(with: api) { data, _, _ in
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String,
                  let html = obj["html_url"] as? String,
                  let link = URL(string: html),
                  Updates.isNewer(tag) else { return }
            DispatchQueue.main.async { self.updateURL = link }
        }.resume()
    }

    /// Reads each Terminal tab's title (the session name Claude writes) so the
    /// roster can show "Explore Mac app…" instead of just the folder. Called when
    /// the dropdown opens — no constant polling. Terminal.app only.
    func refreshTitles() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            tell application "Terminal"
                set out to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        try
                            set out to out & (tty of t) & "\\t" & (custom title of t) & linefeed
                        end try
                    end repeat
                end repeat
                return out
            end tell
            """
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            let pipe = Pipe()
            p.standardOutput = pipe
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return }
            var map: [String: String] = [:]
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let tty = parts[0].replacingOccurrences(of: "/dev/", with: "")
                // Strip Claude's leading spinner glyph, keep the words.
                let title = String(parts[1].drop { !$0.isLetter && !$0.isNumber })
                    .trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { map[tty] = title }
            }
            DispatchQueue.main.async { self.titles = map }
        }
    }

    private let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/simmer/sessions")
    private var tickCount = 0
    private var previousState: ClaudeState = .idle
    private var liveTTYs: Set<String> = []   // ttys currently owned by a running process

    init(preview: ClaudeState? = nil) {
        if let preview {
            state = preview
            render()
            return
        }
        Notifier.shared.setup()
        refreshLiveTTYs()
        pruneStaleFiles()
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    /// The set of ttys (e.g. "ttys003") currently in use by a running process.
    /// When a terminal is closed — even abruptly — its tty leaves this set, so we
    /// can drop the session immediately, even if SessionEnd never fired.
    private func refreshLiveTTYs() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Ao", "tty="]
        let pipe = Pipe()
        p.standardOutput = pipe
        guard (try? p.run()) != nil else { return }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return }
        var set = Set<String>()
        for line in text.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty && t != "??" { set.insert(t) }
        }
        if !set.isEmpty { liveTTYs = set }   // never wipe on a transient ps failure
    }

    private func tick() {
        tickCount += 1
        if tickCount % 6 == 0 { refreshLiveTTYs() }   // ~every 3s
        let all = readSessions()
        // Show every known session, most urgent first (needs you > working > done > idle).
        let rank: [ClaudeState: Int] = [.action: 3, .working: 2, .done: 1, .idle: 0]
        sessions = all.sorted { (rank[$0.state] ?? 0, $0.project) > (rank[$1.state] ?? 0, $1.project) }
        let aggregate = combine(all.map(\.state))

        if aggregate == .action && previousState != .action {
            Chime.playAlert()
            let who = sessions.first(where: { $0.state == .action })?.project
            Notifier.shared.fire(title: "Clawd needs you",
                                  body: who.map { "\($0) is waiting for input." } ?? "A session is waiting for input.")
        }
        if aggregate == .done && previousState != .done {
            Chime.playDone()
        }
        previousState = aggregate
        state = aggregate
        let c = Connection.isConnected
        if c != connected { connected = c }   // keeps the dropdown's status live
        render()
    }

    private func combine(_ states: [ClaudeState]) -> ClaudeState {
        if states.contains(.action)  { return .action }
        if states.contains(.working) { return .working }
        if states.contains(.done)    { return .done }
        return .idle
    }

    private func render() {
        let pose: Pose
        switch state {
        case .idle:    pose = .sleeping
        case .working: pose = (tickCount % 2 == 0) ? .workingA : .workingB
        case .action:  pose = .action
        case .done:    pose = .eureka
        }
        menuIcon = Critter.menuImages[pose]!
        panelIcon = Critter.panelImages[pose]!

        switch state {
        case .idle:
            menuBarText = ""
            detail = "Idle — nothing cooking"
        case .working:
            let i = Int(Date().timeIntervalSince1970 / 6) % workingWords.count
            menuBarText = "\(workingWords[i])…"
            let workingN = sessions.filter { $0.state == .working }.count
            detail = workingN > 1 ? "\(workingN) sessions working" : "Claude is working"
        case .action:
            menuBarText = "Action needed"
            detail = "Claude needs you — permission or input"
        case .done:
            menuBarText = "Done"
            detail = "Claude finished its turn"
        }
    }

    private func readSessions() -> [SessionStatus] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        let now = Date().timeIntervalSince1970
        var rows: [(s: SessionStatus, ts: Double, url: URL, tty: String)] = []
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = obj["state"] as? String,
                  var st = ClaudeState(rawValue: raw) else { continue }
            let ts = (obj["ts"] as? Double) ?? (obj["ts"] as? NSNumber)?.doubleValue ?? 0
            let age = now - ts
            if age > 1800 { try? FileManager.default.removeItem(at: url); continue }  // stale/crashed
            if st == .done && age > 6 { st = .idle }
            let cwd = (obj["cwd"] as? String) ?? ""
            let tty = (obj["tty"] as? String) ?? ""
            let term = (obj["term"] as? String) ?? ""
            // Terminal gone — its tty is no longer owned by any process? Drop it.
            // Covers closing the window/tab outright (SessionEnd never fires).
            let bareTTY = tty.replacingOccurrences(of: "/dev/", with: "")
            if !bareTTY.isEmpty && !liveTTYs.isEmpty && !liveTTYs.contains(bareTTY) {
                try? FileManager.default.removeItem(at: url); continue
            }
            let s = SessionStatus(id: url.deletingPathExtension().lastPathComponent,
                                  state: st, cwd: cwd, tty: tty, term: term)
            rows.append((s, ts, url, bareTTY))
        }
        // De-duplicate by tty (a closed session's tty can be reused by a new one):
        // keep the newest per tty and delete the superseded files.
        var bestByTTY: [String: (s: SessionStatus, ts: Double, url: URL, tty: String)] = [:]
        var result = rows.filter { $0.tty.isEmpty }.map { $0.s }
        for r in rows where !r.tty.isEmpty {
            if let cur = bestByTTY[r.tty] {
                if r.ts >= cur.ts { try? FileManager.default.removeItem(at: cur.url); bestByTTY[r.tty] = r }
                else { try? FileManager.default.removeItem(at: r.url) }
            } else {
                bestByTTY[r.tty] = r
            }
        }
        result.append(contentsOf: bestByTTY.values.map { $0.s })
        return result
    }

    private func pruneStaleFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-86_400)
        for f in files {
            if let d = try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, d < cutoff {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }
}

// MARK: - Clicking a session focuses its terminal
//
// Uses Apple Events (Automation permission) to bring the matching Terminal tab
// to the front — it can ONLY focus a window, never type or change anything.

enum TerminalFocus {
    static func focus(_ s: SessionStatus) {
        if s.term == "Apple_Terminal" && !s.tty.isEmpty {
            let dev = s.tty.hasPrefix("/dev/") ? s.tty : "/dev/\(s.tty)"
            // Find the window id holding the matching tty, select that tab, then
            // raise the window BY ID (raising via the loop reference is unreliable).
            run("""
            tell application "Terminal"
                set theID to missing value
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(dev)" then
                            set selected of t to true
                            set theID to id of w
                        end if
                    end repeat
                end repeat
                -- Only raise Terminal once we've actually found the matching tab,
                -- so a mislabeled session never pops a blank window.
                if theID is not missing value then
                    activate
                    set frontmost of window id theID to true
                else if (count of windows) > 0 then
                    activate
                end if
            end tell
            """)
        } else if s.term == "iTerm.app" && !s.tty.isEmpty {
            let dev = s.tty.hasPrefix("/dev/") ? s.tty : "/dev/\(s.tty)"
            // iTerm2 exposes a `tty` per session (its term for a split pane). Match
            // it, then select the window, tab, and session so we land on the exact
            // pane — not just the app.
            run("""
            tell application "iTerm"
                set matched to false
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with theSession in sessions of t
                            if tty of theSession is "\(dev)" then
                                set matched to true
                                select w             -- raise the window
                                select t             -- bring the tab to the front
                                select theSession    -- focus the pane within it
                            end if
                        end repeat
                    end repeat
                end repeat
                -- Bring iTerm forward if we found the pane; if not, still raise it
                -- (only when it's already open) so a tmux/split session lands there.
                if matched then
                    activate
                else if (count of windows) > 0 then
                    activate
                end if
            end tell
            """)
        } else if !s.term.isEmpty {
            // Other terminals: just bring the app forward (no per-tab control yet).
            run("tell application \"\(appName(for: s.term))\" to activate")
        }
    }

    private static func appName(for term: String) -> String {
        switch term {
        case "iTerm.app": return "iTerm"
        case "Apple_Terminal": return "Terminal"
        case "ghostty": return "Ghostty"
        default: return term
        }
    }

    private static func run(_ source: String) {
        // Run osascript as a subprocess — reliable, unlike NSAppleScript which
        // silently fails window targeting from a menu-bar app.
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", source]
            try? p.run()
        }
    }
}

// MARK: - Dropdown panel (status + sessions + setup/settings)

// MARK: - Custom session names
//
// User-chosen labels, keyed by Claude's session id and stored in UserDefaults
// (Simmer's own UI state — never touches Claude's data). Local to Simmer: there
// is no way to push a name back into a Claude Code session.

enum SessionNames {
    private static let key = "sessionNames"
    static func all() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }
    static func set(_ raw: String, for sessionID: String) {
        guard !sessionID.isEmpty else { return }
        var map = all()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { map.removeValue(forKey: sessionID) } else { map[sessionID] = trimmed }
        UserDefaults.standard.set(map, forKey: key)
    }
}

struct SimmerMenu: View {
    @ObservedObject var monitor: StatusMonitor
    @State private var launchAtLogin = false
    @State private var hoveredSession: String?
    @State private var settingsBroken = false
    @State private var editingID: String?
    @State private var draftName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status header
            HStack(spacing: 10) {
                Image(nsImage: monitor.panelIcon)
                    .opacity(monitor.state == .idle ? 0.55 : 1)
                    .frame(width: 52, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline).font(.headline)
                    Text(monitor.detail).font(.caption).foregroundStyle(.secondary)
                }
            }

            // Per-session roster: project name + a colored status dot + status
            Divider()
            Text("Sessions").font(.caption).bold().foregroundStyle(.secondary)
            if monitor.sessions.isEmpty {
                Text("No Claude Code sessions yet.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(monitor.sessions) { s in sessionRow(s) }
                    .padding(.horizontal, -8)   // let the hover pill breathe to the edges
            }

            // Connection status / onboarding
            Divider()
            if monitor.connected {
                Label("Connected to Claude Code", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Set up").font(.caption).bold()
                    if settingsBroken {
                        Text("Your ~/.claude/settings.json couldn't be read (invalid JSON). Fix it first — Simmer won't edit a file it can't parse, to avoid wiping your settings.")
                            .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Let Clawd watch your Claude Code sessions. This adds Simmer's hooks to your Claude settings (backed up first).")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button("Connect to Claude Code") {
                            if !Connection.connect() { settingsBroken = true }
                        }
                    }
                }
            }

            Divider()

            // Settings
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { on in LoginItem.set(on) }
            if monitor.connected {
                Button("Disconnect from Claude Code") { Connection.disconnect() }
            }

            if let update = monitor.updateURL {
                Divider()
                Button { NSWorkspace.shared.open(update) } label: {
                    Label("Update available — download", systemImage: "arrow.down.circle.fill")
                        .font(.caption).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            Divider()
            Text("Simmer · for Claude Code\nNot affiliated with Anthropic · Runs entirely on your Mac")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            Button("Quit Simmer") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 280)
        .onAppear {
            launchAtLogin = LoginItem.enabled
            settingsBroken = Connection.settingsUnreadable
            editingID = nil
            monitor.refreshTitles()
            monitor.checkForUpdates()
        }
        .onChange(of: nameFieldFocused) { focused in
            if !focused { commitEditing() }   // commit when the field loses focus
        }
    }

    private func beginEditing(_ s: SessionStatus) {
        draftName = monitor.names[s.id] ?? ""
        editingID = s.id
        nameFieldFocused = true
    }
    private func commitEditing() {
        guard let id = editingID else { return }
        monitor.setName(draftName, for: id)
        editingID = nil
    }

    @ViewBuilder
    private func sessionRow(_ s: SessionStatus) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dotColor(s.state)).frame(width: 7, height: 7)
            if editingID == s.id {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.plain)
                    .focused($nameFieldFocused)
                    .onSubmit { commitEditing() }
                    .onExitCommand { editingID = nil }   // Esc cancels
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
        .onTapGesture(count: 2) { beginEditing(s) }
        .onTapGesture { if editingID == nil { TerminalFocus.focus(s) } }
        .help("Click to jump to its terminal · double-click to rename")
    }

    private var headline: String {
        switch monitor.state {
        case .idle:    return "All quiet"
        case .working: return "Working"
        case .action:  return "Action needed"
        case .done:    return "Done"
        }
    }
    private func word(_ s: ClaudeState) -> String {
        switch s {
        case .idle: return "idle"
        case .working: return "working"
        case .action: return "needs you"
        case .done: return "done"
        }
    }
    // If two sessions share a name (e.g. both running in the home folder), append
    // their unique terminal id so they're distinguishable.
    private func displayName(_ s: SessionStatus) -> String {
        // A name you set yourself wins over everything.
        if let name = monitor.names[s.id], !name.isEmpty { return name }
        // Otherwise prefer Claude's session title (e.g. "Explore Mac app…").
        if let title = monitor.titles[s.tty], !title.isEmpty, title != "Claude Code" {
            return title
        }
        // Otherwise the folder name, disambiguated by tty if two share a name.
        let sameName = monitor.sessions.filter { $0.project == s.project }.count > 1
        if sameName && !s.tty.isEmpty { return "\(s.project) · \(s.tty)" }
        return s.project
    }
    private func dotColor(_ s: ClaudeState) -> Color {
        switch s {
        case .idle: return .gray
        case .working: return .orange
        case .action: return .yellow
        case .done: return .green
        }
    }
}

// MARK: - App

@main
struct SimmerApp: App {
    @StateObject private var monitor = StatusMonitor()

    var body: some Scene {
        MenuBarExtra {
            SimmerMenu(monitor: monitor)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: monitor.menuIcon)
                    .opacity(monitor.state == .idle ? 0.5 : 1)
                if !monitor.menuBarText.isEmpty { Text(monitor.menuBarText) }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Canvas previews

#Preview("Working") { SimmerMenu(monitor: StatusMonitor(preview: .working)) }
#Preview("Action needed") { SimmerMenu(monitor: StatusMonitor(preview: .action)) }
#Preview("Done") { SimmerMenu(monitor: StatusMonitor(preview: .done)) }
#Preview("Idle") { SimmerMenu(monitor: StatusMonitor(preview: .idle)) }

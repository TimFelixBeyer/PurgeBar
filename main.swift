import AppKit

// Menubar app that asks macOS to purge "purgeable" space (local snapshots,
// evictable iCloud files, system-managed caches) so it becomes available space.
//
// The purge is done via `tmutil thinlocalsnapshots / <amount> 4`, which hands the
// request to the CacheDelete daemon (`deleted`) at the highest urgency — the same
// mechanism macOS itself uses when a disk runs low. No root required.

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let infoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let resultItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let purgeItem = NSMenuItem(title: "Free Purgeable Space", action: #selector(purge), keyEquivalent: "p")
    private var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "PurgeBar")
        infoItem.isEnabled = false
        resultItem.isEnabled = false
        resultItem.isHidden = true
        purgeItem.target = self
        menu.delegate = self
        menu.addItem(infoItem)
        menu.addItem(resultItem)
        menu.addItem(.separator())
        menu.addItem(purgeItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func space() -> (available: Int64, purgeable: Int64) {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let v = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys),
              let avail = v.volumeAvailableCapacity,
              let important = v.volumeAvailableCapacityForImportantUsage else { return (0, 0) }
        return (Int64(avail), max(0, important - Int64(avail)))
    }

    private func fmt(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func refresh() {
        let s = space()
        infoItem.title = "Available: \(fmt(s.available))   Purgeable: ~\(fmt(s.purgeable))"
        purgeItem.title = busy ? "Freeing…" : "Free Purgeable Space"
        purgeItem.isEnabled = !busy
    }

    @objc private func purge() {
        busy = true
        refresh()
        let before = space().available
        DispatchQueue.global(qos: .userInitiated).async {
            // Two passes: the first purge often exposes more purgeable data.
            var error: String?
            for _ in 0..<2 {
                if let e = Self.run("/usr/bin/tmutil", ["thinlocalsnapshots", "/", "999999999999999", "4"]) {
                    error = e
                    break
                }
            }
            // Give the volume a moment to report the reclaimed space.
            Thread.sleep(forTimeInterval: 2)
            DispatchQueue.main.async {
                self.busy = false
                let freed = self.space().available - before
                self.resultItem.title = error.map { "Error: \($0)" }
                    ?? (freed > 0 ? "Freed \(self.fmt(freed))" : "Nothing more to free right now")
                self.resultItem.isHidden = false
                self.refresh()
            }
        }
    }

    /// Runs a command, returning nil on success or an error message.
    private static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return error.localizedDescription }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        return p.terminationStatus == 0 ? nil : out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

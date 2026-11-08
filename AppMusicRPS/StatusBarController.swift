import AppKit

class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer: Timer?
    private var lastTrack: TrackInfo?
    private let musicBridge = AppleMusicBridge()
    var discordBridge: DiscordBridge?

    init() {
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        buildMenu(track: nil)
        discordBridge = DiscordBridge()
        startPolling()
    }

    private func buildMenu(track: TrackInfo?) {
        let menu = NSMenu()
        let label: String
        if let t = track {
            let prefix = t.isPlaying ? "▶" : "⏸"
            let combined = "\(t.title) - \(t.artist)"
            let truncated = combined.count > 40 ? String(combined.prefix(37)) + "..." : combined
            label = "\(prefix) \(truncated)"
        } else {
            label = "Şu an çalmıyor"
        }
        let infoItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Çıkış", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        // Update icon
        let iconName = (track?.isPlaying == true) ? "music.note" : "pause.fill"
        statusItem.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.fire()
    }

    func poll() {
        let track = musicBridge.currentTrack()
        guard track != lastTrack else { return }
        lastTrack = track
        buildMenu(track: track)
        discordBridge?.send(track: track)
    }
}

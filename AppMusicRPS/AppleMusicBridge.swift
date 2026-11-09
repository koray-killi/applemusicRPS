import AppKit

struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let position: Double  // seconds elapsed
    let duration: Double  // total seconds
}

class AppleMusicBridge {
    private let script = """
        tell application "Music" to return (name of current track) & "\n" & (artist of current track) & "\n" & (album of current track) & "\n" & (player state as string) & "\n" & (player position as string) & "\n" & (duration of current track as string)
        """

    func isMusicRunning() -> Bool {
        NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    func currentTrack() -> TrackInfo? {
        guard isMusicRunning() else { return nil }
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        guard let output = result.stringValue else { return nil }
        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 6 else { return nil }
        return TrackInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: parts[3] == "playing",
            position: Double(parts[4]) ?? 0,
            duration: Double(parts[5]) ?? 0
        )
    }
}

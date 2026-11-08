import Foundation

struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
}

class AppleMusicBridge {
    private let script = """
        tell application "System Events"
            if exists process "Music" then
                tell application "Music"
                    set t to name of current track
                    set ar to artist of current track
                    set al to album of current track
                    set st to player state
                    return t & "\n" & ar & "\n" & al & "\n" & (st as string)
                end tell
            end if
        end tell
        """

    func currentTrack() -> TrackInfo? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error)
        if error != nil { return nil }
        guard let output = result.stringValue else { return nil }
        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 4 else { return nil }
        return TrackInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: parts[3] == "playing"
        )
    }
}

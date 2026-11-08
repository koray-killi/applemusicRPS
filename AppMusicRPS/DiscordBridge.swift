import Foundation

class DiscordBridge {
    private var process: Process?
    private var stdinPipe: Pipe?
    private var isRestarting = false

    init() { startProcess() }

    private func startProcess() {
        guard let binaryURL = Bundle.main.url(forResource: "discord-rpc", withExtension: nil) else {
            return
        }
        let p = Process()
        p.executableURL = binaryURL
        let input = Pipe()
        p.standardInput = input
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self?.stdinPipe = nil  // invalidate before restart
                self?.startProcess()
            }
        }
        try? p.run()
        process = p
        stdinPipe = input
    }

    func send(track: TrackInfo?) {
        guard let pipe = stdinPipe, process?.isRunning == true else { return }
        let payload: [String: Any]
        if let t = track, t.isPlaying {
            payload = ["title": t.title, "artist": t.artist, "album": t.album, "playing": true]
        } else {
            payload = ["playing": false]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else { return }
        pipe.fileHandleForWriting.write(Data((line + "\n").utf8))
    }
}

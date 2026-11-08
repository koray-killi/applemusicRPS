import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance guard
        let running = NSWorkspace.shared.runningApplications
        let count = running.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }.count
        if count > 1 { NSApp.terminate(nil); return }

        statusBarController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.discordBridge?.send(track: nil)
    }
}

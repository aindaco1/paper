// Test-only real Space transitions and system sleep/wake observation.
import AppKit

final class LifecycleFixture: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let events = URL(fileURLWithPath: CommandLine.arguments[1])
    let commands = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
    var window: NSWindow?
    var timer: Timer?
    var observers: [NSObjectProtocol] = []
    func record(_ event: String) {
        let value: [String: Any] = ["event": event, "time": Date().timeIntervalSince1970,
            "fullscreen": window?.styleMask.contains(.fullScreen) ?? false,
            "frontPID": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0]
        let data = try! JSONSerialization.data(withJSONObject: value, options: .sortedKeys) + Data([10])
        let handle = try! FileHandle(forWritingTo: events)
        defer { try? handle.close() }
        try! handle.seekToEnd(); try! handle.write(contentsOf: data)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        FileManager.default.createFile(atPath: events.path, contents: nil)
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in self?.record(name.rawValue)
            })
        }
        if let commands {
            let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 700, height: 460),
                styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Paper fullscreen test"
            window.collectionBehavior = [.fullScreenPrimary]
            window.backgroundColor = .windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                guard let command = try? String(contentsOf: commands, encoding: .utf8) else { return }
                try? FileManager.default.removeItem(at: commands)
                if command == "enter" || command == "exit" { window.toggleFullScreen(nil) }
                else if command == "quit" { NSApp.terminate(nil) }
            }
        }
        record("ready")
    }
    func windowDidEnterFullScreen(_ notification: Notification) { record("entered-fullscreen") }
    func windowDidExitFullScreen(_ notification: Notification) { record("exited-fullscreen") }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) { record("fullscreen-failed") }
}
let app = NSApplication.shared
let fixture = LifecycleFixture()
app.delegate = fixture
app.setActivationPolicy(CommandLine.arguments.count > 2 ? .regular : .accessory)
withExtendedLifetime(fixture) { app.run() }

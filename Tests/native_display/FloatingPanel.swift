// Test-only accessory app: its panel never activates, like a notch/menu-bar utility.
import AppKit

final class FixturePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = FixturePanel(contentRect: NSRect(x: 60, y: 60, width: 240, height: 100),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: 27)
        panel.backgroundColor = .white
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.orderFrontRegardless()
        self.panel = panel
    }
}
let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
withExtendedLifetime(delegate) { app.run() }

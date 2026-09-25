// Test-only local input and cancellable system authorization. Never authenticates a purchase.
import AppKit
import LocalAuthentication

final class InteractionFixture: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var context: LAContext?
    var timeout: Timer?
    var clicks = 0
    let label = NSTextField(labelWithString: "Clicks received: 0")
    let status = NSTextField(wrappingLabelWithString: "Authorization is optional. Cancel the prompt; no credential or biometric is needed.")
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 100,y: 100,width: 620,height: 400), styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false)
        window.title = "Paper input and authorization test"
        window.isReleasedWhenClosed = false
        let stack = NSStackView(views: [NSTextField(labelWithString: "Paper test surface"),
            NSTextField(wrappingLabelWithString: "Read this text through the clear strip. The strip moves without taking focus. Use presentation pause before authorization or capture."),
            NSButton(title: "Click-through test", target: self, action: #selector(click)), label,
            NSButton(title: "Show authorization prompt", target: self, action: #selector(authorize)), status])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 24,left: 24,bottom: 24,right: 24)
        window.contentView = stack
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func click() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); clicks += 1; label.stringValue = "Clicks received: \(clicks)" }
    @objc func authorize() {
        context?.invalidate(); timeout?.invalidate()
        let context = LAContext(); self.context = context
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            status.stringValue = "System authorization unavailable on this host."; return
        }
        status.stringValue = "Cancel the system prompt. It also cancels automatically after 20 seconds."
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Test Paper’s presentation pause. Cancel this prompt; authentication is not required.") { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.timeout?.invalidate()
                self?.status.stringValue = success ? "Authorization completed; no further action is performed." : "Authorization cancelled. No further action was performed."
            }
        }
        timeout = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { _ in context.invalidate() }
    }
}
let app = NSApplication.shared
let fixture = InteractionFixture()
app.delegate = fixture; app.setActivationPolicy(.regular)
withExtendedLifetime(fixture) { app.run() }

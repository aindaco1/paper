// Test-only input and independent Accessibility oracle. Never bundled with Paper.
import AppKit
import ApplicationServices
import Darwin

func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }
func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name, &value)
    return value
}
func frame(_ element: AXUIElement) -> CGRect? {
    guard let position = attribute(element, kAXPositionAttribute as CFString),
          let size = attribute(element, kAXSizeAttribute as CFString),
          CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero; var dimensions = CGSize.zero
    guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
          AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
    return CGRect(origin: point, size: dimensions)
}
func move(_ point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point,
            mouseButton: .left)?.post(tap: .cghidEventTap)
}
func key(_ code: CGKeyCode, _ down: Bool, _ flags: CGEventFlags) {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    event.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
}
func main() {
    guard AXIsProcessTrusted() else { fail("Existing Accessibility permission is required") }
    guard let mode = CommandLine.arguments.dropFirst().first, ["dock", "switcher"].contains(mode),
          let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
        fail("Usage: DockInteractionProbe dock|switcher; Dock must be running")
    }
    let application = AXUIElementCreateApplication(dock.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 1)
    func children() -> [AXUIElement] { attribute(application, kAXChildrenAttribute as CFString) as? [AXUIElement] ?? [] }
    func lists() -> [AXUIElement] { children().filter { attribute($0, kAXRoleAttribute as CFString) as? String == "AXList" } }
    let originalPointer = CGEvent(source: nil)!.location
    let screens = NSScreen.screens.compactMap { screen -> CGRect? in
        guard let id = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else { return nil }
        return CGDisplayBounds(id.uint32Value)
    }
    // Leave the Dock before starting; no system preferences are changed.
    guard let primary = screens.first else { fail("No displays") }
    move(CGPoint(x: primary.midX, y: primary.midY))
    Thread.sleep(forTimeInterval: 0.7)
    let baselineCount = lists().count
    guard baselineCount == 1 else { fail("Close system overviews and the app switcher before testing") }
    var commandHeld = false
    defer {
        if commandHeld {
            key(53, true, .maskCommand); key(53, false, .maskCommand)
            key(55, false, [])
        }
        move(originalPointer)
    }
    if mode == "dock" {
        guard let dockFrame = lists().first.flatMap(frame), let screen = screens.min(by: {
            hypot($0.midX - dockFrame.midX, $0.midY - dockFrame.midY) <
                hypot($1.midX - dockFrame.midX, $1.midY - dockFrame.midY)
        }) else { fail("Cannot locate Dock") }
        move(CGPoint(x: min(screen.maxX - 1, max(screen.minX + 1, dockFrame.midX)),
                     y: min(screen.maxY - 1, max(screen.minY + 1, dockFrame.midY))))
    } else {
        commandHeld = true
        key(55, true, .maskCommand)
        key(48, true, .maskCommand); key(48, false, .maskCommand)
    }
    func active() -> Bool {
        guard !children().contains(where: { attribute($0, kAXIdentifierAttribute as CFString) as? String == "mc" }) else { return false }
        if mode == "switcher" { return lists().count > baselineCount }
        guard let dockFrame = lists().first.flatMap(frame) else { return false }
        return screens.contains { $0.intersection(dockFrame).height > 10 && $0.intersection(dockFrame).width > 10 }
    }
    let deadline = Date().addingTimeInterval(5)
    while !active(), Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
    // A timeout still takes the defer path to release Command and restore pointer.
    guard active() else { fputs("Interaction did not appear\n", stderr); return }
    print("{\"interaction\":\"\(mode)\",\"active\":true}"); fflush(stdout)
    // Keep the interaction present while Python samples Paper. EOF releases it,
    // even if the driver fails; a bounded wait also protects against abandonment.
    var input = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN | POLLHUP), revents: 0)
    _ = poll(&input, 1, 12_000)
    print("{\"interaction\":\"\(mode)\",\"active\":\(active())}"); fflush(stdout)
}
main()

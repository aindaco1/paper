// Test-only Mission Control state inspection. No screen capture or window titles.
import AppKit
import ApplicationServices

func fail(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}

guard AXIsProcessTrusted() else { fail("Existing Accessibility permission is required") }
guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
    fail("Dock is unavailable")
}
let application = AXUIElementCreateApplication(dock.processIdentifier)
AXUIElementSetMessagingTimeout(application, 1)
var children: CFTypeRef?
guard AXUIElementCopyAttributeValue(application, kAXChildrenAttribute as CFString, &children) == .success,
      let elements = children as? [AXUIElement] else { fail("Cannot inspect Dock children") }
// The test must observe this group after opening Mission Control; an unsupported
// Dock accessibility hierarchy times out instead of counting as an entry/pass.
let active = elements.contains { element in
    var identifier: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
    return identifier as? String == "mc"
}
print(active ? "true" : "false")

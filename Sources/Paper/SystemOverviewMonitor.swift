import AppKit

/// A full-display Dock surface is a system overview (Mission Control, or Launchpad
/// on older macOS). Inspect only public ownership, layer and geometry metadata.
@MainActor
final class SystemOverviewMonitor {
    private(set) var isActive = false
    private var enabled = false
    private var timer: Timer?
    private var onChange: (() -> Void)?
    private var dock: NSRunningApplication?
    private var displays: [CGRect] = []

    func start(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func update(enabled: Bool) {
        self.enabled = enabled
        displays = NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[.init("NSScreenNumber")] as? NSNumber else { return nil }
            return CGDisplayBounds(number.uint32Value)
        }
        refresh()
    }

    private func refresh() {
        let active = enabled && overviewIsVisible()
        // Occlusion notifications arrive after the entry animation. Query the
        // current Dock surfaces early enough to keep Paper out of Space thumbnails.
        // The timer stops whenever no overlay is eligible to appear.
        if enabled, timer == nil {
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            timer.tolerance = 0.005
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !enabled {
            timer?.invalidate()
            timer = nil
        }
        guard active != isActive else { return }
        isActive = active
        onChange?()
    }

    private func overviewIsVisible() -> Bool {
        if dock == nil || dock?.isTerminated == true {
            dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        }
        // Dock can retain an old overview window while creating another one.
        // Always inspect current on-screen windows rather than caching their IDs.
        guard let dock,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == dock.processIdentifier,
                  window[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.dockWindow)),
                  let alpha = window[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return displays.contains { frame.insetBy(dx: -1, dy: -1).contains($0) }
        }
    }

    func stop() {
        enabled = false
        timer?.invalidate()
        timer = nil
        onChange = nil
        isActive = false
        dock = nil
        displays = []
    }
}

import AppKit
import PaperCore

/// Inspect public ownership, layer and geometry metadata for overview surfaces.
@MainActor
final class SystemOverviewMonitor {
    private(set) var isActive = false
    private var enabled = false
    private var timer: Timer?
    private var onChange: (() -> Void)?
    private var owners: [String: NSRunningApplication] = [:]
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
        // current overview surfaces early enough to keep Paper out of Space thumbnails.
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
        for id in ["com.apple.dock", "com.apple.WindowManager"] {
            if owners[id] == nil || owners[id]?.isTerminated == true {
                owners[id] = NSRunningApplication.runningApplications(withBundleIdentifier: id).first
            }
        }
        // The system can retain an old overview window while creating another one.
        // Always inspect current on-screen windows rather than caching their IDs.
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { window in
            guard let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let owner = owners.first(where: { $0.value.processIdentifier == pid })?.key,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let alpha = window[kCGWindowAlpha as String] as? Double,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return SystemOverviewPolicy.isOverviewSurface(ownerBundleID: owner, layer: layer, alpha: alpha,
                frame: frame, displays: displays, dockWindowLevel: Int(CGWindowLevelForKey(.dockWindow)))
        }
    }

    func stop() {
        enabled = false
        timer?.invalidate()
        timer = nil
        onChange = nil
        isActive = false
        owners = [:]
        displays = []
    }
}

import AppKit
import Combine
import PaperCore

/// Floating panels can appear without activating their app. Observe their public
/// window metadata, not titles or pixels. No Accessibility or capture permission.
@MainActor
final class ExcludedPanelMonitor {
    private let state: PaperState
    private var changes: AnyCancellable?
    private var refreshPending = false
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var sessionActive = true
    private var asleep = false

    init(state: PaperState) { self.state = state }

    func start() {
        changes = state.objectWillChange.sink { [weak self] in self?.scheduleRefresh() }
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        for (name, active) in [(NSWorkspace.willSleepNotification, false),
                               (NSWorkspace.sessionDidResignActiveNotification, false),
                               (NSWorkspace.didWakeNotification, true),
                               (NSWorkspace.sessionDidBecomeActiveNotification, true)] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    if name == NSWorkspace.willSleepNotification || name == NSWorkspace.didWakeNotification {
                        self?.asleep = !active
                    } else { self?.sessionActive = active }
                    self?.refresh()
                }
            })
        }
    }

    private func scheduleRefresh() {
        guard !refreshPending else { return }
        refreshPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshPending = false
            self.refresh()
        }
    }

    private func refresh() {
        let visible = sessionActive && !asleep && state.pauseReason == nil &&
            state.displayChoices.contains { !state.settings.disabledDisplays.contains($0.id) }
        let bundleIDs = visible ? Set(state.settings.excludedApps.map(\.bundleID)) : []
        let pids = Set(NSWorkspace.shared.runningApplications.compactMap { app -> pid_t? in
            guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier, bundleIDs.contains(id), !app.isHidden else { return nil }
            return app.processIdentifier
        })
        // No periodic work while paused, off, asleep, or without a relevant running app.
        if !pids.isEmpty, timer == nil {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if pids.isEmpty {
            timer?.invalidate(); timer = nil
        }
        let windows = pids.isEmpty ? [] : (CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
        let levels = Set(windows.compactMap { window -> Int? in
            guard let owner = window[kCGWindowOwnerPID as String] as? NSNumber, pids.contains(owner.int32Value),
                  let alpha = window[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let level = window[kCGWindowLayer as String] as? Int,
                  level > NSWindow.Level.normal.rawValue else { return nil }
            return level
        }).sorted()
        if state.excludedPanelLevels != levels { state.excludedPanelLevels = levels }
    }

    func stop() {
        changes = nil
        timer?.invalidate(); timer = nil
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        state.excludedPanelLevels = []
    }
}

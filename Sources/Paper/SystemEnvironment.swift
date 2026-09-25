import AppKit
import IOKit.ps

@MainActor
final class SystemEnvironment {
    private let state: PaperState
    private var observers: [NSObjectProtocol] = []
    private var powerSource: CFRunLoopSource?
    init(state: PaperState) { self.state = state }

    func start() {
        updateFrontmost(NSWorkspace.shared.frontmostApplication)
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in self?.updateFrontmost(app) }
        })
        for name in [Notification.Name.NSProcessInfoPowerStateDidChange,
                     NSNotification.Name.NSSystemTimeZoneDidChange,
                     NSNotification.Name.NSSystemClockDidChange,
                     NSApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in self?.refresh() }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refresh() } })
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let owner = Unmanaged<SystemEnvironment>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in owner.refresh() }
        }
        if let source = IOPSNotificationCreateRunLoopSource(callback, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue() {
            powerSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        refresh()
    }
    private func updateFrontmost(_ app: NSRunningApplication?) {
        // Opening Paper's controls must not bypass the app rule underneath them.
        let id = app?.bundleIdentifier
        guard id == nil || id != Bundle.main.bundleIdentifier else { return }
        if state.frontmostBundleID != id { state.frontmostBundleID = id; state.refreshClock() }
    }
    func refresh() {
        let oldPower = (state.onBattery, state.lowPower)
        updateFrontmost(NSWorkspace.shared.frontmostApplication)
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() {
            state.onBattery = (type as String) == (kIOPSBatteryPowerValue as String)
        } else { state.onBattery = false }
        state.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if oldPower != (state.onBattery, state.lowPower) { state.record(.powerChanged) }
        state.refreshClock()
        state.refreshLogin()
    }
    func stop() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        if let source = powerSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        powerSource = nil
    }
}

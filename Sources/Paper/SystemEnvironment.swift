import AppKit
import IOKit.ps

@MainActor
final class SystemEnvironment {
    private let state: PaperState
    private var observers: [NSObjectProtocol] = []
    private var powerSource: CFRunLoopSource?
    private var appearanceObservation: NSKeyValueObservation?
    init(state: PaperState) { self.state = state }

    func start() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshAppearance() }
        }
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
        state.batteryPercentage = nil
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            state.onBattery = (IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?) == kIOPSBatteryPowerValue
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
            for source in sources {
                guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                      let current = description[kIOPSCurrentCapacityKey] as? Int,
                      let maximum = description[kIOPSMaxCapacityKey] as? Int,
                      maximum > 0, current >= 0, current <= maximum else { continue }
                state.batteryPercentage = Int(Double(current) / Double(maximum) * 100)
                break
            }
        } else { state.onBattery = false }
        state.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if oldPower != (state.onBattery, state.lowPower) { state.record(.powerChanged) }
        state.refreshClock()
        state.refreshLogin()
        refreshAppearance()
    }
    private func refreshAppearance() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if state.darkAppearance != dark { state.darkAppearance = dark }
    }
    func stop() {
        appearanceObservation = nil
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

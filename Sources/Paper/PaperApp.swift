import AppKit
import SwiftUI
import Combine
import PaperCore
import AppIntents
import DustWaveUpdates
import Carbon

@main
enum PaperApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = PaperAppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class PaperAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var state: PaperState!
    private var overlay: OverlayController!
    private var environment: SystemEnvironment!
    private var excludedPanels: ExcludedPanelMonitor!
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private var diagnosticsWindow: NSWindow?
    private var diagnostics: PaperDiagnostics!
    private var updates: AppUpdateController!
    private var launchedAtLogin = false
    private let shortcut = GlobalShortcut()
    private var subscription: AnyCancellable?
    private var priorShortcutEnabled: Bool?
    private var previousSettings: PaperCoreSettingsSnapshot?

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        state = PaperState.shared
        state.record(launchedAtLogin ? .loginLaunch : .launch)
        updates = AppUpdateController(startingUpdater: !PaperState.isTestRun)
        diagnostics = PaperDiagnostics(state: state, updates: updates)
        overlay = OverlayController(state: state)
        environment = SystemEnvironment(state: state)
        excludedPanels = ExcludedPanelMonitor(state: state)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Paper")
        statusItem.button?.setAccessibilityLabel("Paper")
        statusItem.button?.toolTip = "Paper — a softer surface for your screen"
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        installMainMenu()
        shortcut.onToggle = { [weak self] in self?.state.toggle() }
        subscription = state.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.synchronize() }
        }
        environment.start()
        excludedPanels.start()
        overlay.start()
        synchronize()
        PaperShortcuts.updateAppShortcutParameters()
        // Explicit background launches omit the controls; reopening always shows them.
        if !launchedAtLogin && !ProcessInfo.processInfo.arguments.contains("--background") { showSettings() }
        updates.checkOnLaunch()
    }

    private func synchronize() {
        let enabled = state.settings.shortcutEnabled
        if priorShortcutEnabled != enabled {
            priorShortcutEnabled = enabled
            let status = shortcut.setEnabled(enabled)
            if status != 0 { state.record(.shortcutUnavailable) }
            state.shortcutError = status == 0 ? nil : "The shortcut is unavailable (\(status)). Use the menu bar, or turn it off here."
        }
        let schedule = PaperCoreSettingsSnapshot(state: state)
        if previousSettings != schedule { previousSettings = schedule; state.scheduleBoundary() }
        let showing = state.pauseReason == nil && state.displayChoices.contains { state.reason(for: $0.id) == nil }
        statusItem.button?.image = NSImage(systemSymbolName: showing ? "doc.text.fill" : "doc.text", accessibilityDescription: state.status)
        statusItem.button?.setAccessibilityLabel("Paper: \(state.status)")
        statusItem.button?.toolTip = state.status
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: state.status, action: nil, keyEquivalent: "")
        menu.addItem(status)
        menu.addItem(.separator())
        addItem(state.settings.enabled ? "Turn Paper off" : "Turn Paper on", action: #selector(togglePaper), to: menu)
        if let until = state.settings.snoozeUntil, until > Date() {
            addItem("End snooze", action: #selector(endSnooze), to: menu)
        }
        let snoozeItem = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
        let snoozeMenu = NSMenu()
        snoozeMenu.autoenablesItems = false
        for option in SnoozeOption.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(snooze(_:)), keyEquivalent: "")
            item.target = self
            item.tag = option.rawValue
            item.isEnabled = state.settings.enabled
            snoozeMenu.addItem(item)
        }
        snoozeMenu.addItem(.separator())
        addItem("Custom duration…", action: #selector(customSnooze), to: snoozeMenu)
        snoozeMenu.items.last?.isEnabled = state.settings.enabled
        snoozeItem.submenu = snoozeMenu
        menu.addItem(snoozeItem)
        addItem("Settings…", action: #selector(showSettings), to: menu, key: ",")
        addItem("Check for Updates…", action: #selector(checkForUpdates), to: menu)
        menu.items.last?.isEnabled = updates.canCheckForUpdates && !updates.busy
        addItem("Help & diagnostics…", action: #selector(showDiagnostics), to: menu)
        menu.addItem(.separator())
        addItem("Quit Paper", action: #selector(quit), to: menu, key: "q")
    }
    private func addItem(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    @objc private func checkForUpdates() { updates.checkForUpdates() }
    @objc private func showDiagnostics() {
        if diagnosticsWindow == nil {
            let created = NSWindow(contentViewController: NSHostingController(rootView: PaperDiagnosticsView(model: diagnostics)))
            created.title = "Paper — Help & diagnostics"
            created.styleMask = [.titled, .closable]
            created.isReleasedWhenClosed = false
            created.center()
            diagnosticsWindow = created
        }
        diagnostics.prepare()
        NSApp.activate(ignoringOtherApps: true)
        diagnosticsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc private func togglePaper() { state.toggle() }
    @objc private func snooze(_ sender: NSMenuItem) {
        guard let option = SnoozeOption(rawValue: sender.tag) else { return }
        state.snooze(option)
    }
    @objc private func customSnooze() { showSettings(); state.showingCustomSnooze = true }
    @objc private func endSnooze() { state.settings.snoozeUntil = nil }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func showSettings() {
        state.refreshClock()
        state.refreshLogin()
        if window == nil {
            let host = NSHostingController(rootView: PaperView(state: state, updates: updates, showDiagnostics: { [weak self] in self?.showDiagnostics() }))
            let created = NSWindow(contentViewController: host)
            created.title = "Paper"
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.isReleasedWhenClosed = false
            created.minSize = NSSize(width: 500, height: 580)
            created.setContentSize(NSSize(width: 500, height: 680))
            created.center()
            created.delegate = self
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        state.comparing = false
        state.showingCustomSnooze = false
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        state.record(.cleanQuit)
        subscription = nil
        shortcut.stop()
        overlay.stop()
        environment.stop()
        excludedPanels.stop()
        state.stop()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let app = NSMenu()
        appItem.submenu = app
        app.addItem(withTitle: "About Paper", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        addItem("Check for Updates…", action: #selector(checkForUpdates), to: app)
        addItem("Help & diagnostics…", action: #selector(showDiagnostics), to: app)
        app.addItem(.separator())
        addItem("Quit Paper", action: #selector(quit), to: app, key: "q")
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        editItem.submenu = edit
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        NSApp.mainMenu = main
    }
}

/// Only changes that affect the next timer boundary trigger rescheduling.
private struct PaperCoreSettingsSnapshot: Equatable {
    let schedule: PaperSchedule
    let snooze: Date?
    let automaticLooks: AutomaticLooks
    @MainActor init(state: PaperState) {
        schedule = state.settings.schedule
        automaticLooks = state.settings.automaticLooks
        snooze = state.settings.snoozeUntil
    }
}

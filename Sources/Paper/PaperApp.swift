import AppKit
import SwiftUI
import Combine

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
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let shortcut = GlobalShortcut()
    private var subscription: AnyCancellable?
    private var priorShortcutEnabled: Bool?
    private var previousSettings: PaperCoreSettingsSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = PaperState()
        overlay = OverlayController(state: state)
        environment = SystemEnvironment(state: state)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Paper")
        statusItem.button?.setAccessibilityLabel("Paper")
        statusItem.button?.toolTip = "Paper — a softer surface for your screen"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        installMainMenu()
        shortcut.onToggle = { [weak self] in self?.state.toggle() }
        subscription = state.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.synchronize() }
        }
        environment.start()
        overlay.start()
        synchronize()
        // Explicit background launches omit the controls; reopening always shows them.
        if !ProcessInfo.processInfo.arguments.contains("--background") { showSettings() }
    }

    private func synchronize() {
        let enabled = state.settings.shortcutEnabled
        if priorShortcutEnabled != enabled {
            priorShortcutEnabled = enabled
            let status = shortcut.setEnabled(enabled)
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
        } else {
            addItem("Snooze for 15 minutes", action: #selector(snooze), to: menu)
        }
        addItem("Settings…", action: #selector(showSettings), to: menu, key: ",")
        menu.addItem(.separator())
        addItem("Quit Paper", action: #selector(quit), to: menu, key: "q")
    }
    private func addItem(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    @objc private func togglePaper() { state.toggle() }
    @objc private func snooze() { state.snooze(minutes: 15) }
    @objc private func endSnooze() { state.settings.snoozeUntil = nil }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func showSettings() {
        state.refreshClock()
        state.refreshLogin()
        if window == nil {
            let host = NSHostingController(rootView: PaperView(state: state))
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
    func windowWillClose(_ notification: Notification) { state.comparing = false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        subscription = nil
        shortcut.stop()
        overlay.stop()
        environment.stop()
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
    let start: Int
    let end: Int
    let enabled: Bool
    let snooze: Date?
    @MainActor init(state: PaperState) {
        start = state.settings.schedule.startMinute
        end = state.settings.schedule.endMinute
        enabled = state.settings.schedule.enabled
        snooze = state.settings.snoozeUntil
    }
}

import XCTest
import AppKit
import Carbon
import PaperCore
@testable import Paper

@MainActor
final class WorkflowStateTests: XCTestCase {
    private func withState(_ body: (PaperState, UserDefaults) throws -> Void) rethrows {
        let name = "xyz.dustwave.paper.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(PaperState(defaults: defaults), defaults)
    }
    func testTextureRecallFavoritesAndRestart() throws {
        try withState { state, defaults in
            state.settings.intensity = 0.3
            state.toggleFavorite()
            try state.selectTexture("quiet-gray")
            state.settings.intensity = 0.1
            state.toggleFavorite()
            state.nextFavorite()
            XCTAssertEqual(state.texture.id, "classic-matte")
            XCTAssertEqual(state.settings.intensity, 0.3)
            let restarted = PaperState(defaults: defaults)
            try restarted.selectTexture("quiet-gray")
            XCTAssertEqual(restarted.settings.intensity, 0.1)
        }
    }
    func testAppLookWinsOverSystemLookButNeverBypassesExclusion() throws {
        try withState { state, _ in
            let light = try state.saveLook(name: "Light")
            try state.selectTexture("quiet-gray")
            let dark = try state.saveLook(name: "Dark")
            state.settings.automaticLooks.enabled = true
            state.settings.automaticLooks.trigger = .systemAppearance
            state.settings.automaticLooks.dayLookID = light; state.settings.automaticLooks.nightLookID = dark
            state.darkAppearance = true
            XCTAssertEqual(state.texture.id, "quiet-gray")
            state.settings.appLooks["example.reader"] = light
            state.settings.appLooksEnabled = true; state.frontmostBundleID = "example.reader"
            XCTAssertEqual(state.texture.id, "classic-matte")
            state.settings.excludedApps = [.init(bundleID: "example.reader", name: "Reader")]
            XCTAssertEqual(state.pauseReason, .applicationExcluded)
            state.removeLook(light)
            XCTAssertNil(state.settings.appLooks["example.reader"])
            try state.selectTexture("quiet-gray")
            XCTAssertFalse(state.settings.appLooksEnabled)
            XCTAssertFalse(state.settings.automaticLooks.enabled)
        }
    }
    func testDeskReconnectAndRelaunchDoNotReapplyDuringManualEdits() throws {
        try withState { state, defaults in
            let screen = DisplayChoice(id: "internal", name: "Internal")
            state.displaysChanged([screen])
            state.settings.intensity = 0.4
            try state.saveDesk(name: "Laptop")
            state.settings.intensity = 0.1
            state.displaysChanged([screen])
            XCTAssertEqual(state.settings.intensity, 0.1)
            state.displaysChanged([screen, DisplayChoice(id: "external", name: "External")])
            state.settings.enabled = false
            state.settings.presentationPaused = true
            state.displaysChanged([screen])
            XCTAssertEqual(state.settings.intensity, 0.4)
            XCTAssertFalse(state.settings.enabled); XCTAssertTrue(state.settings.presentationPaused)
            let restarted = PaperState(defaults: defaults)
            restarted.displaysChanged([screen])
            XCTAssertEqual(restarted.deskProfiles.count, 1)
            XCTAssertFalse(restarted.settings.enabled); XCTAssertTrue(restarted.settings.presentationPaused)
            restarted.removeDesk(restarted.deskProfiles[0].id)
            XCTAssertTrue(PaperState(defaults: defaults).deskProfiles.isEmpty)
        }
    }
    func testPresentationSurvivesRelaunchAndOrdinaryToggle() throws {
        try withState { state, defaults in
            state.perform(.presentation)
            state.toggle(); state.toggle()
            XCTAssertEqual(state.pauseReason, .presentation)
            let restarted = PaperState(defaults: defaults)
            XCTAssertEqual(restarted.pauseReason, .presentation)
            restarted.perform(.presentation)
            XCTAssertNil(restarted.pauseReason)
            XCTAssertNoThrow(try PaperDiagnosticReport.snapshot(restarted).encoded())
        }
    }
    func testShortcutConflictIsReportedAndOtherBindingsRemainIndependent() {
        let registrar = GlobalShortcut()
        defer { registrar.stop() }
        var settings = ShortcutSettings()
        // Avoid the running app's real shortcut and common system shortcuts.
        settings.toggle = ShortcutBinding(key: "J", control: true)
        settings.snooze = settings.toggle
        let error = registrar.configure(enabled: true, settings: settings)
        XCTAssertTrue(error?.contains("already assigned") == true)
        settings.snooze = nil
        XCTAssertNil(registrar.configure(enabled: true, settings: settings))
        let second = GlobalShortcut()
        defer { second.stop() }
        XCTAssertNotNil(second.configure(enabled: true, settings: settings))
        XCTAssertNil(registrar.configure(enabled: false, settings: settings))
        XCTAssertNil(second.configure(enabled: true, settings: settings))
    }
    func testLeaseRejectsParallelOwnerAndSymlinkAndReleasesOnClose() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var first: InstanceLease? = try InstanceLease(directory: directory, name: "main.lock")
        XCTAssertTrue(try first!.acquire())
        let second = try InstanceLease(directory: directory, name: "main.lock")
        XCTAssertFalse(try second.acquire())
        first = nil
        XCTAssertTrue(try second.acquire())
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("bad.lock"), withDestinationURL: directory.appendingPathComponent("main.lock"))
        XCTAssertThrowsError(try InstanceLease(directory: directory, name: "bad.lock"))
    }
    func testLampAndStripKeepOverlayNoninteractiveAndStatic() {
        guard let screen = NSScreen.main else { return XCTFail("Requires a logged-in Mac") }
        let window = PaperOverlayWindow(screen: screen)
        var lamp = DeskLamp(); lamp.enabled = true
        var strip = ReadingStrip(); strip.enabled = true
        window.apply(texture: PaperState.defaultTexture, adjustments: .none, lamp: lamp, strip: strip)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.canBecomeKey); XCTAssertFalse(window.canBecomeMain)
        XCTAssertNotNil(window.contentView?.layer?.mask)
        XCTAssertTrue(window.contentView?.layer?.animationKeys()?.isEmpty ?? true)
        window.close()
    }
    func testSystemAppearanceAdapterFollowsAppKitChanges() async {
        let app = NSApplication.shared
        let original = app.appearance
        defer { app.appearance = original }
        let name = "xyz.dustwave.paper.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let state = PaperState(defaults: defaults)
        let environment = SystemEnvironment(state: state)
        environment.start()
        defer { environment.stop() }
        app.appearance = NSAppearance(named: .darkAqua)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(state.darkAppearance)
        app.appearance = NSAppearance(named: .aqua)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(state.darkAppearance)
    }
}

import XCTest
@testable import PaperCore

final class WorkflowTests: XCTestCase {
    func testMigrationKeepsSolarAndAddsOnlyOptInFeatures() throws {
        let settings = try JSONDecoder().decode(PaperSettings.self, from: Data(#"{"intensity":0.34,"automaticLooks":{"enabled":true}}"#.utf8))
        XCTAssertEqual(settings.intensity, 0.34)
        XCTAssertEqual(settings.automaticLooks.trigger, .solar)
        XCTAssertNil(settings.lowBatteryThreshold)
        XCTAssertFalse(settings.deskLamp.enabled)
        XCTAssertFalse(settings.readingStrip.enabled)
        XCTAssertFalse(settings.appLooksEnabled)
        XCTAssertFalse(settings.presentationPaused)
        XCTAssertEqual(settings.shortcuts.toggle, ShortcutBinding())
        XCTAssertNil(settings.shortcuts.snooze)
        XCTAssertEqual(try JSONDecoder().decode(PaperSettings.self, from: JSONEncoder().encode(settings)), settings)
    }
    func testAppearanceSwitchingNeedsNoCityAndCreatesNoSolarTimer() {
        var automatic = AutomaticLooks()
        automatic.enabled = true; automatic.trigger = .systemAppearance
        automatic.dayLookID = UUID(); automatic.nightLookID = UUID()
        XCTAssertEqual(automatic.lookID(at: Date(), location: nil), automatic.dayLookID)
        XCTAssertEqual(automatic.lookID(at: Date(), location: nil, darkAppearance: true), automatic.nightLookID)
        XCTAssertNil(automatic.nextBoundary(after: Date(), location: nil))
        automatic.enabled = false
        XCTAssertNil(automatic.lookID(at: Date(), location: nil))
    }
    func testBatteryThresholdBoundariesAndRulePrecedence() {
        var settings = PaperSettings(); settings.lowBatteryThreshold = 20
        func reason(_ percent: Int?, battery: Bool = true) -> PauseReason? {
            OverlayPolicy.pauseReason(settings: settings, onBattery: battery, batteryPercentage: percent, now: Date())
        }
        XCTAssertNil(reason(nil)); XCTAssertNil(reason(-1)); XCTAssertNil(reason(101))
        XCTAssertNil(reason(21)); XCTAssertNil(reason(10, battery: false))
        XCTAssertEqual(reason(20), .lowBattery); XCTAssertEqual(reason(0), .lowBattery)
        settings.presentationPaused = true
        XCTAssertEqual(reason(10), .presentation)
        settings.enabled = false
        XCTAssertEqual(reason(10), .disabled)
    }
    func testDeskProfileCannotUndoGlobalPauseOrShortcutSettings() {
        var saved = PaperSettings(); saved.intensity = 0.4; saved.disabledDisplays = ["external"]
        let desk = DeskProfile(name: "Desk", displayIDs: ["internal", "external"], settings: saved)
        var current = PaperSettings(); current.enabled = false; current.presentationPaused = true
        current.disabledDisplays = ["internal"]
        current.snoozeUntil = Date().addingTimeInterval(100)
        current.shortcuts.toggle.key = "X"
        let result = desk.applying(to: current)
        XCTAssertEqual(result.intensity, 0.4); XCTAssertEqual(result.disabledDisplays, ["internal"])
        XCTAssertFalse(result.enabled); XCTAssertTrue(result.presentationPaused)
        XCTAssertEqual(result.snoozeUntil, current.snoozeUntil)
        XCTAssertEqual(result.shortcuts, current.shortcuts)
    }
    func testStripClampsEdgesAndMovesWithoutChangingHeight() {
        var strip = ReadingStrip(); strip.height = 0.2
        for _ in 0..<50 { strip.move(up: true) }
        XCTAssertEqual(strip.center, 0.9)
        for _ in 0..<50 { strip.move(up: false) }
        XCTAssertEqual(strip.center, 0.1)
        XCTAssertEqual(strip.height, 0.2)
        strip.center = .nan; strip.height = .infinity; strip.normalize()
        XCTAssertEqual(strip.center, 0.5); XCTAssertEqual(strip.height, 0.15)
    }
    func testShortcutsRequireNonTypingModifiersAndKnownKeys() {
        XCTAssertTrue(ShortcutBinding().isValid)
        XCTAssertFalse(ShortcutBinding(key: "P", command: false, option: true).isValid)
        XCTAssertFalse(ShortcutBinding(key: "F15").isValid)
        XCTAssertTrue(ShortcutBinding(key: "A", command: false, option: false, control: true).isValid)
    }
}

import XCTest
@testable import PaperCore

final class NextPrioritiesTests: XCTestCase {
    func testOnlyModeFailsClosedAndExclusionsAlwaysWin() {
        var settings = PaperSettings()
        settings.appRuleMode = .only
        let now = Date()
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, now: now), .applicationNotIncluded)
        settings.includedApps = [.init(bundleID: "reader", name: "Reader")]
        XCTAssertNil(OverlayPolicy.pauseReason(settings: settings, frontmostBundleID: "reader", now: now))
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, frontmostBundleID: "other", now: now), .applicationNotIncluded)
        settings.excludedApps = settings.includedApps
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, frontmostBundleID: "reader", now: now), .applicationExcluded)
        settings.enabled = false
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, frontmostBundleID: "reader", now: now), .disabled)
        settings.enabled = true; settings.disabledDisplays = ["external"]
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, displayID: "external", now: now), .displayExcluded)
    }
    func testDisplayOverridesClampAndOldSettingsMigrate() throws {
        var settings = try JSONDecoder().decode(PaperSettings.self, from: Data(#"{"enabled":false,"intensity":0.34,"excludedApps":[{"bundleID":"atoll","name":"Atoll"}]}"#.utf8))
        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(settings.appRuleMode, .except)
        XCTAssertFalse(settings.automaticLooks.enabled)
        XCTAssertEqual(settings.excludedApps.first?.bundleID, "atoll")
        settings.displayIntensities = ["external":0.1,"invalid":.infinity,"over":5]
        settings.normalize()
        XCTAssertEqual(settings.intensity(for: "external"),0.1)
        XCTAssertEqual(settings.intensity(for: "laptop"),0.34)
        XCTAssertEqual(settings.intensity(for: "invalid"),0.34)
        XCTAssertEqual(settings.intensity(for: "over"),0.45)
        settings.displayIntensities.removeValue(forKey: "external")
        XCTAssertEqual(settings.intensity(for: "external"),0.34)
    }
    func testAutomaticLooksShareSolarEventsWithoutEnablingVisibility() {
        let location = SolarLocation(name:"London",latitude:51.5,longitude:0,timeZoneIdentifier:"Europe/London")
        let noon = ISO8601DateFormatter().date(from:"2026-06-21T12:00:00Z")!
        var settings = PaperSettings()
        settings.automaticLooks.enabled = true
        settings.automaticLooks.dayLookID = UUID(); settings.automaticLooks.nightLookID = UUID()
        settings.schedule.location = location
        XCTAssertEqual(settings.automaticLooks.lookID(at:noon,location:location),settings.automaticLooks.dayLookID)
        XCTAssertEqual(settings.automaticLooks.lookID(at:noon.addingTimeInterval(12*3600),location:location),settings.automaticLooks.nightLookID)
        XCTAssertEqual(OverlayPolicy.nextEvent(settings:settings,after:noon),SolarDay.calculate(on:noon,at:location)?.sunset)
        settings.enabled = false
        XCTAssertEqual(OverlayPolicy.pauseReason(settings:settings,now:noon),.disabled)
        XCTAssertNil(settings.automaticLooks.lookID(at:noon,location:nil))
        settings.automaticLooks.dayLookID = nil
        XCTAssertNil(settings.automaticLooks.lookID(at:noon,location:location))
    }
}

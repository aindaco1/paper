import XCTest
@testable import PaperCore

final class OverlayPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }
    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: hour, minute: minute))!
    }
    func testOrdinaryScheduleIsStartInclusiveEndExclusive() {
        let schedule = PaperSchedule(enabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        XCTAssertFalse(schedule.contains(date(8, 59), calendar: calendar))
        XCTAssertTrue(schedule.contains(date(9), calendar: calendar))
        XCTAssertTrue(schedule.contains(date(16, 59), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(17), calendar: calendar))
        XCTAssertEqual(schedule.nextBoundary(after: date(9), calendar: calendar), date(17))
    }
    func testOvernightAndAllDaySchedules() {
        let schedule = PaperSchedule(enabled: true)
        XCTAssertTrue(schedule.contains(date(23), calendar: calendar))
        XCTAssertTrue(schedule.contains(date(6), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(7), calendar: calendar))
        XCTAssertFalse(schedule.contains(date(12), calendar: calendar))
        let allDay = PaperSchedule(enabled: true, startMinute: 30, endMinute: 30)
        XCTAssertTrue(allDay.contains(date(12), calendar: calendar))
        XCTAssertNil(allDay.nextBoundary(after: date(12), calendar: calendar))
    }
    func testSpringGapAdvancesToNextValidTime() {
        let schedule = PaperSchedule(enabled: true, startMinute: 150, endMinute: 240)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 59))!
        let next = schedule.nextBoundary(after: now, calendar: calendar)!
        XCTAssertEqual(calendar.component(.hour, from: next), 3)
        XCTAssertTrue(schedule.contains(next, calendar: calendar))
    }
    func testRepeatedHourDoesNotReenterAnEndedWindow() {
        let schedule = PaperSchedule(enabled: true, startMinute: 60, endMinute: 90)
        let first = ISO8601DateFormatter().date(from: "2026-11-01T06:15:00Z")!
        let second = first.addingTimeInterval(3600)
        XCTAssertTrue(schedule.contains(first, calendar: calendar))
        XCTAssertFalse(schedule.contains(second, calendar: calendar))
        XCTAssertGreaterThan(schedule.nextBoundary(after: second, calendar: calendar)!, second.addingTimeInterval(20 * 3600))
    }
    func testManualOffAndDisplayExclusionAlwaysWin() {
        var settings = PaperSettings()
        settings.enabled = false
        settings.snoozeUntil = date(14)
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, comparing: true, now: date(12)), .disabled)
        settings.enabled = true
        settings.disabledDisplays = ["external"]
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, displayID: "external", now: date(12)), .displayExcluded)
    }
    func testAppBatteryLowPowerAndScheduleAreIndependentGates() {
        var settings = PaperSettings()
        settings.excludedApps = [.init(bundleID: "photo.app", name: "Photos")]
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, frontmostBundleID: "photo.app", now: date(12)), .applicationExcluded)
        XCTAssertNil(OverlayPolicy.pauseReason(settings: settings, frontmostBundleID: "editor.app", now: date(12)))
        settings.pauseOnBattery = true
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, onBattery: true, now: date(12)), .battery)
        settings.pauseOnLowPower = true
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, lowPower: true, now: date(12)), .lowPower)
        settings.schedule.enabled = true
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, now: date(12), calendar: calendar), .outsideSchedule)
    }
    func testSnoozeExpiryNeverBypassesOtherRules() {
        var settings = PaperSettings()
        settings.snoozeUntil = date(12, 15)
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, now: date(12)), .snoozed)
        XCTAssertNil(OverlayPolicy.pauseReason(settings: settings, now: date(12, 15)))
        settings.pauseOnBattery = true
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, onBattery: true, now: date(12, 15)), .battery)
        XCTAssertNil(OverlayPolicy.nextEvent(settings: settings, after: date(12, 15), calendar: calendar))
    }
    func testEarliestBoundaryAndNormalization() {
        var settings = PaperSettings()
        settings.schedule.enabled = true
        settings.snoozeUntil = date(19)
        XCTAssertEqual(OverlayPolicy.nextEvent(settings: settings, after: date(12), calendar: calendar), date(18))
        settings.intensity = .infinity
        settings.grainStrength = -20
        settings.schedule.startMinute = 9000
        settings.normalize()
        XCTAssertEqual(settings.intensity, 0.22)
        XCTAssertEqual(settings.grainStrength, 0.25)
        XCTAssertEqual(settings.schedule.startMinute, 1439)
    }
}


import XCTest
@testable import PaperCore

final class SolarScheduleTests: XCTestCase {
    private let newYork = SolarLocation(name: "New York", latitude: 40.7128, longitude: -74.006,
                                        timeZoneIdentifier: "America/New_York")
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testApproximateNewYorkSolsticeAndExclusiveSunsetBoundary() throws {
        let day = try XCTUnwrap(SolarDay.calculate(on: date("2026-06-21T16:00:00Z"), at: newYork))
        // Independent civil sunrise/sunset reference, deliberately allowing the
        // few-minute accuracy of NOAA's compact fractional-year approximation.
        XCTAssertEqual(try XCTUnwrap(day.sunrise).timeIntervalSince(date("2026-06-21T09:25:00Z")), 0, accuracy: 600)
        XCTAssertEqual(try XCTUnwrap(day.sunset).timeIntervalSince(date("2026-06-22T00:31:00Z")), 0, accuracy: 600)
        XCTAssertTrue(day.isDaylight(at: day.sunrise!))
        XCTAssertFalse(day.isDaylight(at: day.sunset!))
    }
    func testSolarModesAndManualPausePrecedence() throws {
        var settings = PaperSettings()
        settings.schedule.enabled = true
        settings.schedule.mode = .sunsetToSunrise
        settings.schedule.location = newYork
        let noon = date("2026-06-21T16:00:00Z"), night = date("2026-06-21T04:00:00Z")
        XCTAssertFalse(settings.schedule.contains(noon))
        XCTAssertTrue(settings.schedule.contains(night))
        settings.schedule.mode = .sunriseToSunset
        XCTAssertTrue(settings.schedule.contains(noon))
        XCTAssertFalse(settings.schedule.contains(night))
        settings.enabled = false
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, now: noon), .disabled)
        settings.enabled = true
        settings.disabledDisplays = ["monitor"]
        XCTAssertEqual(OverlayPolicy.pauseReason(settings: settings, displayID: "monitor", now: noon), .displayExcluded)
    }
    func testCityUsesItsOwnDateAcrossInternationalDateLine() throws {
        let city = SolarLocation(name: "Auckland", latitude: -36.85, longitude: 174.76, timeZoneIdentifier: "Pacific/Auckland")
        let noon = date("2026-01-15T23:00:00Z") // Jan 16 midday in Auckland
        let day = try XCTUnwrap(SolarDay.calculate(on: noon, at: city))
        XCTAssertEqual(city.calendar.component(.day, from: try XCTUnwrap(day.sunrise)), 16)
        XCTAssertEqual(city.calendar.component(.day, from: try XCTUnwrap(day.sunset)), 16)
        XCTAssertTrue(day.isDaylight(at: noon))
        XCTAssertEqual(Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: day.sunrise!).day, 15)
    }
    func testPolarDayNightAndDailyReevaluation() throws {
        var schedule = PaperSchedule(enabled: true)
        schedule.mode = .sunsetToSunrise
        schedule.location = SolarLocation(name: "Tromsø", latitude: 69.65, longitude: 18.96, timeZoneIdentifier: "Europe/Oslo")
        let summer = date("2026-06-21T10:00:00Z"), winter = date("2026-12-21T10:00:00Z")
        XCTAssertFalse(schedule.contains(summer))
        XCTAssertTrue(schedule.contains(winter))
        XCTAssertEqual(try XCTUnwrap(schedule.nextBoundary(after: summer)), date("2026-06-21T22:00:00Z"))
    }
    func testDSTDoesNotShiftSolarEventsByAnHour() throws {
        let before = try XCTUnwrap(SolarDay.calculate(on: date("2026-03-07T17:00:00Z"), at: newYork)?.sunrise)
        let after = try XCTUnwrap(SolarDay.calculate(on: date("2026-03-08T16:00:00Z"), at: newYork)?.sunrise)
        XCTAssertEqual(after.timeIntervalSince(before), 86400, accuracy: 180)
        var schedule = PaperSchedule(enabled: true)
        schedule.mode = .sunriseToSunset; schedule.location = newYork
        XCTAssertEqual(schedule.nextBoundary(after: after.addingTimeInterval(-1)), after)
        XCTAssertNotEqual(schedule.nextBoundary(after: after), after)
    }
    func testMissingAndInvalidCityFailClosedWithoutARepetitionTimer() {
        var schedule = PaperSchedule(enabled: true)
        schedule.mode = .sunsetToSunrise
        XCTAssertFalse(schedule.contains(Date()))
        XCTAssertNil(schedule.nextBoundary(after: Date()))
        schedule.location = .init(name: "Invalid", latitude: .nan, longitude: 0, timeZoneIdentifier: "UTC")
        XCTAssertFalse(schedule.contains(Date()))
        XCTAssertNil(schedule.nextBoundary(after: Date()))
        schedule.enabled = false
        XCTAssertTrue(schedule.contains(Date()))
    }
    func testExistingFixedScheduleDecodesWithoutNewKeys() throws {
        let data = Data(#"{"enabled":true,"startMinute":1200,"endMinute":360}"#.utf8)
        let schedule = try JSONDecoder().decode(PaperSchedule.self, from: data)
        XCTAssertEqual(schedule.mode, .fixed)
        XCTAssertNil(schedule.location)
        XCTAssertEqual(schedule.startMinute, 1200)
        XCTAssertTrue(schedule.enabled)
    }
}

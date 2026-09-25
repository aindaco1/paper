import XCTest
@testable import PaperCore

final class SnoozeOptionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }
    private func date(_ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
    func testCustomDurationLimitsAndInvalidNumbers() {
        let now = date(9, 24, 12)
        for minutes in [Double.nan, .infinity, -.infinity, -1, 0, 0.5, 1441] {
            XCTAssertNil(SnoozeOption.deadline(minutes: minutes, after: now))
        }
        XCTAssertEqual(SnoozeOption.deadline(minutes: 1, after: now), now.addingTimeInterval(60))
        XCTAssertEqual(SnoozeOption.deadline(minutes: 1440, after: now), now.addingTimeInterval(86400))
        XCTAssertEqual(SnoozeOption.twoHours.deadline(after: now), now.addingTimeInterval(7200))
    }
    func testTomorrowAlwaysMeansNextCalendarDayEvenBeforeSixAM() {
        for hour in [1, 6, 23] {
            XCTAssertEqual(SnoozeOption.tomorrow.deadline(after: date(9, 24, hour), calendar: calendar), date(9, 25, 6))
        }
    }
    func testTomorrowKeepsSixAMAcrossBothDSTTransitions() {
        let spring = date(3, 7, 6)
        let autumn = date(10, 31, 6)
        XCTAssertEqual(SnoozeOption.tomorrow.deadline(after: spring, calendar: calendar), date(3, 8, 6))
        XCTAssertEqual(SnoozeOption.tomorrow.deadline(after: spring, calendar: calendar)?.timeIntervalSince(spring), 23 * 3600)
        XCTAssertEqual(SnoozeOption.tomorrow.deadline(after: autumn, calendar: calendar), date(11, 1, 6))
        XCTAssertEqual(SnoozeOption.tomorrow.deadline(after: autumn, calendar: calendar)?.timeIntervalSince(autumn), 25 * 3600)
    }
}

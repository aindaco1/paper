import Foundation

public struct AutomaticLooks: Codable, Equatable {
    public var enabled = false
    public var dayLookID: UUID?
    public var nightLookID: UUID?
    public init() {}

    public func lookID(at date: Date, location: SolarLocation?) -> UUID? {
        guard enabled, let dayLookID, let nightLookID, let location,
              let day = SolarDay.calculate(on: date, at: location) else { return nil }
        return day.isDaylight(at: date) ? dayLookID : nightLookID
    }
    public func nextBoundary(after date: Date, location: SolarLocation?) -> Date? {
        guard enabled else { return nil }
        var schedule = PaperSchedule(enabled: true)
        schedule.mode = .sunriseToSunset
        schedule.location = location
        return schedule.nextBoundary(after: date)
    }
}

public enum AppRuleMode: String, Codable, CaseIterable { case except, only }

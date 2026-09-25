import Foundation

public struct AutomaticLooks: Codable, Equatable {
    public enum Trigger: String, Codable, CaseIterable { case solar, systemAppearance }
    public var enabled = false
    public var trigger: Trigger = .solar
    public var dayLookID: UUID?
    public var nightLookID: UUID?
    public init() {}

    private enum CodingKeys: String, CodingKey { case enabled, trigger, dayLookID, nightLookID }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        trigger = try values.decodeIfPresent(Trigger.self, forKey: .trigger) ?? .solar
        dayLookID = try values.decodeIfPresent(UUID.self, forKey: .dayLookID)
        nightLookID = try values.decodeIfPresent(UUID.self, forKey: .nightLookID)
    }
    public func lookID(at date: Date, location: SolarLocation?, darkAppearance: Bool = false) -> UUID? {
        guard enabled, let dayLookID, let nightLookID else { return nil }
        if trigger == .systemAppearance { return darkAppearance ? nightLookID : dayLookID }
        guard let location,
              let day = SolarDay.calculate(on: date, at: location) else { return nil }
        return day.isDaylight(at: date) ? dayLookID : nightLookID
    }
    public func nextBoundary(after date: Date, location: SolarLocation?) -> Date? {
        guard enabled, trigger == .solar else { return nil }
        var schedule = PaperSchedule(enabled: true)
        schedule.mode = .sunriseToSunset
        schedule.location = location
        return schedule.nextBoundary(after: date)
    }
}

public enum AppRuleMode: String, Codable, CaseIterable { case except, only }

import Foundation

public enum ScheduleMode: String, Codable, CaseIterable, Identifiable {
    case fixed, sunsetToSunrise, sunriseToSunset
    public var id: Self { self }
}

public struct SolarLocation: Codable, Equatable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timeZoneIdentifier: String

    public init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.name = name; self.latitude = latitude; self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude)
            && (-180...180).contains(longitude) && TimeZone(identifier: timeZoneIdentifier) != nil
    }
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        return calendar
    }
}

public struct SolarDay {
    public let sunrise: Date?
    public let sunset: Date?
    public let continuousDaylight: Bool

    /// NOAA's fractional-year solar equations, with apparent zenith 90.833 degrees.
    /// Approximate civil sunrise/sunset; no network access or location tracking.
    /// https://gml.noaa.gov/grad/solcalc/solareqns.PDF
    public static func calculate(on date: Date, at location: SolarLocation) -> SolarDay? {
        guard location.isValid else { return nil }
        let calendar = location.calendar
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date)!)
        let yearLength = Double(calendar.range(of: .day, in: .year, for: date)!.count)
        let gamma = 2 * Double.pi / yearLength * (day - 1)
        let equation = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let latitude = location.latitude * .pi / 180
        let zenithCos = cos(90.833 * .pi / 180)
        let denominator = cos(latitude) * cos(declination)
        let numerator = zenithCos - sin(latitude) * sin(declination)
        // This also handles the exact poles without division by zero.
        if numerator < -denominator { return .init(sunrise: nil, sunset: nil, continuousDaylight: true) }
        if numerator > denominator { return .init(sunrise: nil, sunset: nil, continuousDaylight: false) }
        let angle = acos(min(1, max(-1, numerator / denominator))) * 180 / .pi
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let midnight = utc.date(from: components) else { return nil }
        let noon = 720 - 4 * location.longitude - equation
        // Deliberately keep negative/next-day UTC minutes (e.g. New Zealand).
        return .init(sunrise: midnight.addingTimeInterval((noon - 4 * angle) * 60),
                     sunset: midnight.addingTimeInterval((noon + 4 * angle) * 60), continuousDaylight: false)
    }

    public func isDaylight(at date: Date) -> Bool {
        guard let sunrise, let sunset else { return continuousDaylight }
        return date >= sunrise && date < sunset
    }
}

import Foundation

public struct AppExclusion: Codable, Equatable, Identifiable {
    public var bundleID: String
    public var name: String
    public var id: String { bundleID }
    public init(bundleID: String, name: String) { self.bundleID = bundleID; self.name = name }
}

public struct PaperSchedule: Codable, Equatable {
    public var enabled = false
    public var startMinute = 18 * 60
    public var endMinute = 7 * 60

    public init(enabled: Bool = false, startMinute: Int = 18 * 60, endMinute: Int = 7 * 60) {
        self.enabled = enabled
        self.startMinute = min(1439, max(0, startMinute))
        self.endMinute = min(1439, max(0, endMinute))
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, startMinute != endMinute else { return true }
        let start = boundary(startMinute, on: date, calendar: calendar)
        let end = boundary(endMinute, on: date, calendar: calendar)
        if startMinute < endMinute { return date >= start && date < end }
        return date >= start || date < end
    }

    public func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date? {
        guard enabled, startMinute != endMinute else { return nil }
        // Resolve each day's first occurrence before filtering, so Calendar
        // cannot return the second occurrence of an already-ended DST boundary.
        return (0...2).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: date)) }
            .flatMap { day in [startMinute, endMinute].map { boundary($0, on: day, calendar: calendar) } }
            .filter { $0 > date }.min()
    }

    private func boundary(_ minute: Int, on date: Date, calendar: Calendar) -> Date {
        calendar.nextDate(after: calendar.startOfDay(for: date).addingTimeInterval(-1),
            matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
            matchingPolicy: .nextTime, repeatedTimePolicy: .first)!
    }
}

public struct PaperSettings: Codable, Equatable {
    public var enabled = true
    public var textureID = "quiet-gray"
    public var intensity = 0.22
    public var grainScale = 1.0
    public var grainStrength = 1.0
    public var pauseOnBattery = false
    public var pauseOnLowPower = false
    public var shortcutEnabled = true
    public var disabledDisplays: Set<String> = []
    public var excludedApps: [AppExclusion] = []
    public var schedule = PaperSchedule()
    public var snoozeUntil: Date?

    public init() {}

    public mutating func normalize() {
        intensity = intensity.isFinite ? min(0.45, max(0.05, intensity)) : 0.22
        grainScale = [0.5, 1, 2].contains(grainScale) ? grainScale : 1
        grainStrength = grainStrength.isFinite ? min(2, max(0.25, grainStrength)) : 1
        schedule.startMinute = min(1439, max(0, schedule.startMinute))
        schedule.endMinute = min(1439, max(0, schedule.endMinute))
    }
}

public enum PauseReason: Equatable {
    case disabled, displayExcluded, comparing, snoozed, applicationExcluded, battery, lowPower, outsideSchedule
}

public enum OverlayPolicy {
    public static func pauseReason(settings: PaperSettings, displayID: String? = nil,
                                   frontmostBundleID: String? = nil, onBattery: Bool = false,
                                   lowPower: Bool = false, comparing: Bool = false,
                                   now: Date, calendar: Calendar = .current) -> PauseReason? {
        if !settings.enabled { return .disabled }
        if let displayID, settings.disabledDisplays.contains(displayID) { return .displayExcluded }
        if comparing { return .comparing }
        if let until = settings.snoozeUntil, until > now { return .snoozed }
        if let id = frontmostBundleID, settings.excludedApps.contains(where: { $0.bundleID == id }) {
            return .applicationExcluded
        }
        if settings.pauseOnBattery && onBattery { return .battery }
        if settings.pauseOnLowPower && lowPower { return .lowPower }
        if !settings.schedule.contains(now, calendar: calendar) { return .outsideSchedule }
        return nil
    }

    public static func nextEvent(settings: PaperSettings, after now: Date,
                                 calendar: Calendar = .current) -> Date? {
        [settings.snoozeUntil, settings.schedule.nextBoundary(after: now, calendar: calendar)]
            .compactMap { $0 }.filter { $0 > now }.min()
    }
}

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
    public var mode: ScheduleMode = .fixed
    public var location: SolarLocation?

    public init(enabled: Bool = false, startMinute: Int = 18 * 60, endMinute: Int = 7 * 60) {
        self.enabled = enabled
        self.startMinute = min(1439, max(0, startMinute))
        self.endMinute = min(1439, max(0, endMinute))
    }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return true }
        if mode != .fixed {
            guard let location, let day = SolarDay.calculate(on: date, at: location) else { return false }
            let daylight = day.isDaylight(at: date)
            return mode == .sunriseToSunset ? daylight : !daylight
        }
        guard enabled, startMinute != endMinute else { return true }
        let start = boundary(startMinute, on: date, calendar: calendar)
        let end = boundary(endMinute, on: date, calendar: calendar)
        if startMinute < endMinute { return date >= start && date < end }
        return date >= start || date < end
    }

    public func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date? {
        guard enabled else { return nil }
        if mode != .fixed {
            guard let location, location.isValid else { return nil }
            let local = location.calendar
            let midnight = local.startOfDay(for: date)
            // Re-evaluate daily even during polar day/night, when no event exists.
            let days = (0...2).compactMap { local.date(byAdding: .day, value: $0, to: midnight) }
            return (days + days.flatMap { day -> [Date] in
                guard let solar = SolarDay.calculate(on: day, at: location) else { return [] }
                return [solar.sunrise, solar.sunset].compactMap { $0 }
            }).filter { $0 > date }.min()
        }
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

    private enum CodingKeys: String, CodingKey { case enabled, startMinute, endMinute, mode, location }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        startMinute = try values.decode(Int.self, forKey: .startMinute)
        endMinute = try values.decode(Int.self, forKey: .endMinute)
        mode = try values.decodeIfPresent(ScheduleMode.self, forKey: .mode) ?? .fixed
        location = try values.decodeIfPresent(SolarLocation.self, forKey: .location)
    }
}

public struct PaperSettings: Codable, Equatable {
    public static let defaultTextureID = "classic-matte"
    public var enabled = true
    public var textureID = Self.defaultTextureID
    public var intensity = 0.22
    public var grainScale = 1.0
    public var grainStrength = 1.0
    public var pauseOnBattery = false
    public var pauseOnLowPower = false
    public var shortcutEnabled = true
    public var shortcuts = ShortcutSettings()
    public var lowBatteryThreshold: Int?
    public var textureIntensities: [String: Double] = [:]
    public var deskLamp = DeskLamp()
    public var readingStrip = ReadingStrip()
    public var presentationPaused = false
    public var appLooksEnabled = false
    public var appLooks: [String: UUID] = [:]
    public var disabledDisplays: Set<String> = []
    public var excludedApps: [AppExclusion] = []
    public var appRuleMode: AppRuleMode = .except
    public var includedApps: [AppExclusion] = []
    public var displayIntensities: [String: Double] = [:]
    public var automaticLooks = AutomaticLooks()
    public var schedule = PaperSchedule()
    public var snoozeUntil: Date?

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, textureID, intensity, grainScale, grainStrength, pauseOnBattery, pauseOnLowPower,
             shortcutEnabled, disabledDisplays, excludedApps, schedule, snoozeUntil,
             appRuleMode, includedApps, displayIntensities, automaticLooks,
             shortcuts, lowBatteryThreshold, textureIntensities, deskLamp,
             readingStrip, presentationPaused, appLooksEnabled, appLooks
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let v = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try v.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        textureID = try v.decodeIfPresent(String.self, forKey: .textureID) ?? textureID
        intensity = try v.decodeIfPresent(Double.self, forKey: .intensity) ?? intensity
        grainScale = try v.decodeIfPresent(Double.self, forKey: .grainScale) ?? grainScale
        grainStrength = try v.decodeIfPresent(Double.self, forKey: .grainStrength) ?? grainStrength
        pauseOnBattery = try v.decodeIfPresent(Bool.self, forKey: .pauseOnBattery) ?? pauseOnBattery
        pauseOnLowPower = try v.decodeIfPresent(Bool.self, forKey: .pauseOnLowPower) ?? pauseOnLowPower
        shortcutEnabled = try v.decodeIfPresent(Bool.self, forKey: .shortcutEnabled) ?? shortcutEnabled
        shortcuts = try v.decodeIfPresent(ShortcutSettings.self, forKey: .shortcuts) ?? .init()
        lowBatteryThreshold = try v.decodeIfPresent(Int.self, forKey: .lowBatteryThreshold)
        textureIntensities = try v.decodeIfPresent([String: Double].self, forKey: .textureIntensities) ?? [:]
        deskLamp = try v.decodeIfPresent(DeskLamp.self, forKey: .deskLamp) ?? .init()
        readingStrip = try v.decodeIfPresent(ReadingStrip.self, forKey: .readingStrip) ?? .init()
        presentationPaused = try v.decodeIfPresent(Bool.self, forKey: .presentationPaused) ?? false
        appLooksEnabled = try v.decodeIfPresent(Bool.self, forKey: .appLooksEnabled) ?? false
        appLooks = try v.decodeIfPresent([String: UUID].self, forKey: .appLooks) ?? [:]
        disabledDisplays = try v.decodeIfPresent(Set<String>.self, forKey: .disabledDisplays) ?? []
        excludedApps = try v.decodeIfPresent([AppExclusion].self, forKey: .excludedApps) ?? []
        includedApps = try v.decodeIfPresent([AppExclusion].self, forKey: .includedApps) ?? []
        appRuleMode = try v.decodeIfPresent(AppRuleMode.self, forKey: .appRuleMode) ?? .except
        displayIntensities = try v.decodeIfPresent([String: Double].self, forKey: .displayIntensities) ?? [:]
        automaticLooks = try v.decodeIfPresent(AutomaticLooks.self, forKey: .automaticLooks) ?? .init()
        schedule = try v.decodeIfPresent(PaperSchedule.self, forKey: .schedule) ?? schedule
        snoozeUntil = try v.decodeIfPresent(Date.self, forKey: .snoozeUntil)
        normalize()
    }
    public func intensity(for displayID: String) -> Double {
        let value = displayIntensities[displayID] ?? intensity
        return value.isFinite ? min(0.45, max(0.05, value)) : intensity
    }

    public mutating func normalize() {
        intensity = intensity.isFinite ? min(0.45, max(0.05, intensity)) : 0.22
        grainScale = [0.5, 1, 2].contains(grainScale) ? grainScale : 1
        grainStrength = grainStrength.isFinite ? min(2, max(0.25, grainStrength)) : 1
        displayIntensities = displayIntensities.filter { $0.value.isFinite }.mapValues { min(0.45, max(0.05, $0)) }
        textureIntensities = textureIntensities.filter { $0.value.isFinite }.mapValues { min(0.45, max(0.05, $0)) }
        lowBatteryThreshold = lowBatteryThreshold.map { min(100, max(1, $0)) }
        deskLamp.normalize()
        readingStrip.normalize()
        schedule.startMinute = min(1439, max(0, schedule.startMinute))
        schedule.endMinute = min(1439, max(0, schedule.endMinute))
    }
}

public enum PauseReason: Equatable {
    case disabled, displayExcluded, comparing, snoozed, presentation, applicationExcluded, applicationNotIncluded, battery, lowBattery, lowPower, outsideSchedule
}

public enum OverlayPolicy {
    /// Stay above ordinary windows, but beneath an excluded app's floating UI.
    /// Frontmost exclusions still pause the entire overlay through pauseReason.
    public static func windowLevel(defaultLevel: Int, normalLevel: Int,
                                   excludedPanelLevels: [Int]) -> Int {
        excludedPanelLevels.filter { $0 > normalLevel + 1 && $0 <= defaultLevel }
            .map { $0 - 1 }.min() ?? defaultLevel
    }

    public static func pauseReason(settings: PaperSettings, displayID: String? = nil,
                                   frontmostBundleID: String? = nil, onBattery: Bool = false,
                                   lowPower: Bool = false, batteryPercentage: Int? = nil, comparing: Bool = false,
                                   now: Date, calendar: Calendar = .current) -> PauseReason? {
        if !settings.enabled { return .disabled }
        if let displayID, settings.disabledDisplays.contains(displayID) { return .displayExcluded }
        if settings.presentationPaused { return .presentation }
        if comparing { return .comparing }
        if let until = settings.snoozeUntil, until > now { return .snoozed }
        if let id = frontmostBundleID, settings.excludedApps.contains(where: { $0.bundleID == id }) {
            return .applicationExcluded
        }
        if settings.appRuleMode == .only,
           !settings.includedApps.contains(where: { $0.bundleID == frontmostBundleID }) {
            return .applicationNotIncluded
        }
        if settings.pauseOnBattery && onBattery { return .battery }
        if onBattery, let threshold = settings.lowBatteryThreshold, let batteryPercentage,
           (0...100).contains(batteryPercentage), batteryPercentage <= threshold { return .lowBattery }
        if settings.pauseOnLowPower && lowPower { return .lowPower }
        if !settings.schedule.contains(now, calendar: calendar) { return .outsideSchedule }
        return nil
    }

    public static func nextEvent(settings: PaperSettings, after now: Date,
                                 calendar: Calendar = .current) -> Date? {
        [settings.snoozeUntil, settings.schedule.nextBoundary(after: now, calendar: calendar),
         settings.automaticLooks.nextBoundary(after: now, location: settings.schedule.location)]
            .compactMap { $0 }.filter { $0 > now }.min()
    }
}

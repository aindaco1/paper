import Foundation

/// Shared by the settings controls and menu bar; no separate scheduling path.
public enum SnoozeOption: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15, thirtyMinutes = 30, oneHour = 60, twoHours = 120
    case tomorrow = -1

    public var id: Int { rawValue }

    public func deadline(after date: Date, calendar: Calendar = .current) -> Date? {
        if self != .tomorrow { return Self.deadline(minutes: Double(rawValue), after: date) }
        guard let day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else { return nil }
        return calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day,
                             matchingPolicy: .nextTime, repeatedTimePolicy: .first)
    }

    public static func deadline(minutes: Double, after date: Date) -> Date? {
        guard minutes.isFinite, minutes >= 1, minutes <= 24 * 60 else { return nil }
        return date.addingTimeInterval(minutes * 60)
    }
}

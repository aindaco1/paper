import Foundation

public enum ShortcutAction: String, Codable, CaseIterable, Identifiable {
    case toggle, snooze, nextFavorite, readingUp, readingDown, presentation
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .toggle: return "Toggle Paper"
        case .snooze: return "Snooze for 15 minutes"
        case .nextFavorite: return "Next favorite"
        case .readingUp: return "Move reading strip up"
        case .readingDown: return "Move reading strip down"
        case .presentation: return "Toggle presentation pause"
        }
    }
}

/// Physical ANSI letter keys. The native adapter owns Carbon constants and registration.
public struct ShortcutBinding: Codable, Equatable, Hashable {
    public var key: String
    public var command: Bool
    public var option: Bool
    public var control: Bool
    public var shift: Bool
    public init(key: String = "P", command: Bool = true, option: Bool = true,
                control: Bool = false, shift: Bool = true) {
        self.key = key; self.command = command; self.option = option
        self.control = control; self.shift = shift
    }
    public var isValid: Bool { Self.keys.contains(key) && (command || control) }
    public static let keys = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
    public var title: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + key
    }
}

public struct ShortcutSettings: Codable, Equatable {
    public var toggle = ShortcutBinding()
    public var snooze: ShortcutBinding?
    public var nextFavorite: ShortcutBinding?
    public var readingUp: ShortcutBinding?
    public var readingDown: ShortcutBinding?
    public var presentation: ShortcutBinding?
    public init() {}
    public subscript(action: ShortcutAction) -> ShortcutBinding? {
        get {
            switch action {
            case .toggle: return toggle; case .snooze: return snooze; case .nextFavorite: return nextFavorite
            case .readingUp: return readingUp; case .readingDown: return readingDown; case .presentation: return presentation
            }
        }
        set {
            switch action {
            case .toggle: toggle = newValue ?? ShortcutBinding()
            case .snooze: snooze = newValue
            case .nextFavorite: nextFavorite = newValue
            case .readingUp: readingUp = newValue
            case .readingDown: readingDown = newValue
            case .presentation: presentation = newValue
            }
        }
    }
}

public struct ReadingStrip: Codable, Equatable {
    public var enabled = false
    /// Center and height as fractions of each display, independent of scale.
    public var center = 0.5
    public var height = 0.15
    public init() {}
    public mutating func normalize() {
        height = height.isFinite ? min(0.5, max(0.05, height)) : 0.15
        center = center.isFinite ? min(1 - height / 2, max(height / 2, center)) : 0.5
    }
    public mutating func move(up: Bool) {
        center += up ? 0.05 : -0.05
        normalize()
    }
}

/// A local setup for an exact set of connected display identifiers. Global control
/// and shortcut ownership always remain with the current settings.
public struct DeskProfile: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var name: String
    public var displayIDs: Set<String>
    public var settings: PaperSettings
    public init(name: String, displayIDs: Set<String>, settings: PaperSettings) {
        self.name = name; self.displayIDs = displayIDs; self.settings = settings
    }
    public func applying(to current: PaperSettings) -> PaperSettings {
        var result = settings
        result.enabled = current.enabled
        result.disabledDisplays = current.disabledDisplays
        result.snoozeUntil = current.snoozeUntil
        result.presentationPaused = current.presentationPaused
        result.shortcuts = current.shortcuts
        result.shortcutEnabled = current.shortcutEnabled
        result.textureIntensities = current.textureIntensities
        result.normalize()
        return result
    }
}

public struct DeskLamp: Codable, Equatable {
    public var enabled = false
    public var warmth = 0.5
    public var strength = 0.3
    public init() {}
    public mutating func normalize() {
        warmth = warmth.isFinite ? min(1, max(0, warmth)) : 0.5
        strength = strength.isFinite ? min(1, max(0, strength)) : 0.3
    }
}

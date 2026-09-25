import AppKit
import Combine
import PaperCore

struct PaperAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

enum PaperImportError: LocalizedError {
    case tooLarge, tooMany, invalidName, invalidRecipe
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Choose a JSON recipe smaller than 1 MB."
        case .tooMany: return "You can keep up to 50 imported papers. Remove one before importing another."
        case .invalidName: return "This recipe needs a readable paper name."
        case .invalidRecipe: return "Choose a Deckle paper recipe exported as JSON. This file is incomplete, invalid, or uses an unsupported recipe version."
        }
    }
}

enum RecipeImport {
    static func decode(_ data: Data) throws -> CustomPaper {
        guard data.count <= 1_048_576 else { throw PaperImportError.tooLarge }
        var paper: CustomPaper
        do { paper = try JSONDecoder().decode(CustomPaper.self, from: data) }
        catch is DecodingError { throw PaperImportError.invalidRecipe }
        paper.name = String(paper.name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !paper.name.isEmpty else { throw PaperImportError.invalidName }
        paper.name = String(paper.name.prefix(80))
        // Decoding derives any legacy seed before assigning a fresh identity.
        paper.id = "custom-\(UUID().uuidString.lowercased())"
        return paper
    }
}

/// A single typed settings store. Corrupt bytes are retained before defaults are used.
struct PaperPersistence {
    let defaults: UserDefaults
    func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        guard let bytes = defaults.data(forKey: key) else { return nil }
        do { return try JSONDecoder().decode(type, from: bytes) }
        catch {
            defaults.set(bytes, forKey: "\(key).corrupt.\(UUID().uuidString)")
            throw error
        }
    }
    func save<T: Encodable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class PaperState: ObservableObject {
    static let defaultTexture = TexturePreset.preset(id: PaperSettings.defaultTextureID)
    // Use the full pinned catalog, with the default first; no separate ID list to maintain.
    static let builtIns = [defaultTexture] + TexturePreset.all.filter { $0.id != defaultTexture.id }
    @Published var settings: PaperSettings { didSet { persist(settings, key: "settings.v1") } }
    @Published private(set) var customPapers: [CustomPaper]
    @Published var comparing = false
    @Published var showingCustomSnooze = false
    @Published var alert: PaperAlert?
    @Published var now = Date()
    @Published var onBattery = false
    @Published var lowPower = false
    @Published var frontmostBundleID: String?
    @Published var displayChoices: [DisplayChoice] = []
    @Published var shortcutError: String?
    @Published var loginState: LaunchAtLoginState = .disabled
    private let persistence: PaperPersistence
    let login = LaunchAtLoginController()
    private var boundaryTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        persistence = PaperPersistence(defaults: defaults)
        var errors: [String] = []
        do { settings = try persistence.load(PaperSettings.self, key: "settings.v1") ?? PaperSettings() }
        catch { settings = PaperSettings(); errors.append("Settings could not be read.") }
        do { customPapers = try persistence.load([CustomPaper].self, key: "papers.v1") ?? [] }
        catch { customPapers = []; errors.append("Imported paper recipes could not be read.") }
        settings.normalize()
        if !allTextures.contains(where: { $0.id == settings.textureID }) { settings.textureID = Self.defaultTexture.id }
        if !errors.isEmpty {
            alert = PaperAlert(title: "Recovered default settings",
                              message: errors.joined(separator: " ") + " A copy of the unreadable data was kept locally.")
        }
        refreshLogin()
    }

    var allTextures: [TexturePreset] { Self.builtIns + customPapers.map(TexturePreset.init(custom:)) }
    var texture: TexturePreset { allTextures.first { $0.id == settings.textureID } ?? Self.defaultTexture }
    var adjustments: TextureRenderer.GrainAdjustments {
        .init(scale: settings.grainScale, strength: settings.grainStrength)
    }
    var intensityDescription: String { settings.intensity.formatted(.percent.precision(.fractionLength(0))) }
    var pauseReason: PauseReason? { reason(for: nil) }
    var status: String {
        switch pauseReason {
        case .disabled: return "Paper is off"
        case .displayExcluded: return "Display is excluded"
        case .comparing: return "Comparing with your original screen"
        case .snoozed: return "Snoozed until \(settings.snoozeUntil?.formatted(date: .omitted, time: .shortened) ?? "later")"
        case .applicationExcluded: return "Paused for an excluded app"
        case .battery: return "Paused on battery"
        case .lowPower: return "Paused in Low Power Mode"
        case .outsideSchedule: return "Waiting for your schedule"
        case nil:
            if !displayChoices.isEmpty && displayChoices.allSatisfy({ settings.disabledDisplays.contains($0.id) }) {
                return "Choose a display to show Paper"
            }
            return "Paper is on"
        }
    }

    func reason(for display: String?) -> PauseReason? {
        OverlayPolicy.pauseReason(settings: settings, displayID: display,
            frontmostBundleID: frontmostBundleID, onBattery: onBattery, lowPower: lowPower,
            comparing: comparing, now: now)
    }
    func toggle() {
        settings.enabled.toggle()
        comparing = false
        if settings.enabled { settings.snoozeUntil = nil }
    }
    func snooze(minutes: Double, at date: Date = Date()) {
        applySnooze(until: SnoozeOption.deadline(minutes: minutes, after: date), now: date)
    }
    func snooze(_ option: SnoozeOption, at date: Date = Date(), calendar: Calendar = .current) {
        applySnooze(until: option.deadline(after: date, calendar: calendar), now: date)
    }
    private func applySnooze(until deadline: Date?, now date: Date) {
        guard let deadline, deadline > date else { return }
        comparing = false
        now = date
        settings.snoozeUntil = deadline
    }
    func refreshClock() { now = Date(); scheduleBoundary() }
    func scheduleBoundary() {
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        guard let date = OverlayPolicy.nextEvent(settings: settings, after: Date()) else { return }
        let timer = Timer(fire: date.addingTimeInterval(0.1), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshClock() }
        }
        RunLoop.main.add(timer, forMode: .common)
        boundaryTimer = timer
    }
    func stop() { boundaryTimer?.invalidate(); boundaryTimer = nil }

    private func persist<T: Encodable>(_ value: T, key: String) {
        do { try persistence.save(value, key: key) }
        catch { showError("Could not save settings", error) }
    }
    func showError(_ title: String, _ error: Error) {
        alert = PaperAlert(title: title, message: error.localizedDescription)
    }
    func importRecipes(urls: [URL]) {
        var failures: [String] = []
        var papers = customPapers
        var selected: String?
        for url in urls {
            do {
                guard papers.count < 50 else { throw PaperImportError.tooMany }
                let attributes = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard attributes.isRegularFile == true, (attributes.fileSize ?? Int.max) <= 1_048_576
                else { throw PaperImportError.tooLarge }
                let paper = try RecipeImport.decode(Data(contentsOf: url))
                papers.append(paper)
                selected = paper.id
            } catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        do {
            try persistence.save(papers, key: "papers.v1")
            customPapers = papers
            if let selected { settings.textureID = selected }
        } catch { failures.append(error.localizedDescription) }
        if !failures.isEmpty { alert = PaperAlert(title: "Some papers could not be imported", message: failures.joined(separator: "\n\n")) }
    }
    func removeSelectedImport() {
        let remaining = customPapers.filter { $0.id != settings.textureID }
        do {
            try persistence.save(remaining, key: "papers.v1")
            customPapers = remaining
            settings.textureID = Self.defaultTexture.id
        } catch { showError("Could not remove paper", error) }
    }
    func addExcludedApp(url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else {
            alert = PaperAlert(title: "Choose another app", message: "Choose an application other than Paper.")
            return
        }
        guard !settings.excludedApps.contains(where: { $0.bundleID == id }) else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        settings.excludedApps.append(.init(bundleID: id, name: name))
    }
    func refreshLogin() { loginState = login.state }
    func toggleLogin() {
        do { loginState = try login.toggle() }
        catch { refreshLogin(); showError("Could not change launch at login", error) }
    }
}

struct DisplayChoice: Identifiable, Equatable {
    let id: String
    let name: String
}

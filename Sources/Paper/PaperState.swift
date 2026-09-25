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
        case .tooLarge: return "Choose a JSON file no larger than 1 MB."
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
        paper = try validated(paper)
        // Decoding derives any legacy seed before assigning a fresh identity.
        paper.id = "custom-\(UUID().uuidString.lowercased())"
        return paper
    }
    static func validated(_ value: CustomPaper) throws -> CustomPaper {
        var paper = value
        let numbers = [paper.tintRed, paper.tintGreen, paper.tintBlue, paper.wash, paper.weave, paper.blotch,
                       Double(paper.fiberAngle), Double(paper.fiberStrength), Double(paper.surfaceRoughness),
                       Double(paper.darkGrainStrength ?? 0), Double(paper.lightGrainStrength ?? 0)]
        guard numbers.allSatisfy(\.isFinite) else { throw PaperImportError.invalidRecipe }
        paper.name = String(paper.name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !paper.name.isEmpty else { throw PaperImportError.invalidName }
        paper.name = String(paper.name.prefix(80))
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
            defaults.set(bytes, forKey: "\(key).corrupt.latest")
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
    static let shared = PaperState(defaults: applicationDefaults)
    /// The native harness runs the signed app with a disposable preferences suite.
    /// Only an explicitly named UUID test suite is accepted; normal launches use standard defaults.
    static var isTestRun: Bool { ProcessInfo.processInfo.environment["PAPER_TEST_SUITE"].flatMap(UUID.init(uuidString:)) != nil }
    private static var applicationDefaults: UserDefaults {
        if let id = ProcessInfo.processInfo.environment["PAPER_TEST_SUITE"], UUID(uuidString: id) != nil {
            return UserDefaults(suiteName: "xyz.dustwave.paper.test.\(id)")!
        }
        return .standard
    }
    static let defaultTexture = TexturePreset.preset(id: PaperSettings.defaultTextureID)
    // Use the full pinned catalog, with the default first; no separate ID list to maintain.
    static let builtIns = [defaultTexture] + TexturePreset.all.filter { $0.id != defaultTexture.id }
    @Published var settings: PaperSettings { didSet { persist(settings, key: "settings.v1") } }
    @Published private(set) var customPapers: [CustomPaper]
    @Published private(set) var library: PaperLibrary
    @Published private(set) var deskProfiles: [DeskProfile] = []
    @Published private(set) var activeDeskName: String?
    private var lastDisplayIDs: Set<String>?
    @Published var comparing = false
    @Published var showingCustomSnooze = false
    @Published var alert: PaperAlert?
    @Published var now = Date()
    @Published var onBattery = false
    @Published var lowPower = false
    @Published var batteryPercentage: Int?
    @Published var darkAppearance = false
    @Published var frontmostBundleID: String?
    @Published var excludedPanelLevels: [Int] = []
    @Published var displayChoices: [DisplayChoice] = []
    @Published var shortcutError: String?
    @Published var loginState: LaunchAtLoginState = .disabled
    private let persistence: PaperPersistence
    var diagnosticEvents: [PaperLogEvent] {
        (persistence.defaults.stringArray(forKey: "diagnostic.events.v1") ?? []).suffix(20).compactMap(PaperLogEvent.init(rawValue:))
    }
    func record(_ event: PaperLogEvent) {
        persistence.defaults.set(Array((diagnosticEvents + [event]).suffix(20)).map(\.rawValue), forKey: "diagnostic.events.v1")
    }
    var pendingDiagnostic: Data? {
        get { guard let data = persistence.defaults.data(forKey: "diagnostic.pending.v1"), data.count <= 8192 else { return nil }; return data }
        set { persistence.defaults.set(newValue, forKey: "diagnostic.pending.v1") }
    }
    let login = LaunchAtLoginController()
    private var boundaryTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        persistence = PaperPersistence(defaults: defaults)
        var errors: [String] = []
        do { settings = try persistence.load(PaperSettings.self, key: "settings.v1") ?? PaperSettings() }
        catch {
            var recovered = PaperSettings(); recovered.enabled = false
            settings = recovered
            errors.append("Settings could not be read. Paper is off until you enable it again.")
        }
        let collection: PaperCollection
        do {
            if let saved = try persistence.load(PaperCollection.self, key: "collection.v1") {
                try PaperArchive.validate(saved)
                collection = saved
            } else {
                let legacy = PaperCollection(papers: try persistence.load([CustomPaper].self, key: "papers.v1") ?? [],
                    library: try persistence.load(PaperLibrary.self, key: "library.v1") ?? PaperLibrary())
                try PaperArchive.validate(legacy)
                collection = legacy
            }
        } catch {
            collection = PaperCollection()
            for key in ["collection.v1", "papers.v1", "library.v1"] {
                if let bytes = defaults.data(forKey: key) { defaults.set(bytes, forKey: "\(key).corrupt.latest") }
            }
            errors.append("Your paper library could not be read.")
        }
        customPapers = collection.papers
        library = collection.library
        settings.normalize()
        do {
            deskProfiles = Array((try persistence.load([DeskProfile].self, key: "desks.v1") ?? []).prefix(8))
        } catch { errors.append("Desk profiles could not be read.") }
        normalizeAutomaticLooks()
        if !allTextures.contains(where: { $0.id == settings.textureID }) { settings.textureID = Self.defaultTexture.id }
        if !errors.isEmpty {
            record(.recovery)
            alert = PaperAlert(title: "Recovered default settings",
                              message: errors.joined(separator: " ") + " A copy of the unreadable data was kept locally.")
        }
        refreshLogin()
    }

    var allTextures: [TexturePreset] { Self.builtIns + customPapers.map(TexturePreset.init(custom:)) }
    var favoriteTextures: [TexturePreset] { allTextures.filter { library.favorites.contains($0.id) } }
    var otherTextures: [TexturePreset] { allTextures.filter { !library.favorites.contains($0.id) } }
    var automaticLook: PaperLook? {
        guard [settings.automaticLooks.dayLookID, settings.automaticLooks.nightLookID].allSatisfy({ id in
            library.looks.contains { $0.id == id }
        }), let id = settings.automaticLooks.lookID(at: now, location: settings.schedule.location, darkAppearance: darkAppearance),
              let look = library.looks.first(where: { $0.id == id }),
              allTextures.contains(where: { $0.id == look.textureID }) else { return nil }
        return look
    }
    var appLook: PaperLook? {
        guard settings.appLooksEnabled, let app = frontmostBundleID, let id = settings.appLooks[app] else { return nil }
        return library.looks.first { look in look.id == id && allTextures.contains(where: { $0.id == look.textureID }) }
    }
    var activeLook: PaperLook? { appLook ?? automaticLook }
    var appearance: PaperSettings {
        var value = settings
        activeLook?.apply(to: &value)
        return value
    }
    var texture: TexturePreset { allTextures.first { $0.id == appearance.textureID } ?? Self.defaultTexture }
    var adjustments: TextureRenderer.GrainAdjustments {
        .init(scale: appearance.grainScale, strength: appearance.grainStrength)
    }
    var intensityDescription: String { appearance.intensity.formatted(.percent.precision(.fractionLength(0))) }
    var pauseReason: PauseReason? { reason(for: nil) }
    var status: String {
        switch pauseReason {
        case .disabled: return "Paper is off"
        case .presentation: return "Paused for presentation"
        case .displayExcluded: return "Display is excluded"
        case .comparing: return "Comparing with your original screen"
        case .snoozed: return "Snoozed until \(settings.snoozeUntil?.formatted(date: .omitted, time: .shortened) ?? "later")"
        case .applicationExcluded: return "Paused for an excluded app"
        case .applicationNotIncluded: return "Waiting for a selected app"
        case .battery: return "Paused on battery"
        case .lowBattery: return "Paused for low battery"
        case .lowPower: return "Paused in Low Power Mode"
        case .outsideSchedule:
            return settings.schedule.mode != .fixed && settings.schedule.location?.isValid != true
                ? "Choose a city for your schedule" : "Waiting for your schedule"
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
            batteryPercentage: batteryPercentage, comparing: comparing, now: now)
    }
    func toggle() {
        record(.toggled)
        setEnabled(!settings.enabled)
    }
    func setEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        comparing = false
        if settings.enabled { settings.snoozeUntil = nil }
    }
    func selectTexture(_ id: String) throws {
        guard allTextures.contains(where: { $0.id == id }) else { throw PaperActionError.missingTexture }
        var updated = settings
        updated.textureIntensities[settings.textureID] = settings.intensity
        updated.automaticLooks.enabled = false
        updated.appLooksEnabled = false
        updated.textureID = id
        updated.intensity = updated.textureIntensities[id] ?? settings.intensity
        settings = updated
    }
    func nextFavorite() {
        let favorites = favoriteTextures
        guard !favorites.isEmpty else { return }
        let index = favorites.firstIndex { $0.id == texture.id }.map { ($0 + 1) % favorites.count } ?? 0
        try? selectTexture(favorites[index].id)
    }
    func perform(_ action: ShortcutAction) {
        switch action {
        case .toggle: toggle()
        case .snooze: snooze(minutes: 15)
        case .nextFavorite: nextFavorite()
        case .readingUp: stateStripMove(up: true)
        case .readingDown: stateStripMove(up: false)
        case .presentation: settings.presentationPaused.toggle()
        }
    }
    private func stateStripMove(up: Bool) {
        guard settings.readingStrip.enabled else { return }
        settings.readingStrip.move(up: up)
    }
    func displaysChanged(_ choices: [DisplayChoice]) {
        displayChoices = choices
        let ids = Set(choices.map(\.id))
        guard !ids.isEmpty, lastDisplayIDs != ids else { return }
        lastDisplayIDs = ids
        guard let profile = deskProfiles.first(where: { $0.displayIDs == ids }) else {
            activeDeskName = nil; return
        }
        settings = profile.applying(to: settings)
        normalizeAutomaticLooks()
        if !allTextures.contains(where: { $0.id == settings.textureID }) { settings.textureID = Self.defaultTexture.id }
        activeDeskName = profile.name
    }
    func saveDesk(name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60, !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !displayChoices.isEmpty else { throw PaperActionError.invalidName }
        let ids = Set(displayChoices.map(\.id))
        var profiles = deskProfiles
        let profile = DeskProfile(name: name, displayIDs: ids, settings: settings)
        if let index = profiles.firstIndex(where: { $0.displayIDs == ids }) { profiles[index] = profile }
        else { guard profiles.count < 8 else { throw PaperActionError.tooManyDesks }; profiles.append(profile) }
        try persistence.save(profiles, key: "desks.v1")
        deskProfiles = profiles
        activeDeskName = name
    }
    func removeDesk(_ id: UUID) {
        var profiles = deskProfiles
        profiles.removeAll { $0.id == id }
        do {
            try persistence.save(profiles, key: "desks.v1")
            deskProfiles = profiles
            activeDeskName = profiles.first { $0.displayIDs == Set(displayChoices.map(\.id)) }?.name
        } catch { showError("Could not remove desk profile", error) }
    }
    func toggleFavorite() {
        var updated = library
        if !updated.favorites.insert(texture.id).inserted { updated.favorites.remove(texture.id) }
        saveLibrary(updated)
    }
    @discardableResult func saveLook(name: String) throws -> UUID {
        let name = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60 else { throw PaperActionError.invalidName }
        var updated = library
        var look = PaperLook(name: name, settings: appearance)
        if let index = updated.looks.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            look.id = updated.looks[index].id
            updated.looks[index] = look
        } else {
            guard updated.looks.count < PaperLibrary.maximumLooks else { throw PaperActionError.tooManyLooks }
            updated.looks.append(look)
        }
        try saveCollection(PaperCollection(papers: customPapers, library: updated))
        return look.id
    }
    func applyLook(_ id: UUID) throws {
        guard let look = library.looks.first(where: { $0.id == id }) else { throw PaperActionError.missingLook }
        guard allTextures.contains(where: { $0.id == look.textureID }) else { throw PaperActionError.missingTexture }
        var updated = settings
        updated.textureIntensities[settings.textureID] = settings.intensity
        updated.automaticLooks.enabled = false
        updated.appLooksEnabled = false
        look.apply(to: &updated)
        settings = updated
    }
    func removeLook(_ id: UUID) {
        var updated = library
        updated.looks.removeAll { $0.id == id }
        saveLibrary(updated)
    }
    private func saveLibrary(_ updated: PaperLibrary) {
        do { try saveCollection(PaperCollection(papers: customPapers, library: updated)) }
        catch { showError("Could not save your library", error) }
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
        record(.operationFailed)
        alert = PaperAlert(title: title, message: error.localizedDescription)
    }
    func importRecipes(urls: [URL]) {
        var failures: [String] = []
        var papers = customPapers
        var selected: String?
        for url in urls {
            do {
                guard papers.count < 50 else { throw PaperImportError.tooMany }
                let paper = try RecipeImport.decode(BoundedJSONFile.read(url))
                papers.append(paper)
                selected = paper.id
            } catch { record(.importFailed); failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        do {
            try saveCollection(PaperCollection(papers: papers, library: library))
            if let selected { try selectTexture(selected) }
        } catch { failures.append(error.localizedDescription) }
        if !failures.isEmpty { alert = PaperAlert(title: "Some papers could not be imported", message: failures.joined(separator: "\n\n")) }
    }
    func removeSelectedImport() {
        let removedID = settings.textureID
        let remaining = customPapers.filter { $0.id != settings.textureID }
        do {
            var updated = library
            updated.removeTexture(removedID)
            try saveCollection(PaperCollection(papers: remaining, library: updated))
            settings.textureID = Self.defaultTexture.id
            settings.textureIntensities.removeValue(forKey: removedID)
        } catch { showError("Could not remove paper", error) }
    }
    func addExcludedApp(url: URL, included: Bool = false) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else {
            alert = PaperAlert(title: "Choose another app", message: "Choose an application other than Paper.")
            return
        }
        let apps = included ? settings.includedApps : settings.excludedApps
        guard !apps.contains(where: { $0.bundleID == id }) else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        if included { settings.includedApps.append(.init(bundleID: id, name: name)) }
        else { settings.excludedApps.append(.init(bundleID: id, name: name)) }
    }
    private func normalizeAutomaticLooks() {
        var automatic = settings.automaticLooks
        let ids = Set(library.looks.map(\.id))
        if let id = automatic.dayLookID, !ids.contains(id) { automatic.dayLookID = nil }
        if let id = automatic.nightLookID, !ids.contains(id) { automatic.nightLookID = nil }
        if automatic != settings.automaticLooks { settings.automaticLooks = automatic }
        let validAppLooks = settings.appLooks.filter { ids.contains($0.value) }
        if validAppLooks != settings.appLooks { settings.appLooks = validAppLooks }
    }
    private func saveCollection(_ value: PaperCollection) throws {
        try PaperArchive.validate(value)
        try persistence.save(value, key: "collection.v1")
        customPapers = value.papers
        library = value.library
        normalizeAutomaticLooks()
    }
    func exportLibrary() throws -> Data {
        try PaperArchive(collection: PaperCollection(papers: customPapers, library: library)).encoded()
    }
    func importLibrary(_ data: Data) throws {
        let archive = try PaperArchive.decode(data)
        let merged = try archive.merging(into: PaperCollection(papers: customPapers, library: library))
        try saveCollection(merged)
    }
    func refreshLogin() { loginState = login.state }
    func toggleLogin() {
        do { loginState = try login.toggle() }
        catch { refreshLogin(); showError("Could not change launch at login", error) }
    }
}

enum PaperActionError: LocalizedError {
    case missingTexture, missingLook, invalidName, tooManyLooks, tooManyDesks, invalidDuration
    var errorDescription: String? {
        switch self {
        case .missingTexture: return "This texture is no longer available. Choose another paper."
        case .missingLook: return "This saved look is no longer available."
        case .invalidName: return "Give this look a name between 1 and 60 characters."
        case .tooManyLooks: return "You can save up to eight looks. Remove one or reuse an existing name to replace it."
        case .tooManyDesks: return "You can save up to eight desk profiles. Remove one first."
        case .invalidDuration: return "Choose a whole number of minutes between 1 and 1,440."
        }
    }
}

struct DisplayChoice: Identifiable, Equatable {
    let id: String
    let name: String
}

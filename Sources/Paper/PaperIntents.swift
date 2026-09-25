import AppIntents
import PaperCore

// Intents execute in Paper and share the same state and commands as the controls.
struct TogglePaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Paper"
    static var description = IntentDescription("Turn the paper overlay on or off.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        PaperState.shared.toggle()
        return .result()
    }
}

struct SetPaperEnabledIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Paper Enabled"
    static var openAppWhenRun = true
    @Parameter(title: "Enabled", default: true) var enabled: Bool
    static var parameterSummary: some ParameterSummary { Summary("Set Paper enabled to \(\.$enabled)") }
    @MainActor func perform() async throws -> some IntentResult {
        PaperState.shared.setEnabled(enabled)
        return .result()
    }
}

struct SnoozePaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Snooze Paper"
    static var openAppWhenRun = true
    @Parameter(title: "Minutes", default: 30) var minutes: Int
    static var parameterSummary: some ParameterSummary { Summary("Snooze Paper for \(\.$minutes) minutes") }
    @MainActor func perform() async throws -> some IntentResult {
        guard (1...1440).contains(minutes) else { throw PaperActionError.invalidDuration }
        PaperState.shared.snooze(minutes: Double(minutes))
        return .result()
    }
}

struct PaperTextureEntity: AppEntity {
    var id: String
    var name: String
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Paper texture")
    static var defaultQuery = PaperTextureQuery()
    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
}

struct PaperTextureQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [PaperTextureEntity] {
        PaperState.shared.allTextures.filter { identifiers.contains($0.id) }.map { .init(id: $0.id, name: $0.name) }
    }
    @MainActor func suggestedEntities() async throws -> [PaperTextureEntity] {
        (PaperState.shared.favoriteTextures + PaperState.shared.otherTextures).map { .init(id: $0.id, name: $0.name) }
    }
    @MainActor func entities(matching string: String) async throws -> [PaperTextureEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

struct SelectPaperTextureIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Paper Texture"
    static var openAppWhenRun = true
    @Parameter(title: "Texture") var texture: PaperTextureEntity
    static var parameterSummary: some ParameterSummary { Summary("Select \(\.$texture) in Paper") }
    @MainActor func perform() async throws -> some IntentResult {
        try PaperState.shared.selectTexture(texture.id)
        return .result()
    }
}

struct PaperLookEntity: AppEntity {
    var id: String
    var name: String
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved Paper look")
    static var defaultQuery = PaperLookQuery()
    var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }
}

struct PaperLookQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [String]) async throws -> [PaperLookEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
    @MainActor func suggestedEntities() async throws -> [PaperLookEntity] {
        PaperState.shared.library.looks.map { .init(id: $0.id.uuidString, name: $0.name) }
    }
    @MainActor func entities(matching string: String) async throws -> [PaperLookEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

struct ApplyPaperLookIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Paper Look"
    static var openAppWhenRun = true
    @Parameter(title: "Look") var look: PaperLookEntity
    static var parameterSummary: some ParameterSummary { Summary("Apply \(\.$look) in Paper") }
    @MainActor func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: look.id) else { throw PaperActionError.missingLook }
        try PaperState.shared.applyLook(id)
        return .result()
    }
}

struct PaperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TogglePaperIntent(), phrases: ["Toggle \(.applicationName)"],
                    shortTitle: "Toggle Paper", systemImageName: "doc.text")
        AppShortcut(intent: SnoozePaperIntent(), phrases: ["Snooze \(.applicationName)"],
                    shortTitle: "Snooze Paper", systemImageName: "moon.zzz")
        AppShortcut(intent: SelectPaperTextureIntent(), phrases: ["Choose a texture in \(.applicationName)"],
                    shortTitle: "Select Texture", systemImageName: "square.stack")
        AppShortcut(intent: ApplyPaperLookIntent(), phrases: ["Apply a saved look in \(.applicationName)"],
                    shortTitle: "Apply Saved Look", systemImageName: "star")
    }
}

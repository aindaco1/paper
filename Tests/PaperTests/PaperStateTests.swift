import XCTest
import AppKit
@testable import Paper
import PaperCore

@MainActor
final class PaperStateTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "xyz.dustwave.paper.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }
    func testCorruptSettingsArePreservedBeforeRecovery() throws {
        try withDefaults { defaults in
            let bad = Data("broken json".utf8)
            defaults.set(bad, forKey: "settings.v1")
            let state = PaperState(defaults: defaults)
            XCTAssertNotNil(state.alert)
            XCTAssertEqual(state.settings.intensity, 0.22)
            XCTAssertEqual(state.texture.name, "Soft Wove")
            let backup = defaults.dictionaryRepresentation().first { $0.key.hasPrefix("settings.v1.corrupt.") }
            XCTAssertEqual(backup?.value as? Data, bad)
            state.settings.intensity = 0.30
            let restored = try PaperPersistence(defaults: defaults).load(PaperSettings.self, key: "settings.v1")
            XCTAssertEqual(restored?.intensity, 0.30)
        }
    }
    func testLegacyImportKeepsSeedButAssignsUniqueIdentity() throws {
        let data = Data(#"{"id":"old-paper","name":"Imported paper","tintRed":0.9,"tintGreen":0.9,"tintBlue":0.9,"wash":0.4,"weave":0.1,"blotch":0.1}"#.utf8)
        let a = try RecipeImport.decode(data)
        let b = try RecipeImport.decode(data)
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(a.seed, b.seed)
        XCTAssertEqual(a.engineVersion, .legacy)
    }
    func testMalformedLargeAndFutureRecipesAreRejected() {
        XCTAssertThrowsError(try RecipeImport.decode(Data("{}".utf8))) { error in
            XCTAssertTrue(error.localizedDescription.contains("Deckle paper recipe"))
        }
        XCTAssertThrowsError(try RecipeImport.decode(Data(repeating: 0, count: 1_048_577)))
        let future = Data(#"{"id":"x","name":"X","tintRed":1,"tintGreen":1,"tintBlue":1,"wash":0.3,"weave":0,"blotch":0,"engineVersion":999}"#.utf8)
        XCTAssertThrowsError(try RecipeImport.decode(future))
    }
    func testExpandedCatalogRendersAndPreservesSelectionsAcrossLaunches() {
        let presets = PaperState.builtIns
        XCTAssertEqual(presets.count, 26)
        XCTAssertEqual(Set(presets.map(\.id)).count, 26)
        XCTAssertEqual(Set(presets.map(\.id)), Set(TexturePreset.all.map(\.id)))
        for preset in presets {
            withDefaults { defaults in
                let state = PaperState(defaults: defaults)
                state.settings.textureID = preset.id
                let restarted = PaperState(defaults: defaults)
                XCTAssertEqual(restarted.texture.id, preset.id)
                let tile = TextureRenderer.compositeTile(for: restarted.texture, backingScale: 1)
                XCTAssertNotNil(tile.cgImage(forProposedRect: nil, context: nil, hints: nil))
            }
        }
    }
    func testDefaultAndMissingTextureRecoveryPreserveValidSavedChoices() {
        withDefaults { defaults in
            let state = PaperState(defaults: defaults)
            XCTAssertEqual(state.texture.name, "Soft Wove")
            XCTAssertEqual(PaperState.builtIns.first?.id, state.texture.id)
            state.settings.textureID = "quiet-gray"
            XCTAssertEqual(PaperState(defaults: defaults).texture.name, "Quiet Gray")
            state.settings.textureID = "no-longer-available"
            XCTAssertEqual(state.texture.name, "Soft Wove")
            let recovered = PaperState(defaults: defaults)
            XCTAssertEqual(recovered.settings.textureID, "classic-matte")
        }
    }
    func testSnoozePersistsAndResumesOnlyWhenOtherRulesAllow() {
        withDefaults { defaults in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let state = PaperState(defaults: defaults)
            state.comparing = true
            state.snooze(minutes: 45, at: now)
            let deadline = now.addingTimeInterval(45 * 60)
            XCTAssertEqual(state.settings.snoozeUntil, deadline)
            XCTAssertFalse(state.comparing)
            state.snooze(minutes: .nan, at: now)
            XCTAssertEqual(state.settings.snoozeUntil, deadline)
            let restarted = PaperState(defaults: defaults)
            XCTAssertEqual(restarted.settings.snoozeUntil, deadline)
            restarted.settings.pauseOnBattery = true
            restarted.onBattery = true
            restarted.now = deadline
            XCTAssertEqual(restarted.pauseReason, .battery)
            restarted.settings.enabled = false
            restarted.snooze(.tomorrow, at: now)
            XCTAssertEqual(restarted.pauseReason, .disabled)
        }
    }
    func testIntensityAccessibilityDescriptionMatchesRoundedDisplay() {
        withDefaults { defaults in
            let state = PaperState(defaults: defaults)
            state.settings.intensity = 0.29
            XCTAssertEqual(state.intensityDescription, 0.29.formatted(.percent.precision(.fractionLength(0))))
            XCTAssertTrue(state.intensityDescription.contains("29"))
        }
    }
    func testRecipeRoundTripAndPartialImportFailure() throws {
        try withDefaults { defaults in
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let good = directory.appendingPathComponent("good.json")
            let bad = directory.appendingPathComponent("bad.json")
            var paper = CustomPaper()
            paper.name = "My weave"
            paper.seed = 42
            try JSONEncoder().encode(paper).write(to: good)
            try Data("invalid".utf8).write(to: bad)
            let state = PaperState(defaults: defaults)
            state.importRecipes(urls: [good, bad])
            XCTAssertEqual(state.customPapers.count, 1)
            XCTAssertEqual(state.texture.name, "My weave")
            XCTAssertEqual(state.customPapers.first?.seed, 42)
            XCTAssertNotNil(state.alert)
            let restarted = PaperState(defaults: defaults)
            XCTAssertEqual(restarted.texture.id, state.texture.id)
            restarted.removeSelectedImport()
            XCTAssertEqual(restarted.customPapers.count, 0)
            XCTAssertEqual(restarted.texture.name, "Soft Wove")
        }
    }
    func testCompareDoesNotChangePersistentStateAndToggleEndsSnooze() {
        withDefaults { defaults in
            let state = PaperState(defaults: defaults)
            state.comparing = true
            XCTAssertEqual(state.pauseReason, .comparing)
            XCTAssertTrue(state.settings.enabled)
            state.snooze(minutes: 15)
            XCTAssertFalse(state.comparing)
            state.toggle()
            XCTAssertEqual(state.pauseReason, .disabled)
            state.toggle()
            XCTAssertNil(state.settings.snoozeUntil)
            XCTAssertFalse(PaperState(defaults: defaults).comparing)
        }
    }
    func testOverlayNeverTakesInputOrFocus() throws {
        guard let screen = NSScreen.screens.first else { throw XCTSkip("Requires a display") }
        let panel = PaperOverlayWindow(screen: screen)
        XCTAssertEqual(panel.frame, screen.frame)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(panel.isVisible)
    }
}

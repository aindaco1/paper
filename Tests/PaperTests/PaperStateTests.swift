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
        XCTAssertThrowsError(try RecipeImport.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try RecipeImport.decode(Data(repeating: 0, count: 1_048_577)))
        let future = Data(#"{"id":"x","name":"X","tintRed":1,"tintGreen":1,"tintBlue":1,"wash":0.3,"weave":0,"blotch":0,"engineVersion":999}"#.utf8)
        XCTAssertThrowsError(try RecipeImport.decode(future))
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
            XCTAssertEqual(restarted.texture.id, "quiet-gray")
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

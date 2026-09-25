import XCTest
import PaperCore
@testable import Paper

final class PaperLibraryTests: XCTestCase {
    @MainActor private func withState(_ body: (PaperState, UserDefaults) throws -> Void) rethrows {
        let name = "PaperLibraryTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(PaperState(defaults: defaults), defaults)
    }
    @MainActor func testFavoritesPersistWithoutDuplicatingOrHidingTextures() throws {
        try withState { state, defaults in
            state.toggleFavorite()
            try state.selectTexture("quiet-gray")
            state.toggleFavorite()
            let restored = PaperState(defaults: defaults)
            XCTAssertEqual(Set(restored.favoriteTextures.map(\.id)), ["classic-matte", "quiet-gray"])
            XCTAssertEqual((restored.favoriteTextures + restored.otherTextures).count, 26)
            restored.toggleFavorite()
            XCTAssertFalse(restored.library.favorites.contains("quiet-gray"))
        }
    }
    @MainActor func testLooksRestoreAppearanceWithoutOverridingVisibilityRules() throws {
        try withState { state, defaults in
            state.settings.intensity = 0.34; state.settings.grainScale = 2
            let id = try state.saveLook(name: "Reading")
            state.settings.enabled = false
            state.settings.pauseOnBattery = true
            state.settings.snoozeUntil = Date.distantFuture
            try state.selectTexture("quiet-gray")
            state.settings.intensity = 0.1
            let restored = PaperState(defaults: defaults)
            try restored.applyLook(id)
            XCTAssertEqual(restored.settings.textureID, "classic-matte")
            XCTAssertEqual(restored.settings.intensity, 0.34)
            XCTAssertEqual(restored.settings.grainScale, 2)
            XCTAssertFalse(restored.settings.enabled)
            XCTAssertTrue(restored.settings.pauseOnBattery)
            XCTAssertEqual(restored.settings.snoozeUntil, Date.distantFuture)
        }
    }
    @MainActor func testLookReplacementRetainsIdentityAndLimitIsEnforced() throws {
        try withState { state, _ in
            let id = try state.saveLook(name: "Reading")
            state.settings.intensity = 0.30
            XCTAssertEqual(try state.saveLook(name: " reading "), id)
            for index in 2...8 { try state.saveLook(name: "Look \(index)") }
            XCTAssertThrowsError(try state.saveLook(name: "Ninth"))
            XCTAssertThrowsError(try state.saveLook(name: "  "))
            state.removeLook(id)
            XCTAssertThrowsError(try state.applyLook(id))
            XCTAssertNoThrow(try state.saveLook(name: "Replacement"))
        }
    }
    @MainActor func testAutomationRejectsMissingTextureAndSettingOnClearsSnooze() throws {
        try withState { state, _ in
            XCTAssertThrowsError(try state.selectTexture("missing"))
            XCTAssertEqual(state.texture.name, "Soft Wove")
            state.settings.snoozeUntil = Date.distantFuture
            state.settings.pauseOnBattery = true
            state.setEnabled(true)
            XCTAssertNil(state.settings.snoozeUntil)
            XCTAssertTrue(state.settings.pauseOnBattery)
        }
    }
}

import XCTest
import PaperCore
import Darwin
@testable import Paper

@MainActor final class ArchiveTests: XCTestCase {
    private func state(_ body: (PaperState, UserDefaults) throws -> Void) rethrows {
        let name = "PaperArchiveTests.\(UUID())"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        try body(PaperState(defaults:defaults),defaults)
    }
    func testBackupRoundTripIsIdempotentAndPreservesVisibilitySettings() throws {
        try state { source, _ in
            source.toggleFavorite(); try source.saveLook(name:"Reading")
            let data = try source.exportLibrary()
            try state { target, defaults in
                target.settings.enabled = false; target.settings.appRuleMode = .only
                try target.importLibrary(data); try target.importLibrary(data)
                XCTAssertEqual(target.library.looks.count,1)
                XCTAssertEqual(target.library.favorites,["classic-matte"])
                XCTAssertFalse(target.settings.enabled); XCTAssertEqual(target.settings.appRuleMode,.only)
                XCTAssertEqual(PaperState(defaults:defaults).library,target.library)
                XCTAssertNotNil(defaults.data(forKey:"collection.v1"))
            }
        }
    }
    func testConflictingRecipeAndLookIDsAreRemappedTogether() throws {
        var paper = CustomPaper(); paper.name = "Original"
        var settings = PaperSettings(); settings.textureID = paper.id
        let look = PaperLook(name:"Reading",settings:settings)
        var original = PaperCollection(papers:[paper]); original.library.looks = [look]
        paper.tintRed = 0.1
        var incoming = PaperCollection(papers:[paper]); incoming.library.looks = [look]; incoming.library.favorites = [paper.id]
        let archive = PaperArchive(collection:incoming)
        let merged = try archive.merging(into:original)
        XCTAssertEqual(merged.papers.count,2); XCTAssertEqual(merged.library.looks.count,2)
        XCTAssertNotEqual(merged.papers[0].id,merged.papers[1].id)
        XCTAssertEqual(merged.library.looks[1].textureID,merged.papers[1].id)
        XCTAssertEqual(merged.library.favorites,[merged.papers[1].id])
        let again = try archive.merging(into:merged)
        XCTAssertEqual(again.papers.count,2); XCTAssertEqual(again.library.looks.count,2)
    }
    func testMissingReferencesDuplicateIDsAndUnsupportedSchemasFailBeforeMutation() throws {
        try state { state, _ in
            let before = state.library
            var collection = PaperCollection()
            var settings = PaperSettings(); settings.textureID = "missing"
            collection.library.looks = [PaperLook(name:"Broken",settings:settings)]
            let encoder = JSONEncoder()
            XCTAssertThrowsError(try state.importLibrary(encoder.encode(PaperArchive(collection:collection))))
            collection.library.looks = []
            collection.library.favorites = ["missing"]
            XCTAssertThrowsError(try state.importLibrary(encoder.encode(PaperArchive(collection:collection))))
            var bad = PaperArchive(collection:PaperCollection()); bad.version = 999
            XCTAssertThrowsError(try state.importLibrary(encoder.encode(bad)))
            let duplicate = CustomPaper(); bad = PaperArchive(collection:PaperCollection(papers:[duplicate,duplicate]))
            XCTAssertThrowsError(try state.importLibrary(encoder.encode(bad)))
            XCTAssertEqual(state.library,before); XCTAssertTrue(state.customPapers.isEmpty)
        }
    }
    func testCapacityFailureLeavesLibraryUnchanged() throws {
        try state { state, _ in
            for index in 0..<8 { try state.saveLook(name:"Existing \(index)") }
            let before = state.library
            var incoming = PaperCollection(); incoming.library.looks = [PaperLook(name:"Ninth",settings:PaperSettings())]
            XCTAssertThrowsError(try state.importLibrary(PaperArchive(collection:incoming).encoded()))
            XCTAssertEqual(state.library,before)
        }
    }
    func testBoundedReaderRejectsOversizedFilesDirectoriesAndPipes() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let large = folder.appendingPathComponent("large.json")
        try Data(repeating:0,count:BoundedJSONFile.maximumBytes+1).write(to:large)
        XCTAssertThrowsError(try BoundedJSONFile.read(large))
        XCTAssertThrowsError(try BoundedJSONFile.read(folder))
        let pipe = folder.appendingPathComponent("pipe.json")
        XCTAssertEqual(mkfifo(pipe.path,0o600),0)
        XCTAssertThrowsError(try BoundedJSONFile.read(pipe))
        let valid = folder.appendingPathComponent("valid.json")
        try Data("{}".utf8).write(to:valid)
        XCTAssertEqual(try BoundedJSONFile.read(valid),Data("{}".utf8))
    }
    func testHostileJSONAndNonfiniteRecipesAreRejected() throws {
        let nested = Data((String(repeating:"[",count:1500)+"0"+String(repeating:"]",count:1500)).utf8)
        XCTAssertThrowsError(try PaperArchive.decode(nested))
        XCTAssertThrowsError(try PaperArchive.decode(Data(repeating:0,count:1_048_577)))
        var recipe = CustomPaper(); recipe.fiberAngle = .nan
        XCTAssertThrowsError(try RecipeImport.validated(recipe))
        recipe.fiberAngle = 0; recipe.name = "\u{0}\n"
        XCTAssertThrowsError(try RecipeImport.validated(recipe))
    }
    func testLegacyLibraryRejectsInvalidReferencesAndKeepsRecoveryCopy() throws {
        try state { _, defaults in
            var library = PaperLibrary(); library.favorites = ["missing"]
            let bytes = try JSONEncoder().encode(library)
            defaults.set(bytes, forKey: "library.v1")
            let recovered = PaperState(defaults: defaults)
            XCTAssertNotNil(recovered.alert)
            XCTAssertTrue(recovered.library.favorites.isEmpty)
            XCTAssertEqual(defaults.data(forKey: "library.v1.corrupt.latest"), bytes)
        }
    }
    func testCorruptionBackupsStayBoundedAcrossRepeatedLaunches() throws {
        try state { _, defaults in
            defaults.set(Data("broken".utf8),forKey:"settings.v1")
            for _ in 0..<10 { _ = PaperState(defaults:defaults) }
            XCTAssertEqual(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("settings.v1.corrupt.") }.count,1)
        }
    }
    func testAutomaticAppearanceDoesNotRewriteManualSettingsAndManualChoiceStopsIt() throws {
        try state { state, defaults in
            state.settings.intensity = 0.15
            let day = try state.saveLook(name:"Day")
            try state.selectTexture("quiet-gray"); state.settings.intensity = 0.35
            let night = try state.saveLook(name:"Night")
            state.settings.schedule.location = SolarLocation(name:"London",latitude:51.5,longitude:0,timeZoneIdentifier:"Europe/London")
            state.settings.automaticLooks = .init()
            state.settings.automaticLooks.dayLookID = day; state.settings.automaticLooks.nightLookID = night
            state.settings.automaticLooks.enabled = true
            state.settings.enabled = false; state.settings.displayIntensities = ["external":0.1]
            state.now = ISO8601DateFormatter().date(from:"2026-06-21T12:00:00Z")!
            XCTAssertEqual(state.texture.id,"classic-matte"); XCTAssertEqual(state.appearance.intensity,0.15)
            XCTAssertEqual(state.appearance.intensity(for:"external"),0.1)
            XCTAssertEqual(state.settings.textureID,"quiet-gray"); XCTAssertEqual(state.pauseReason,.disabled)
            state.now = state.now.addingTimeInterval(12*3600)
            XCTAssertEqual(state.texture.id,"quiet-gray"); XCTAssertEqual(state.appearance.intensity,0.35)
            let restored = PaperState(defaults:defaults)
            XCTAssertTrue(restored.settings.automaticLooks.enabled)
            try state.applyLook(day)
            XCTAssertFalse(state.settings.automaticLooks.enabled); XCTAssertFalse(state.settings.enabled)
            state.settings.automaticLooks.enabled = true
            state.removeLook(day)
            XCTAssertNil(state.settings.automaticLooks.dayLookID)
            XCTAssertNil(state.automaticLook, "A missing day or night look falls back to manual appearance")
        }
    }
}

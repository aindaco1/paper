import XCTest
import DustWaveDiagnostics
@testable import Paper
final class PaperDiagnosticsTests: XCTestCase {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/paper-diagnostic.json")
    func testGoldenPublicContractRoundTrips() throws {
        let bytes = try Data(contentsOf: fixture)
        let report = try JSONDecoder().decode(PaperDiagnosticReport.self, from: bytes)
        let encoded = try report.encoded()
        XCTAssertEqual(try JSONSerialization.jsonObject(with: bytes) as? NSDictionary, try JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
    }
    func testStoredReportsCannotInjectFreeFormPrivateData() throws {
        var report = try JSONDecoder().decode(PaperDiagnosticReport.self, from: Data(contentsOf: fixture))
        report.state.pause = "/Users/private/name"
        XCTAssertThrowsError(try report.encoded())
        report.state.pause = "none"; report.application.build = "private-build"
        XCTAssertThrowsError(try report.encoded())
        report.application.build = "7"; report.state.displays = -1
        XCTAssertThrowsError(try report.encoded())
    }
    @MainActor func testSnapshotExcludesNamesPathsCitiesAndIdentifiersAndBoundsJournal() throws {
        let suite = "xyz.dustwave.paper.test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = PaperState(defaults: defaults)
        state.settings.excludedApps = [.init(bundleID: "private.bundle", name: "Private App")]
        state.settings.disabledDisplays = ["Private Display ID"]
        for _ in 0..<100 { state.record(.importFailed) }
        let report = PaperDiagnosticReport.snapshot(state)
        XCTAssertEqual(report.state.events.count, 20)
        let json = String(decoding: try report.encoded(), as: UTF8.self)
        XCTAssertFalse(json.contains("Private")); XCTAssertFalse(json.contains("private.bundle")); XCTAssertFalse(json.contains("excludedApps"))
    }
}

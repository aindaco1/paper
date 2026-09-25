import XCTest
import CoreGraphics
@testable import PaperCore

final class SystemOverviewPolicyTests: XCTestCase {
    private let display = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    private func overview(_ owner: String = "com.apple.WindowManager", layer: Int = 19,
                          alpha: Double = 1, frame: CGRect? = nil, displays: [CGRect]? = nil) -> Bool {
        SystemOverviewPolicy.isOverviewSurface(ownerBundleID: owner, layer: layer, alpha: alpha,
            frame: frame ?? display, displays: displays ?? [display], dockWindowLevel: 20)
    }

    func testDockRevealDoesNotPauseEvenWhenItsWindowCoversTheDisplay() {
        // Observed on macOS 27: the Dock's visual strip is backed by this
        // full-display layer-20 window, not a strip-sized window.
        XCTAssertFalse(overview("com.apple.dock", layer: 20))
    }

    func testCommandTabBackdropDoesNotPause() {
        // Command-Tab creates another full-display Dock surface. Classification
        // must not depend on window IDs, ordering or a cached idle window.
        XCTAssertFalse(overview("com.apple.dock", layer: 20))
    }

    func testOverviewSurfacesUseTheirSpecificOwnerAndLayer() {
        XCTAssertTrue(overview())
        XCTAssertTrue(overview("com.apple.dock", layer: 18))
        XCTAssertFalse(overview("com.apple.dock", layer: 19))
        XCTAssertFalse(overview(layer: 20))
        XCTAssertFalse(overview(layer: 18))
        XCTAssertFalse(overview("ordinary.app"))
    }

    func testDockAndSwitcherRemainVisibleAcrossRepeatedOverviewTransitions() {
        let sequence: [(String, Int)] = [
            ("com.apple.dock", 20), ("com.apple.WindowManager", 19),
            ("com.apple.dock", 20), ("com.apple.WindowManager", 19), ("com.apple.dock", 20)
        ]
        XCTAssertEqual(sequence.map { overview($0.0, layer: $0.1) }, [false, true, false, true, false])
    }

    func testSmallHiddenAndInvalidSurfacesAreNotOverviews() {
        XCTAssertFalse(overview(frame: CGRect(x: 0, y: 0, width: 1728, height: 60)))
        XCTAssertFalse(overview(frame: .zero))
        XCTAssertFalse(overview(frame: .infinite))
        XCTAssertFalse(overview(alpha: 0))
        XCTAssertFalse(overview(alpha: .nan))
        XCTAssertFalse(overview(alpha: .infinity))
        XCTAssertFalse(overview(displays: []))
    }

    func testOverviewOnAnOffsetDisplayAndOnePointRounding() {
        let external = CGRect(x: -1280, y: -720, width: 1280, height: 720)
        XCTAssertTrue(overview(frame: external, displays: [display, external]))
        XCTAssertFalse(overview(frame: external, displays: [display]))
        XCTAssertTrue(overview(frame: display.insetBy(dx: 1, dy: 1)))
        XCTAssertFalse(overview(frame: display.insetBy(dx: 2, dy: 2)))
    }
}

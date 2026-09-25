import Foundation
import CoreGraphics

/// Classifies public window metadata, without reading window content or titles.
public enum SystemOverviewPolicy {
    public static func isOverviewSurface(ownerBundleID: String, layer: Int, alpha: Double,
                                         frame: CGRect, displays: [CGRect], dockWindowLevel: Int) -> Bool {
        // Dock's ordinary surface and Command-Tab backdrop can both cover an
        // entire display at the Dock level. Neither is an overview. Mission
        // Control uses a separate surface: WindowManager just below the Dock on
        // newer macOS, or Dock two levels below it on earlier macOS.
        let overviewLayer: Int
        switch ownerBundleID {
        case "com.apple.WindowManager": overviewLayer = dockWindowLevel - 1
        case "com.apple.dock": overviewLayer = dockWindowLevel - 2
        default: return false
        }
        guard layer == overviewLayer, alpha.isFinite, alpha > 0,
              frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite, !frame.isEmpty, !frame.isInfinite else { return false }
        return displays.contains { !$0.isEmpty && frame.insetBy(dx: -1, dy: -1).contains($0) }
    }
}

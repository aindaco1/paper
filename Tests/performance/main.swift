// Developer-only optimized renderer benchmark. Compile with the pinned renderer files.
import AppKit
import Foundation

func milliseconds(_ body: () -> Void) -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
}
var rows: [[String: Any]] = []
for scale: CGFloat in [1, 2] {
    for texture in TexturePreset.all {
        autoreleasepool {
            TextureRenderer.resetCaches()
            let cold = milliseconds { _ = TextureRenderer.compositeTile(for: texture, backingScale: scale) }
            let metrics = TextureRenderer.cacheMetrics
            let warm = milliseconds {
                for _ in 0..<100 { _ = TextureRenderer.compositeTile(for: texture, backingScale: scale) }
            } / 100
            precondition(TextureRenderer.cacheMetrics.compositeHits == metrics.compositeHits + 100)
            precondition(TextureRenderer.cacheMetrics.fieldMisses == metrics.fieldMisses)
            rows.append(["texture": texture.id, "backingScale": scale, "coldMilliseconds": cold,
                         "cachedMilliseconds": warm, "cachedRepetitions": 100])
        }
    }
}
TextureRenderer.resetCaches()
let result: [String: Any] = ["status": "passed", "optimized": true,
    "os": ProcessInfo.processInfo.operatingSystemVersionString, "measurements": rows]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)

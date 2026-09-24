import AppKit

// Original icon drawn with native vector primitives; no external asset dependency.
let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Paper.iconset")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 200, yRadius: 200)
        NSGradient(starting: NSColor(srgbRed: 0.29, green: 0.36, blue: 0.31, alpha: 1),
                   ending: NSColor(srgbRed: 0.14, green: 0.21, blue: 0.17, alpha: 1))!.draw(in: background, angle: -90)
        let paper = NSBezierPath(roundedRect: NSRect(x: 265, y: 218, width: 494, height: 602), xRadius: 30, yRadius: 30)
        NSColor(srgbRed: 0.96, green: 0.94, blue: 0.86, alpha: 1).setFill()
        paper.fill()
        NSColor(srgbRed: 0.40, green: 0.44, blue: 0.36, alpha: 0.5).setStroke()
        for (index, width) in [300.0, 300.0, 210.0].enumerated() {
            let line = NSBezierPath()
            line.lineWidth = 18
            line.lineCapStyle = .round
            line.move(to: NSPoint(x: 356, y: 630 - Double(index) * 94))
            line.line(to: NSPoint(x: 356 + width, y: 630 - Double(index) * 94))
            line.stroke()
        }
        image.unlockFocus()
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}


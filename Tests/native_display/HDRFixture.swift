// Test-only static HDR patches and a physical pointer/keyboard target.
// No screen capture, display adjustment, or synthetic input.
import AppKit
import Metal
import QuartzCore

final class HDRPatch: NSView {
    let value: Double
    let metal = CAMetalLayer()
    let device = MTLCreateSystemDefaultDevice()!
    lazy var queue = device.makeCommandQueue()!
    init(value: Double) {
        self.value = value
        super.init(frame: .zero)
        wantsLayer = true
        metal.device = device
        metal.pixelFormat = .rgba16Float
        metal.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        metal.wantsExtendedDynamicRangeContent = true
        metal.isOpaque = true
        layer = metal
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() { super.layout(); render() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); render() }
    func render() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = window?.backingScaleFactor ?? 2
        metal.contentsScale = scale
        metal.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        guard let drawable = metal.nextDrawable(), let command = queue.makeCommandBuffer() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: value, green: value, blue: value, alpha: 1)
        command.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        command.present(drawable)
        command.commit()
    }
}

final class HDRFixture: NSObject, NSApplicationDelegate {
    let events: URL
    var window: NSWindow!
    var patches: [HDRPatch] = []
    var clicks = 0
    let clickLabel = NSTextField(labelWithString: "Clicks received: 0")
    let headroomLabel = NSTextField(labelWithString: "")
    init(events: URL) { self.events = events }
    func record(_ event: String) {
        guard let screen = window.screen else { return }
        let state: [String: Any] = ["event": event, "time": Date().timeIntervalSince1970,
            "clicks": clicks, "frontPID": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0,
            "currentEDR": screen.maximumExtendedDynamicRangeColorComponentValue,
            "potentialEDR": screen.maximumPotentialExtendedDynamicRangeColorComponentValue,
            "referenceEDR": screen.maximumReferenceExtendedDynamicRangeColorComponentValue,
            "scale": screen.backingScaleFactor,
            "colorSpace": screen.colorSpace?.localizedName ?? "unknown",
            "patchValues": [0.18, 1.0, 2.0, 4.0]]
        let data = try! JSONSerialization.data(withJSONObject: state, options: .sortedKeys) + Data([10])
        let handle = try! FileHandle(forWritingTo: events)
        defer { try? handle.close() }
        try! handle.seekToEnd(); try! handle.write(contentsOf: data)
        headroomLabel.stringValue = String(format: "Current EDR %.2f× · Potential %.2f×",
            screen.maximumExtendedDynamicRangeColorComponentValue,
            screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        FileManager.default.createFile(atPath: events.path, contents: nil)
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 820, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Paper HDR and input test"
        window.isReleasedWhenClosed = false
        let stack = NSStackView()
        stack.orientation = .vertical; stack.spacing = 18; stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        let title = NSTextField(labelWithString: "Paper HDR and input test")
        title.font = .boldSystemFont(ofSize: 22)
        stack.addArrangedSubview(title)
        let instructions = NSTextField(wrappingLabelWithString:
            "Compare the white patches with Paper on and off (⇧⌥⌘P). HDR 2× and 4× should remain brighter than SDR white when headroom allows. Texture changes appearance; this is not a color-accuracy test.")
        stack.addArrangedSubview(instructions)
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 16; row.distribution = .fillEqually
        for (label, value) in [("Gray 18%", 0.18), ("SDR white 1×", 1.0), ("HDR white 2×", 2.0), ("HDR white 4×", 4.0)] {
            let column = NSStackView(); column.orientation = .vertical; column.spacing = 8
            let patch = HDRPatch(value: value); patches.append(patch)
            column.addArrangedSubview(patch)
            column.addArrangedSubview(NSTextField(labelWithString: label))
            patch.heightAnchor.constraint(equalToConstant: 140).isActive = true
            patch.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
            row.addArrangedSubview(column)
        }
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(headroomLabel)
        let controls = NSStackView(); controls.spacing = 16
        controls.addArrangedSubview(NSButton(title: "Click-through test", target: self, action: #selector(clicked)))
        controls.addArrangedSubview(clickLabel)
        controls.addArrangedSubview(NSButton(title: "Record HDR state", target: self, action: #selector(sample)))
        stack.addArrangedSubview(controls)
        window.contentView = stack
        window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        record("ready")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.record("settled") }
    }
    @objc func clicked() { clicks += 1; clickLabel.stringValue = "Clicks received: \(clicks)"; record("click") }
    @objc func sample() { patches.forEach { $0.render() }; record("sample") }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

guard CommandLine.arguments.count == 2 else { fatalError("Usage: HDRFixture events.jsonl") }
let fixture = HDRFixture(events: URL(fileURLWithPath: CommandLine.arguments[1]))
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.delegate = fixture
withExtendedLifetime(fixture) { app.run() }

// Retained tiled layer approach from Deckle; display-frame handling informed by Record.
import AppKit
import Combine
import PaperCore

@MainActor
final class OverlayController {
    private let state: PaperState
    private var windows: [String: PaperOverlayWindow] = [:]
    private var observers: [NSObjectProtocol] = []
    private var changes: AnyCancellable?
    private var refreshPending = false
    private var sessionActive = true
    private var asleep = false
    private let systemOverview = SystemOverviewMonitor()

    init(state: PaperState) { self.state = state }
    func start() {
        systemOverview.start { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        changes = state.objectWillChange.sink { [weak self] in self?.scheduleRefresh() }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refreshDisplays() } })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in
                    guard let self else { return }
                    if name == NSWorkspace.didWakeNotification { self.asleep = false; self.state.record(.wake) }
                    if name == NSWorkspace.sessionDidBecomeActiveNotification { self.sessionActive = true }
                    self.state.refreshClock()
                    self.refreshDisplays()
                }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in
                    if name == NSWorkspace.willSleepNotification { self?.asleep = true; self?.state.record(.sleep) }
                    else { self?.sessionActive = false }
                    self?.refresh()
                }
            })
        }
        refreshDisplays()
    }

    private func scheduleRefresh() {
        guard !refreshPending else { return }
        refreshPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self else { return }
            self.refreshPending = false
            self.refresh()
        }
    }
    private func refreshDisplays() {
        let choices = NSScreen.screens.compactMap { screen -> DisplayChoice? in
            guard let id = screen.paperIdentifier else { return nil }
            return DisplayChoice(id: id, name: screen.localizedName)
        }
        if state.displayChoices != choices { state.displaysChanged(choices); state.record(.displaysChanged) }
        refresh()
    }
    private func refresh() {
        systemOverview.update(enabled: sessionActive && !asleep && NSScreen.screens.contains {
            guard let id = $0.paperIdentifier else { return false }
            return state.reason(for: id) == nil
        })
        var connected = Set<String>()
        for screen in NSScreen.screens {
            guard let id = screen.paperIdentifier else { continue }
            connected.insert(id)
            // Do not create/render a window until this display is actually enabled.
            guard sessionActive, !asleep, state.reason(for: id) == nil else {
                windows.removeValue(forKey: id)?.close()
                continue
            }
            if systemOverview.isActive {
                windows[id]?.orderOut(nil)
                continue
            }
            let window = windows[id] ?? PaperOverlayWindow(screen: screen)
            windows[id] = window
            window.level = NSWindow.Level(rawValue: OverlayPolicy.windowLevel(
                defaultLevel: NSWindow.Level.screenSaver.rawValue, normalLevel: NSWindow.Level.normal.rawValue,
                excludedPanelLevels: state.excludedPanelLevels))
            if window.frame != screen.frame { window.setFrame(screen.frame, display: false) }
            window.apply(texture: state.texture, adjustments: state.adjustments,
                         lamp: state.settings.deskLamp, strip: state.settings.readingStrip)
            window.alphaValue = state.appearance.intensity(for: id)
            window.orderFrontRegardless()
        }
        for id in Set(windows.keys).subtracting(connected) {
            windows.removeValue(forKey: id)?.close()
        }
    }
    func stop() {
        systemOverview.stop()
        changes = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        for window in windows.values { window.close() }
        windows.removeAll()
    }
}

extension NSScreen {
    var paperIdentifier: String? {
        guard let number = deviceDescription[.init("NSScreenNumber")] as? NSNumber else { return nil }
        let displayID = number.uint32Value
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "display-\(displayID)"
    }
}

@MainActor
final class PaperOverlayWindow: NSPanel {
    private let textureView = PaperTextureView()
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    convenience init(screen: NSScreen) {
        self.init(contentRect: NSRect(origin: .zero, size: screen.frame.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false, screen: screen)
        // NSScreen.frame is global; the initializer's origin is screen-relative.
        setFrame(screen.frame, display: false)
        level = .screenSaver
        // The overview monitor orders this window out explicitly. Keep it
        // stationary so AppKit does not delay restoring a transient panel.
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        setAccessibilityElement(false)
        contentView = textureView
    }
    func apply(texture: TexturePreset, adjustments: TextureRenderer.GrainAdjustments,
               lamp: DeskLamp = .init(), strip: ReadingStrip = .init()) {
        textureView.apply(texture: texture, adjustments: adjustments, lamp: lamp, strip: strip)
    }
}

@MainActor
final class PaperTextureView: NSView {
    private var texture: TexturePreset?
    private var adjustments = TextureRenderer.GrainAdjustments.none
    private var backingScale: CGFloat = 0
    private let lampLayer = CAGradientLayer()
    private let stripMask = CAShapeLayer()
    private var lamp = DeskLamp()
    private var strip = ReadingStrip()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        lampLayer.type = .radial
        lampLayer.startPoint = CGPoint(x: 0.5, y: 1)
        lampLayer.endPoint = CGPoint(x: 1, y: 0)
        layer?.addSublayer(lampLayer)
        stripMask.fillRule = .evenOdd
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func apply(texture: TexturePreset, adjustments: TextureRenderer.GrainAdjustments,
               lamp: DeskLamp = .init(), strip: ReadingStrip = .init()) {
        if self.lamp != lamp || self.strip != strip {
            self.lamp = lamp; self.strip = strip
            updateEffects()
        }
        let scale = window?.backingScaleFactor ?? 2
        guard self.texture != texture || self.adjustments != adjustments || scale != backingScale else { return }
        self.texture = texture
        self.adjustments = adjustments
        backingScale = scale
        render()
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let texture else { return }
        apply(texture: texture, adjustments: adjustments, lamp: lamp, strip: strip)
    }
    override func layout() { super.layout(); updateEffects() }
    private func updateEffects() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lampLayer.frame = bounds
        lampLayer.isHidden = !lamp.enabled
        let tint = NSColor(srgbRed: 1, green: 0.95 - lamp.warmth * 0.3, blue: 0.8 - lamp.warmth * 0.6, alpha: lamp.strength)
        lampLayer.colors = [tint.cgColor, tint.withAlphaComponent(0).cgColor]
        if strip.enabled {
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addRect(CGRect(x: bounds.minX, y: bounds.minY + (strip.center - strip.height / 2) * bounds.height,
                                width: bounds.width, height: strip.height * bounds.height))
            stripMask.frame = bounds; stripMask.path = path
            layer?.mask = stripMask
        } else { layer?.mask = nil }
        CATransaction.commit()
    }
    private func render() {
        guard let texture else { return }
        let tile = TextureRenderer.compositeTile(for: texture, adjustments: adjustments, backingScale: backingScale)
        layer?.backgroundColor = NSColor(patternImage: tile).cgColor
    }
}

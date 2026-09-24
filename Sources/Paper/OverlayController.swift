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

    init(state: PaperState) { self.state = state }
    func start() {
        changes = state.objectWillChange.sink { [weak self] in self?.scheduleRefresh() }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refreshDisplays() } })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in
                    guard let self else { return }
                    self.sessionActive = true
                    self.state.refreshClock()
                    self.refreshDisplays()
                }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in Task { @MainActor in
                    self?.sessionActive = false
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
        if state.displayChoices != choices { state.displayChoices = choices }
        refresh()
    }
    private func refresh() {
        var connected = Set<String>()
        for screen in NSScreen.screens {
            guard let id = screen.paperIdentifier else { continue }
            connected.insert(id)
            // Do not create/render a window until this display is actually enabled.
            guard sessionActive, state.reason(for: id) == nil else {
                windows[id]?.orderOut(nil)
                continue
            }
            let window = windows[id] ?? PaperOverlayWindow(screen: screen)
            windows[id] = window
            if window.frame != screen.frame { window.setFrame(screen.frame, display: false) }
            window.apply(texture: state.texture, adjustments: state.adjustments)
            window.alphaValue = state.settings.intensity
            window.orderFrontRegardless()
        }
        for id in Set(windows.keys).subtracting(connected) {
            windows.removeValue(forKey: id)?.orderOut(nil)
        }
    }
    func stop() {
        changes = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        for window in windows.values { window.orderOut(nil) }
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
    func apply(texture: TexturePreset, adjustments: TextureRenderer.GrainAdjustments) {
        textureView.apply(texture: texture, adjustments: adjustments)
    }
}

@MainActor
final class PaperTextureView: NSView {
    private var texture: TexturePreset?
    private var adjustments = TextureRenderer.GrainAdjustments.none
    private var backingScale: CGFloat = 0
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func apply(texture: TexturePreset, adjustments: TextureRenderer.GrainAdjustments) {
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
        apply(texture: texture, adjustments: adjustments)
    }
    private func render() {
        guard let texture else { return }
        let tile = TextureRenderer.compositeTile(for: texture, adjustments: adjustments, backingScale: backingScale)
        layer?.backgroundColor = NSColor(patternImage: tile).cgColor
    }
}

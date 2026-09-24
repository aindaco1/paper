// Adapted from Record's GlobalScreenshotShortcutRegistrar (MIT; see Licenses/Record-MIT.txt).
import Carbon

@MainActor
final class GlobalShortcut {
    private var handler: EventHandlerRef?
    private var reference: EventHotKeyRef?
    var onToggle: (() -> Void)?
    private static let signature: OSType = 0x5050_4552 // PPER

    func setEnabled(_ enabled: Bool) -> OSStatus {
        stop()
        guard enabled else { return noErr }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == GlobalShortcut.signature, identifier.id == 1
            else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { owner.onToggle?() }
            return noErr
        }
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installStatus == noErr else { return installStatus }
        // Include Shift to avoid Deckle's default Option-Command-P shortcut.
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(optionKey | shiftKey | cmdKey),
            EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), 0, &reference)
        if status != noErr { stop() }
        return status
    }

    func stop() {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        reference = nil
        handler = nil
    }
}

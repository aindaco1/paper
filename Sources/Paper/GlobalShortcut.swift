// Adapted from Record's GlobalScreenshotShortcutRegistrar (MIT; see Licenses/Record-MIT.txt).
import Carbon
import PaperCore

@MainActor
final class GlobalShortcut {
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    var onAction: ((ShortcutAction) -> Void)?
    private static let signature: OSType = 0x5050_4552 // PPER
    private static let keys: [String: UInt32] = ["A":0,"S":1,"D":2,"F":3,"H":4,"G":5,"Z":6,"X":7,"C":8,"V":9,"B":11,
        "Q":12,"W":13,"E":14,"R":15,"Y":16,"T":17,"O":31,"U":32,"I":34,"P":35,"L":37,"J":38,"K":40,"N":45,"M":46]

    /// Registers independent commands. One conflicting command never disables the others.
    func configure(enabled: Bool, settings: ShortcutSettings) -> String? {
        stop()
        guard enabled else { return nil }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == GlobalShortcut.signature,
                  identifier.id > 0, identifier.id <= ShortcutAction.allCases.count else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { owner.onAction?(ShortcutAction.allCases[Int(identifier.id) - 1]) }
            return noErr
        }
        let status = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return "Shortcuts could not start (\(status)). Use the menu bar." }
        var seen = Set<ShortcutBinding>()
        var errors: [String] = []
        for (index, action) in ShortcutAction.allCases.enumerated() {
            guard let binding = settings[action] else { continue }
            guard binding.isValid, let code = Self.keys[binding.key] else {
                errors.append("\(action.title): choose a letter with Command or Control."); continue
            }
            guard seen.insert(binding).inserted else {
                errors.append("\(action.title): \(binding.title) is already assigned in Paper."); continue
            }
            let modifiers = (binding.command ? cmdKey : 0) | (binding.option ? optionKey : 0)
                | (binding.control ? controlKey : 0) | (binding.shift ? shiftKey : 0)
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(code, UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: UInt32(index + 1)),
                                            GetApplicationEventTarget(), 0, &reference)
            if result == noErr, let reference { references.append(reference) }
            else { errors.append("\(action.title): \(binding.title) is unavailable (\(result)). Choose another combination.") }
        }
        return errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
    func stop() {
        for reference in references { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
        references.removeAll(); handler = nil
    }
}

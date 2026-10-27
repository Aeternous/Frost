import Carbon.HIToolbox

/// System-wide ⌃⌥⌘ + key shortcuts that work from any app. Carbon hot keys need no extra permission.
final class Hotkeys {
    private var actions: [UInt32: () -> Void] = [:]

    init() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let hotkeys = Unmanaged<Hotkeys>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async { hotkeys.actions[id.id]?() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Registers ⌃⌥⌘ + `keyCode`. Returns false if another app already uses that combination.
    @discardableResult
    func register(_ keyCode: Int, action: @escaping () -> Void) -> Bool {
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(controlKey | optionKey | cmdKey),
                                         EventHotKeyID(signature: OSType(0x4652_5354), id: id),  // "FRST"
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else { return false }
        actions[id] = action
        return true
    }
}

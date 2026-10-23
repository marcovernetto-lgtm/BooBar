import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let key: UInt32
    let modifiers: UInt32
    let label: String
    static func capture(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) || flags.contains(.control),
              !flags.contains(.function), let characters = event.charactersIgnoringModifiers,
              characters.count == 1, characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        if flags.intersection([.command, .control, .option, .shift]) == .command && [12, 13, 43].contains(event.keyCode) { return nil }
        var modifiers: UInt32 = 0
        var label = ""
        for (flag, carbon, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"),
            (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] where flags.contains(flag) {
            modifiers |= UInt32(carbon); label += symbol
        }
        return Shortcut(key: UInt32(event.keyCode), modifiers: modifiers, label: label + characters.uppercased())
    }
}

@MainActor
final class GlobalShortcut {
    private var hotkey: EventHotKeyRef?
    private var registered: Shortcut?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    private func installHandler() {
        guard handler == nil else { return }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue().action?() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ shortcut: Shortcut?) -> Bool {
        if let shortcut, shortcut == registered, hotkey != nil { return true }
        guard let shortcut else {
            if let hotkey { UnregisterEventHotKey(hotkey) }
            hotkey = nil; registered = nil; return true
        }
        installHandler()
        guard handler != nil else { return false }
        var replacement: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.key, shortcut.modifiers,
            EventHotKeyID(signature: 0x426f6f42, id: 1), GetApplicationEventTarget(), 0, &replacement)
        guard status == noErr else { return false }
        if let hotkey { UnregisterEventHotKey(hotkey) }
        hotkey = replacement; registered = shortcut
        return true
    }
    isolated deinit { stop() }
    func stop() {
        if let hotkey { UnregisterEventHotKey(hotkey) }; hotkey = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil
    }
}

struct BarInteraction {
    var pinned = false
    var lastPresence = Date()
    mutating func shouldCollapse(now: Date, inBar: Bool, pressed: Bool, popup: Bool) -> Bool {
        if pinned || inBar || pressed || popup { lastPresence = now; return false }
        return now.timeIntervalSince(lastPresence) > 1.5
    }
    static func interval(expanded: Bool, nearBar: Bool) -> TimeInterval { expanded || nearBar ? 0.1 : 0.5 }
    static func opensSettings(login: Bool, background: Bool, welcomed: Bool, authorized: Bool) -> Bool {
        !login && !background && (!welcomed || !authorized)
    }
}

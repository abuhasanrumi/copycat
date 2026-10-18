import Carbon

final class HotKey {
    private var ref: EventHotKeyRef?
    private static var handler: (() -> Void)?

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotKey.handler = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.handler?()
            return noErr
        }, 1, &spec, nil, nil)
        RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: OSType(0x5043_4C50), id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }
}

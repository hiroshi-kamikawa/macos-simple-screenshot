import AppKit
import Carbon

final class HotKeyManager {
    private var refs: [EventHotKeyRef?] = []
    private let handler: (CaptureAction) -> Void
    private var eventHandler: EventHandlerRef?

    init(handler: @escaping (CaptureAction) -> Void) { self.handler = handler }

    func registerDefaults() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout.size(ofValue: id), nil, &id)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            if let action = CaptureAction(rawValue: id.id) { manager.handler(action) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        let keys: [(CaptureAction, UInt32)] = [
            (.screenImage, UInt32(kVK_ANSI_1)), (.areaImage, UInt32(kVK_ANSI_2)), (.windowImage, UInt32(kVK_ANSI_3)),
            (.screenVideo, UInt32(kVK_ANSI_4)), (.areaVideo, UInt32(kVK_ANSI_5)), (.windowVideo, UInt32(kVK_ANSI_6))
        ]
        for (action, key) in keys {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x4C534854), id: action.rawValue)
            RegisterEventHotKey(key, UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &ref)
            refs.append(ref)
        }
    }

    deinit {
        refs.compactMap { $0 }.forEach { _ = UnregisterEventHotKey($0) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}

import Carbon
import Foundation

@MainActor
public final class HotKeyMonitor {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var nextID: UInt32 = 1

    public init() {}

    isolated deinit {
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    public func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping @MainActor () -> Void) {
        ensureEventHandlerInstalled()
        let id = nextID
        nextID += 1
        handlers[id] = handler

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 0x4E54_4348, id: id) // 'NTCH'
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if let ref { hotKeyRefs.append(ref) }
    }

    public func registerOptionCommandV(_ handler: @escaping @MainActor () -> Void) {
        register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | cmdKey), handler: handler)
    }

    public func registerOptionSpace(_ handler: @escaping @MainActor () -> Void) {
        register(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), handler: handler)
    }

    public func registerOptionA(_ handler: @escaping @MainActor () -> Void) {
        register(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(optionKey), handler: handler)
    }

    public func registerOptionCommandL(_ handler: @escaping @MainActor () -> Void) {
        register(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(optionKey | cmdKey), handler: handler)
    }

    private func ensureEventHandlerInstalled() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return noErr }
                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    monitor.handlers[hotKeyID.id]?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }
}

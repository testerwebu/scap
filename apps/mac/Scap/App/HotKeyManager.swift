import Carbon.HIToolbox
import Foundation

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private let signature = OSType("SPKT".fourCharCode)
    private let hotKeyID = UInt32(1)
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    private init() {}

    func configure(shortcut: KeyboardShortcut, action: @escaping () -> Void) {
        self.action = action
        register(shortcut)
    }

    func update(shortcut: KeyboardShortcut) {
        register(shortcut)
    }

    private func register(_ shortcut: KeyboardShortcut) {
        unregisterHotKey()
        installEventHandlerIfNeeded()

        let id = EventHotKeyID(signature: signature, id: hotKeyID)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else {
                    return noErr
                }

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

                if status == noErr,
                   hotKeyID.signature == OSType("SPKT".fourCharCode),
                   hotKeyID.id == 1 {
                    Task { @MainActor in
                        HotKeyManager.shared.action?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRef = nil
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf8.reduce(0) { result, character in
            (result << 8) + FourCharCode(character)
        }
    }
}

import AppKit
import Carbon.HIToolbox
import Foundation

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let keyDisplay: String

    static let defaultCapture = KeyboardShortcut(
        keyCode: UInt32(kVK_ANSI_S),
        carbonModifiers: UInt32(controlKey | optionKey),
        keyDisplay: "S"
    )

    var displayText: String {
        "\(modifierDisplay)\(keyDisplay)"
    }

    var hasModifier: Bool {
        carbonModifiers != 0
    }

    private var modifierDisplay: String {
        var symbols = ""

        if carbonModifiers & UInt32(controlKey) != 0 {
            symbols += "⌃"
        }

        if carbonModifiers & UInt32(optionKey) != 0 {
            symbols += "⌥"
        }

        if carbonModifiers & UInt32(shiftKey) != 0 {
            symbols += "⇧"
        }

        if carbonModifiers & UInt32(cmdKey) != 0 {
            symbols += "⌘"
        }

        return symbols
    }

    static func from(event: NSEvent) -> KeyboardShortcut? {
        guard event.type == .keyDown else {
            return nil
        }

        let modifiers = event.modifierFlags.carbonHotKeyModifiers

        guard modifiers != 0 else {
            return nil
        }

        return KeyboardShortcut(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers,
            keyDisplay: event.hotKeyDisplayString
        )
    }
}

private extension NSEvent.ModifierFlags {
    var carbonHotKeyModifiers: UInt32 {
        var modifiers: UInt32 = 0

        if contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        if contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return modifiers
    }
}

private extension NSEvent {
    var hotKeyDisplayString: String {
        switch Int(keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Escape:
            return "Esc"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Forward Delete"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_UpArrow:
            return "↑"
        case kVK_DownArrow:
            return "↓"
        default:
            let characters = charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let characters, !characters.isEmpty {
                return characters.uppercased()
            }

            return "Key \(keyCode)"
        }
    }
}

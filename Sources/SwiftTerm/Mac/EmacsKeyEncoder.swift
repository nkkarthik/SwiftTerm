#if os(macOS)
import AppKit

/// Encodes key combinations that legacy terminal input cannot represent
/// faithfully, using sequences understood by Emacs's xterm input decoder.
public enum EmacsKeyEncoder {
    public static let superPrefix: [UInt8] = [0x18, 0x40, 0x73]

    private static let backwardDeleteKeyCode: UInt16 = 51
    private static let appCommandKeys: Set<String> = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", ",", "c", "v", "h", "n", "q", "w",
    ]
    private static let zoomKeys: Set<String> = ["=", "+", "-", "0"]

    public static func bytes(for event: NSEvent, emacsTarget: Bool = true) -> [UInt8]? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if emacsTarget, let bytes = modifiedBackspaceBytes(for: event, flags: flags) {
            return bytes
        }
        if let bytes = controlMetaLetterBytes(for: event, flags: flags) {
            return bytes
        }
        if emacsTarget, let bytes = controlOtherKeyBytes(for: event, flags: flags) {
            return bytes
        }

        guard emacsTarget,
              flags.contains(.command),
              !flags.contains(.control),
              !flags.contains(.option),
              let characters = event.charactersIgnoringModifiers,
              isPrintable(characters),
              !zoomKeys.contains(characters),
              flags.contains(.shift) || !appCommandKeys.contains(characters.lowercased())
        else { return nil }
        return superPrefix + Array(characters.utf8)
    }

    private static func modifiedBackspaceBytes(
        for event: NSEvent, flags: NSEvent.ModifierFlags
    ) -> [UInt8]? {
        guard event.keyCode == backwardDeleteKeyCode,
              flags.contains(.control),
              !flags.contains(.command)
        else { return nil }
        let modifier =
            1 + (flags.contains(.shift) ? 1 : 0) + (flags.contains(.option) ? 2 : 0) + 4
        return Array("\u{1b}[27;\(modifier);127~".utf8)
    }

    private static func controlMetaLetterBytes(
        for event: NSEvent, flags: NSEvent.ModifierFlags
    ) -> [UInt8]? {
        guard flags.contains(.control), flags.contains(.option), !flags.contains(.command),
              let characters = event.charactersIgnoringModifiers,
              isPlainLetter(characters),
              let scalar = characters.uppercased().unicodeScalars.first,
              (0x41...0x5a).contains(scalar.value)
        else { return nil }
        return [0x1b, UInt8(scalar.value & 0x1f)]
    }

    private static func controlOtherKeyBytes(
        for event: NSEvent, flags: NSEvent.ModifierFlags
    ) -> [UInt8]? {
        guard flags.contains(.control),
              !flags.contains(.command),
              let characters = event.charactersIgnoringModifiers,
              isPrintable(characters),
              !isPlainLetter(characters)
        else { return nil }
        let modifier =
            1 + (flags.contains(.shift) ? 1 : 0) + (flags.contains(.option) ? 2 : 0) + 4
        let keycode = characters.unicodeScalars.first!.value
        return Array("\u{1b}[27;\(modifier);\(keycode)~".utf8)
    }

    private static func isPlainLetter(_ characters: String) -> Bool {
        characters.count == 1 && characters.unicodeScalars.first!.properties.isAlphabetic
    }

    private static func isPrintable(_ characters: String) -> Bool {
        guard characters.count == 1 else { return false }
        return characters.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            return value >= 0x20 && value != 0x7f && !(0xf700...0xf8ff).contains(value)
        }
    }
}
#endif

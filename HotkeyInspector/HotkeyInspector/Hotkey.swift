import Foundation
import CoreGraphics

struct ShortcutModifiers: OptionSet, Hashable, Sendable {
    let rawValue: Int
    static let control = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let shift = Self(rawValue: 1 << 2)
    static let command = Self(rawValue: 1 << 3)

    // AX assumes Command unless the NoCommand bit is set.
    static func accessibility(_ mask: Int) -> Self {
        var result: Self = []
        if mask & 1 != 0 { result.insert(.shift) }
        if mask & 2 != 0 { result.insert(.option) }
        if mask & 4 != 0 { result.insert(.control) }
        if mask & 8 == 0 { result.insert(.command) }
        return result
    }

    static func event(_ flags: CGEventFlags) -> Self {
        var result: Self = []
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        return result
    }

    var symbols: String {
        [(Self.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }.map(\.1).joined()
    }
}

struct KeyCombination: Hashable, Sendable {
    let character: String?
    let keyCode: Int?
    let glyph: Int?
    let modifiers: ShortcutModifiers?

    init?(character: String?, keyCode: Int?, glyph: Int?, modifierMask: Int?) {
        let text = character.flatMap { $0.isEmpty ? nil : $0 }
        let code = keyCode.flatMap { (0...127).contains($0) ? $0 : nil }
        let symbol = glyph.flatMap { $0 > 0 ? $0 : nil }
        guard text != nil || code != nil || symbol != nil else { return nil }
        self.character = text
        self.keyCode = code
        self.glyph = symbol
        self.modifiers = modifierMask.map(ShortcutModifiers.accessibility)
    }

    var display: String {
        let key: String
        if let character { key = KeyNames.character(character) }
        else if let keyCode { key = KeyNames.special[keyCode] ?? "Код \(keyCode)" }
        else if let glyph { key = KeyNames.glyph(glyph) }
        else { key = "?" }
        return (modifiers?.symbols ?? "[модификаторы неизвестны] ") + key
    }

    // Missing data cannot justify a conflict; text is not a physical key ID.
    var physicalIdentity: String? {
        guard let keyCode, let modifiers else { return nil }
        return "\(keyCode):\(modifiers.rawValue)"
    }
}

enum KeyNames {
    static let functionKeys: [Int: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20"
    ]
    static let special: [Int: String] = functionKeys.merging([
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc", 76: "⌤",
        115: "Home", 116: "Page Up", 117: "⌦", 119: "End", 121: "Page Down",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ], uniquingKeysWith: { first, _ in first })

    static func character(_ text: String) -> String {
        let controls = ["\r": "↩", "\n": "↩", "\t": "⇥", " ": "Space",
                        "\u{1B}": "Esc", "\u{08}": "⌫", "\u{7F}": "⌫",
                        "\u{F700}": "↑", "\u{F701}": "↓", "\u{F702}": "←", "\u{F703}": "→"]
        if let label = controls[text] { return label }
        if text.unicodeScalars.count == 1, let scalar = text.unicodeScalars.first,
           (0xF704...0xF726).contains(scalar.value) {
            return "F\(scalar.value - 0xF704 + 1)"
        }
        return text.uppercased()
    }

    static func glyph(_ value: Int) -> String {
        if (0x6F...0x7A).contains(value) { return "F\(value - 0x6F + 1)" }
        if (0x87...0x89).contains(value) { return "F\(value - 0x87 + 13)" }
        if (0x8F...0x92).contains(value) { return "F\(value - 0x8F + 16)" }
        return [2: "⇥", 3: "⇤", 11: "↩", 13: "⌤", 23: "⌫", 27: "Esc",
                98: "Page Up", 100: "←", 101: "→", 104: "↑", 106: "↓",
                107: "Page Down"][value] ?? "Глиф \(value)"
    }
}

struct ApplicationInfo: Identifiable, Hashable, Sendable {
    let id: Int32
    let name: String
    let bundleIdentifier: String?
}

struct Hotkey: Identifiable, Sendable {
    let id: String
    let application: ApplicationInfo
    let action: String
    let menuPath: [String]
    let combination: KeyCombination
    let isEnabled: Bool?
    var path: String { menuPath.joined(separator: " → ") }

    static func conflictingIDs(in items: [Hotkey]) -> Set<String> {
        var groups: [String: [String]] = [:]
        for item in items where item.isEnabled == true {
            guard let key = item.combination.physicalIdentity else { continue }
            groups["\(item.application.id):\(key)", default: []].append(item.id)
        }
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0 })
    }
}

enum MonitorPolicy {
    // Shift/Option alone may produce text. Fn alone is not a function key.
    static func allows(keyCode: Int, flags: CGEventFlags, isRepeat: Bool) -> Bool {
        guard !isRepeat, (0...127).contains(keyCode) else { return false }
        return KeyNames.functionKeys[keyCode] != nil ||
            flags.contains(.maskCommand) || flags.contains(.maskControl)
    }
}

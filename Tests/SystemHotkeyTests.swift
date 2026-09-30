import Foundation
import CoreGraphics

enum SystemHotkeyTests {
    static func run(check: (Bool, String) -> Void) throws {
        // Synthetic settings, including a remap that differs from the usual shortcut.
        let plist: [String: Any] = ["AppleSymbolicHotKeys": [
            "64": ["enabled": true, "value": ["type": "standard", "parameters": [102, 3, 1048576]]],
            "28": ["enabled": false, "value": ["type": "standard", "parameters": [51, 20, 1179648]]],
            "7": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 120, 262144]]],
            "999": ["enabled": true],
            "1000": ["enabled": true, "value": ["type": "standard", "parameters": [65535, 65535, 0]]],
            "1001": ["enabled": true, "value": ["type": "standard", "parameters": [97, 0, 8388608]]],
            "1002": ["enabled": true, "value": ["type": "other", "parameters": [97, 0, 1048576]]],
            "1003": ["enabled": true, "value": ["type": "standard", "parameters": [97, 0]]],
            "1004": ["enabled": true, "value": ["type": "standard", "parameters": [97, 0, -1]]],
            "1005": ["enabled": "yes", "value": ["type": "standard", "parameters": [32, 49, 0]]],
            "1006": ["enabled": true, "value": ["type": "standard", "parameters": [97, true, 0]]]
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
        let rows = try SystemHotkeyReader.decode(data: data)
        func row(_ id: String) -> SystemHotkeySetting { rows.first { $0.id == id }! }
        check(rows.count == 11, "Preserve settings with missing/unsupported combinations")
        check(rows.first?.id == "7", "Sort IDs numerically")
        check(row("64").shortcut == "⌘F", "Use actual Spotlight remap, never a default")
        check(row("28").shortcut == "⇧⌘3" && row("28").isEnabled == false, "Retain disabled assignment")
        check(row("7").shortcut == "⌃F2", "CG flags are not AX flags; sentinel falls back to function key")
        check(row("999").shortcut == nil && row("999").isEnabled == true, "Missing value does not imply disabled")
        check(row("999").action == "Системная команда #999", "Unknown ID has no invented action")
        check(row("1000").shortcut == nil, "65535 never becomes a physical key or character")
        check(row("1001").shortcut == "fn A", "Preserve Fn modifier")
        check(row("1002").shortcut == nil, "Unsupported format does not guess")
        check(row("1003").shortcut == nil, "Reject incomplete parameters")
        check(row("1004").shortcut == nil, "Reject negative event flags")
        check(row("1005").isEnabled == nil, "Unknown enabled state is not coerced")
        check(row("1005").shortcut == "Space", "Zero CG mask does not imply Command")
        check(row("1006").shortcut == nil, "A boolean is not a virtual key code")
        check(row("64").matches(query: "spotlight", enabledOnly: true), "Search reference action label")
        check(row("64").matches(query: "⌘F", enabledOnly: true), "Search actual combination")
        check(row("999").matches(query: "999", enabledOnly: false), "Search unknown ID")
        check(!row("28").matches(query: "", enabledOnly: true), "Filter disabled setting")
        check(!row("1005").matches(query: "", enabledOnly: true), "Unknown enabled state excluded from enabled-only filter")
        let empty = try PropertyListSerialization.data(fromPropertyList: ["AppleSymbolicHotKeys": [:]], format: .xml, options: 0)
        check(try SystemHotkeyReader.decode(data: empty).isEmpty, "Empty preferences never produce defaults")
        do {
            _ = try SystemHotkeyReader.decode(data: Data("invalid".utf8))
            check(false, "Invalid plist must fail")
        } catch { check(true, "Invalid plist reports error") }
        let wrongRoot = try PropertyListSerialization.data(fromPropertyList: ["Other": 1], format: .xml, options: 0)
        do {
            _ = try SystemHotkeyReader.decode(data: wrongRoot)
            check(false, "Missing dictionary must fail")
        } catch { check(true, "Missing dictionary reports error") }
    }
}

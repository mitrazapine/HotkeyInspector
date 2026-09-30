import Foundation
import CoreGraphics

@main
struct HotkeyTests {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1
            guard condition() else { fatalError("FAIL: \(message)") }
        }

        check(ShortcutModifiers.accessibility(0) == .command, "AX defaults to Command")
        check(ShortcutModifiers.accessibility(8).isEmpty, "NoCommand removes implicit Command")
        check(ShortcutModifiers.accessibility(7) == [.command, .shift, .option, .control], "AX modifier bits")
        check(ShortcutModifiers.accessibility(9) == .shift, "Shift without Command")
        check(ShortcutModifiers.event([.maskCommand, .maskShift, .maskAlphaShift]) == [.command, .shift], "Caps Lock is not a shortcut modifier")

        let commandA = KeyCombination(character: "a", keyCode: 0, glyph: nil, modifierMask: 0)!
        check(commandA.display == "⌘A", "Menu character display")
        check(commandA.keyCode == 0, "Virtual key zero is valid, not absent")
        check(commandA.physicalIdentity == "0:8", "Identity uses physical key and normalized flags")
        check(KeyCombination(character: "", keyCode: nil, glyph: 0, modifierMask: 0) == nil, "Empty AX attributes are not a shortcut")
        check(KeyCombination(character: nil, keyCode: -1, glyph: nil, modifierMask: 0) == nil, "Invalid key code is rejected")
        check(KeyCombination(character: "q", keyCode: nil, glyph: nil, modifierMask: nil)!.physicalIdentity == nil, "Unknown modifiers/key cannot imply a conflict")
        check(KeyCombination(character: nil, keyCode: nil, glyph: 111, modifierMask: 8)!.display == "F1", "Glyph fallback")
        check(KeyCombination(character: " ", keyCode: 49, glyph: nil, modifierMask: 0)!.display == "⌘Space", "Space is a valid menu key")
        check(KeyNames.character("\u{F704}") == "F1", "Unicode function key")
        check(KeyNames.character("\t") == "⇥", "Tab character")

        // Exhaustively reject every ordinary key under text-producing modifiers.
        for code in 0...127 {
            for flags: CGEventFlags in [[], .maskShift, .maskAlternate, [.maskAlternate, .maskShift], .maskAlphaShift, .maskSecondaryFn] {
                check(MonitorPolicy.allows(keyCode: code, flags: flags, isRepeat: false) == (KeyNames.functionKeys[code] != nil), "Text privacy: code \(code), flags \(flags.rawValue)")
            }
            check(!MonitorPolicy.allows(keyCode: code, flags: .maskCommand, isRepeat: true), "No repeats")
        }
        check(MonitorPolicy.allows(keyCode: 0, flags: .maskCommand, isRepeat: false), "Command shortcut")
        check(MonitorPolicy.allows(keyCode: 8, flags: .maskControl, isRepeat: false), "Control shortcut")
        check(!MonitorPolicy.allows(keyCode: 999, flags: .maskCommand, isRepeat: false), "Invalid event key")

        let app = ApplicationInfo(id: 123, name: "Fixture", bundleIdentifier: "test.fixture")
        let other = ApplicationInfo(id: 456, name: "Other", bundleIdentifier: "test.other")
        func item(_ id: String, enabled: Bool? = true, application: ApplicationInfo = app,
                  combination: KeyCombination = commandA) -> Hotkey {
            Hotkey(id: id, application: application, action: id, menuPath: ["File", id],
                   combination: combination, isEnabled: enabled)
        }
        check(Hotkey.conflictingIDs(in: [item("a"), item("b")]) == ["a", "b"], "Two enabled commands in one app")
        check(Hotkey.conflictingIDs(in: [item("a"), item("b", enabled: false)]).isEmpty, "Disabled command is not conflict")
        check(Hotkey.conflictingIDs(in: [item("a"), item("b", enabled: nil)]).isEmpty, "Unknown availability is not conflict")
        check(Hotkey.conflictingIDs(in: [item("a"), item("b", application: other)]).isEmpty, "Same shortcut in different apps is normal")
        let shifted = KeyCombination(character: "a", keyCode: 0, glyph: nil, modifierMask: 1)!
        check(Hotkey.conflictingIDs(in: [item("a"), item("b", combination: shifted)]).isEmpty, "Different modifiers")
        let textOnly = KeyCombination(character: "a", keyCode: nil, glyph: nil, modifierMask: 0)!
        check(Hotkey.conflictingIDs(in: [item("a", combination: textOnly), item("b", combination: textOnly)]).isEmpty, "Text-only menu entries do not claim physical conflicts")
        let copyItems = [item("b", enabled: false), item("a", enabled: nil)]
        check(MenuSelectionCopy.text(items: copyItems, selectedIDs: [], conflictIDs: []) == nil, "No selection disables row copy")
        check(MenuSelectionCopy.text(items: copyItems, selectedIDs: ["missing"], conflictIDs: []) == nil, "Stale IDs cannot copy another snapshot")
        check(MenuSelectionCopy.text(items: copyItems, selectedIDs: ["a", "b"], conflictIDs: []) == "⌘A\tb\tFile → b\tFixture\tНедоступно\n⌘A\ta\tFile → a\tFixture\tНеизвестно", "Copied rows retain visible order and availability")
        check(MenuSelectionCopy.text(items: [item("a")], selectedIDs: ["a", "b"], conflictIDs: []) == "⌘A\ta\tFile → a\tFixture\tДоступно", "Filtered-out rows are excluded from copy")
        check(MenuSelectionCopy.text(items: [item("a")], selectedIDs: ["a"], conflictIDs: ["a"]) == "⌘A\ta\tFile → a\tFixture\tСовпадение", "Copy preserves the displayed conflict status")
        let multilineItem = Hotkey(id: "multiline", application: app, action: "First\tSecond\r\nThird",
                                   menuPath: ["File", "First\nSecond"], combination: commandA, isEnabled: true)
        check(MenuSelectionCopy.text(items: [multilineItem], selectedIDs: ["multiline"], conflictIDs: []) == "⌘A\tFirst Second Third\tFile → First Second\tFixture\tДоступно", "Menu control characters cannot create extra clipboard rows or columns")
        try SystemHotkeyTests.run { check($0, $1) }
        print("PASS: \(checks) checks — AX decoding, privacy filter, conflict semantics, system settings")
    }
}

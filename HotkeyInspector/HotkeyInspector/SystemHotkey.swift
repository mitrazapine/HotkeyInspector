import Foundation
import CoreGraphics
import CoreFoundation

struct SystemHotkeySetting: Identifiable, Sendable {
    let id: String
    let isEnabled: Bool?
    let shortcut: String?
    let detail: String?
    // Reference labels only. Never use this table to supply a key or enabled state.
    // Symbolic IDs are undocumented; retain the ID in the UI for comparison.
    private static let actionLabels: [String: String] = [
        "7": "Фокус на строке меню", "8": "Фокус на Dock",
        "9": "Фокус на следующем окне", "10": "Фокус на панели инструментов",
        "11": "Фокус на плавающем окне", "12": "Изменить режим доступа с клавиатуры",
        "13": "Изменить навигацию клавишей Tab", "27": "Следующее окно приложения",
        "28": "Снимок экрана в файл", "29": "Снимок экрана в буфер обмена",
        "30": "Снимок области в файл", "31": "Снимок области в буфер обмена",
        "32": "Mission Control", "33": "Окна приложения", "36": "Показать рабочий стол",
        "52": "Скрыть или показать Dock", "53": "Уменьшить яркость экрана",
        "54": "Увеличить яркость экрана", "57": "Фокус на меню статуса",
        "60": "Предыдущий источник ввода", "61": "Следующий источник ввода",
        "64": "Spotlight", "65": "Окно поиска Finder",
        "79": "Предыдущее пространство", "81": "Следующее пространство",
        "118": "Перейти на рабочий стол 1", "119": "Перейти на рабочий стол 2",
        "120": "Перейти на рабочий стол 3", "121": "Перейти на рабочий стол 4",
        "122": "Перейти на рабочий стол 5", "123": "Перейти на рабочий стол 6",
        "124": "Перейти на рабочий стол 7", "125": "Перейти на рабочий стол 8",
        "126": "Перейти на рабочий стол 9", "184": "Панель снимков и записи экрана"
    ]

    var action: String { Self.actionLabels[id] ?? "Системная команда #\(id)" }
    var hasReferenceLabel: Bool { Self.actionLabels[id] != nil }
    var status: String {
        switch isEnabled {
        case true?: "Включено"
        case false?: "Выключено"
        case nil: "Неизвестно"
        }
    }

    func matches(query: String, enabledOnly: Bool) -> Bool {
        guard !enabledOnly || isEnabled == true else { return false }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty || [id, action, shortcut ?? "", status]
            .contains { $0.localizedStandardContains(term) }
    }
}

struct SystemHotkeySnapshot: Sendable {
    let items: [SystemHotkeySetting]
    let date: Date
    let sourceURL: URL
}

enum SystemHotkeyReader {
    static var preferencesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")
    }

    // Read only. No defaults command, preferences synchronization or settings writes.
    static func read() throws -> SystemHotkeySnapshot {
        let url = preferencesURL
        let items = try decode(data: Data(contentsOf: url))
        return SystemHotkeySnapshot(items: items, date: Date(), sourceURL: url)
    }

    static func decode(data: Data) throws -> [SystemHotkeySetting] {
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let root = plist as? [String: Any],
              let settings = root["AppleSymbolicHotKeys"] as? [String: Any] else {
            throw ReadError.missingSettings
        }
        return settings.map { id, raw in
            guard let entry = raw as? [String: Any] else {
                return SystemHotkeySetting(id: id, isEnabled: nil, shortcut: nil,
                                           detail: "Неизвестный формат записи")
            }
            let enabled = boolean(entry["enabled"])
            guard let value = entry["value"] as? [String: Any] else {
                return SystemHotkeySetting(id: id, isEnabled: enabled, shortcut: nil,
                                           detail: "Сочетание не сохранено в этом источнике")
            }
            guard value["type"] as? String == "standard",
                  let parameters = value["parameters"] as? [Any], parameters.count == 3,
                  let character = integer(parameters[0]), (0...65535).contains(character),
                  let code = integer(parameters[1]), (0...65535).contains(code),
                  let mask = integer(parameters[2]), mask >= 0, UInt64(mask) <= UInt32.max else {
                return SystemHotkeySetting(id: id, isEnabled: enabled, shortcut: nil,
                                           detail: "Неизвестный формат или некорректные параметры")
            }
            let shortcut = display(character: character, code: code, mask: UInt64(mask))
            return SystemHotkeySetting(id: id, isEnabled: enabled, shortcut: shortcut,
                                       detail: shortcut == nil ? "Нет данных о клавише в сохранённой записи" : nil)
        }.sorted {
            let first = Int($0.id) ?? Int.max
            let second = Int($1.id) ?? Int.max
            return first == second ? $0.id < $1.id : first < second
        }
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func integer(_ value: Any) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: number.doubleValue)
    }

    private static func display(character: Int, code: Int, mask: UInt64) -> String? {
        let key: String
        if character != 65535, let scalar = UnicodeScalar(character),
           character >= 32, character != 127 {
            key = KeyNames.character(String(scalar))
        } else if (0...127).contains(code) {
            key = KeyNames.special[code] ?? "Код \(code)"
        } else {
            return nil
        }
        // These are CGEventFlags, not AXMenuItemCmdModifiers (Command is not implicit).
        let flags = CGEventFlags(rawValue: mask)
        var prefix = ""
        if flags.contains(.maskSecondaryFn) { prefix += "fn " }
        if flags.contains(.maskAlphaShift) { prefix += "Caps " }
        if flags.contains(.maskNumericPad) { prefix += "Num " }
        let known: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift,
                                   .maskSecondaryFn, .maskAlphaShift, .maskNumericPad]
        let extra = mask & ~known.rawValue
        let suffix = extra == 0 ? "" : " [флаги 0x\(String(extra, radix: 16))]"
        return prefix + ShortcutModifiers.event(flags).symbols + key + suffix
    }

    enum ReadError: LocalizedError {
        case missingSettings
        var errorDescription: String? {
            "В файле настроек нет словаря AppleSymbolicHotKeys. Стандартные сочетания автоматически не подставляются."
        }
    }
}

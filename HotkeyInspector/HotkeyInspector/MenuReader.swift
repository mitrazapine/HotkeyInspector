import ApplicationServices
import Foundation

struct MenuScanResult: Sendable {
    let hotkeys: [Hotkey]
    let visitedCount: Int
    let warnings: [String]
    let date: Date
}

enum MenuScanError: LocalizedError {
    case noPermission
    case menuUnavailable(Int32)
    var errorDescription: String? {
        switch self {
        case .noPermission: return "Разрешите Accessibility для HotkeyInspector в настройках macOS."
        case .menuUnavailable(let code):
            return "Меню недоступно (AX \(code)). Приложение могло завершиться или не предоставлять меню через Accessibility."
        }
    }
}

// AX objects stay on the scanning task. Only value models cross back to UI.
enum MenuReader {
    static func scan(_ application: ApplicationInfo) throws -> MenuScanResult {
        guard AXIsProcessTrusted() else { throw MenuScanError.noPermission }
        let root = AXUIElementCreateApplication(application.id)
        AXUIElementSetMessagingTimeout(root, 0.15)
        var menuValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(root, kAXMenuBarAttribute as CFString, &menuValue)
        guard error == .success, let menuValue,
              CFGetTypeID(menuValue) == AXUIElementGetTypeID() else {
            throw MenuScanError.menuUnavailable(error.rawValue)
        }
        let menu = unsafeBitCast(menuValue, to: AXUIElement.self)
        var reader = Traversal(application: application)
        reader.walk(menu, path: [], indexPath: "menu", depth: 0)
        return MenuScanResult(hotkeys: reader.hotkeys, visitedCount: reader.visited,
                              warnings: reader.warnings.sorted(), date: Date())
    }

    private struct Traversal {
        let application: ApplicationInfo
        let deadline = Date().addingTimeInterval(8)
        var visited = 0
        var hotkeys: [Hotkey] = []
        var warnings: Set<String> = []

        mutating func canContinue() -> Bool {
            if Task.isCancelled { return false }
            if Date() >= deadline || visited >= 4000 {
                warnings.insert("Обход ограничен временем или числом элементов. Результат может быть неполным.")
                return false
            }
            return true
        }

        mutating func read(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
            guard canContinue() else { return nil }
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(element, key as CFString, &value)
            if error == .cannotComplete || error == .invalidUIElement || error == .apiDisabled {
                warnings.insert("Часть меню не ответила или изменилась во время чтения (AX \(error.rawValue)).")
            }
            return error == .success ? value : nil
        }

        mutating func walk(_ element: AXUIElement, path: [String], indexPath: String, depth: Int) {
            guard canContinue() else { return }
            guard depth < 25 else {
                warnings.insert("Достигнут предел вложенности меню; часть пунктов пропущена.")
                return
            }
            visited += 1
            AXUIElementSetMessagingTimeout(element, 0.15)
            guard let role = read(element, kAXRoleAttribute) as? String else { return }
            // Never traverse windows, text fields, web content or arbitrary AX values.
            guard [kAXMenuBarRole, kAXMenuRole, kAXMenuBarItemRole, kAXMenuItemRole].contains(role) else { return }
            let title = (read(element, kAXTitleAttribute) as? String) ?? ""
            var nextPath = path
            if !title.isEmpty, role != kAXMenuRole, role != kAXMenuBarRole { nextPath.append(title) }
            if role == kAXMenuItemRole {
                let character = read(element, kAXMenuItemCmdCharAttribute) as? String
                let code = (read(element, kAXMenuItemCmdVirtualKeyAttribute) as? NSNumber)?.intValue
                let glyph = (read(element, kAXMenuItemCmdGlyphAttribute) as? NSNumber)?.intValue
                let mask = (read(element, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue
                if let combination = KeyCombination(character: character, keyCode: code,
                                                    glyph: glyph, modifierMask: mask) {
                    let enabled = (read(element, kAXEnabledAttribute) as? NSNumber)?.boolValue
                    hotkeys.append(Hotkey(id: "\(application.id):\(indexPath)", application: application,
                                          action: title.isEmpty ? "Без названия" : title,
                                          menuPath: nextPath, combination: combination, isEnabled: enabled))
                }
            }
            guard let children = read(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
            for (index, child) in children.enumerated() {
                guard canContinue() else { break }
                walk(child, path: nextPath, indexPath: "\(indexPath).\(index)", depth: depth + 1)
            }
        }
    }
}

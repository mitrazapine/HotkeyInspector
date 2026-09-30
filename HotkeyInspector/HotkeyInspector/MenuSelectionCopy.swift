import Foundation

enum MenuSelectionCopy {
    static func text(items: [Hotkey], selectedIDs: Set<Hotkey.ID>, conflictIDs: Set<Hotkey.ID>) -> String? {
        // Filter the visible rows instead of iterating an unordered selection.
        let rows = items.filter { selectedIDs.contains($0.id) }.map { item in
            let status = conflictIDs.contains(item.id) ? "Совпадение"
                : item.isEnabled == true ? "Доступно"
                : item.isEnabled == false ? "Недоступно" : "Неизвестно"
            return [item.combination.display, item.action, item.path, item.application.name, status]
                .map(cleanField).joined(separator: "\t")
        }
        return rows.isEmpty ? nil : rows.joined(separator: "\n")
    }

    private static func cleanField(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}

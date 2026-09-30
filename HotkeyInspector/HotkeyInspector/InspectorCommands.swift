import SwiftUI

enum InspectorTab: Hashable {
    case menu, system, monitor
}

struct InspectorCommandActions {
    var find: () -> Void
    var refresh: (() -> Void)?
    var cancel: (() -> Void)? = nil
}

private struct InspectorActiveTabKey: FocusedValueKey {
    typealias Value = InspectorTab
}

private struct InspectorMenuActionsKey: FocusedValueKey {
    typealias Value = InspectorCommandActions
}

private struct InspectorSystemActionsKey: FocusedValueKey {
    typealias Value = InspectorCommandActions
}

extension FocusedValues {
    var inspectorActiveTab: InspectorTab? {
        get { self[InspectorActiveTabKey.self] }
        set { self[InspectorActiveTabKey.self] = newValue }
    }

    var inspectorMenuActions: InspectorCommandActions? {
        get { self[InspectorMenuActionsKey.self] }
        set { self[InspectorMenuActionsKey.self] = newValue }
    }

    var inspectorSystemActions: InspectorCommandActions? {
        get { self[InspectorSystemActionsKey.self] }
        set { self[InspectorSystemActionsKey.self] = newValue }
    }
}

struct InspectorCommands: Commands {
    @AppStorage("keepOnTop") private var keepOnTop = true
    @FocusedValue(\.inspectorActiveTab) private var activeTab
    @FocusedValue(\.inspectorMenuActions) private var menuActions
    @FocusedValue(\.inspectorSystemActions) private var systemActions

    private var actions: InspectorCommandActions? {
        switch activeTab {
        case .menu: return menuActions
        case .system: return systemActions
        case .monitor, nil: return nil
        }
    }

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Найти сочетание…") { actions?.find() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
        }
        CommandGroup(after: .toolbar) {
            Toggle("Поверх окон", isOn: $keepOnTop)
            Divider()
            Button("Обновить сочетания") { actions?.refresh?() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions?.refresh == nil)
            Button("Отменить чтение меню") { actions?.cancel?() }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(actions?.cancel == nil)
        }
    }
}

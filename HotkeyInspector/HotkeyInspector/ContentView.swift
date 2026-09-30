import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = InspectorModel()
    @StateObject private var monitor = HotkeyMonitor()
    @AppStorage("keepOnTop") private var keepOnTop = true
    @State private var selectedHotkeyIDs: Set<Hotkey.ID> = []
    @State private var selectedTab: InspectorTab = .menu
    @State private var systemSearch = ""
    @State private var systemEnabledOnly = false
    @FocusState private var searchFocused: Bool

    private var activeSearch: Binding<String> {
        switch selectedTab {
        case .menu: return $model.search
        case .system: return $systemSearch
        case .monitor: return .constant("")
        }
    }

    private var searchPrompt: Text {
        selectedTab == .system
            ? Text("Действие, сочетание или ID")
            : Text("Действие, сочетание или путь меню")
    }

    private var canRefreshMenu: Bool {
        model.hasAccessibility && model.selectedApplication != nil && !model.isScanning
    }

    var body: some View {
        NavigationStack {
            if selectedTab == .monitor {
                inspectorContent
            } else {
                inspectorContent
                    .searchable(text: activeSearch, placement: .toolbar, prompt: searchPrompt)
                    .searchFocused($searchFocused)
            }
        }
        .onChange(of: selectedTab) { _, _ in searchFocused = false }
        .onAppear { model.start() }
        .onDisappear {
            model.stop()
            monitor.stop(clearHistory: true)
        }
    }

    private var inspectorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("В фокусе macOS: \(model.activeApplicationName)", systemImage: "macwindow")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help("Приложение в фокусе macOS. Источник меню выбирается отдельно во вкладке «Меню».")

            TabView(selection: $selectedTab) {
                menuPane
                    .tabItem { Label("Меню", systemImage: "list.bullet.rectangle") }
                    .tag(InspectorTab.menu)
                SystemHotkeysView(search: $systemSearch, enabledOnly: $systemEnabledOnly, find: { searchFocused = true })
                    .tabItem { Label("Система", systemImage: "gearshape") }
                    .tag(InspectorTab.system)
                MonitorView(monitor: monitor).tabItem { Label("Монитор", systemImage: "waveform") }
                    .tag(InspectorTab.monitor)
            }
            .tabViewStyle(.tabBarOnly)
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $keepOnTop) {
                    Label("Поверх окон", systemImage: "pin")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help(keepOnTop ? "Окно закреплено поверх других" : "Закрепить окно поверх других")
            }
        }
        .focusedSceneValue(\.inspectorActiveTab, selectedTab)
    }

    private var menuPane: some View {
        InspectorPane {
            VStack(alignment: .leading, spacing: 12) {
                AccessibilityPermissionView(model: model)
                AdaptiveControlRow {
                    Picker("Меню приложения", selection: $model.selectedPID) {
                        Text("Выберите приложение").tag(Int32?.none)
                        ForEach(model.applications) { app in
                            Text("\(app.name) · PID \(app.id)").tag(Optional(app.id))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(model.selectedApplication?.name ?? "Выберите приложение для чтения меню")
                    HStack {
                        Button("Последнее активное") { model.selectLastActive() }
                            .help("Выбрать приложение, которое было активно до Hotkey Inspector")
                        Button("Обновить меню") { model.scan() }
                            .disabled(!canRefreshMenu)
                    }.fixedSize()
                }
                HStack(spacing: 12) {
                    Toggle("Доступные", isOn: $model.enabledOnly).toggleStyle(.checkbox)
                    Toggle("Конфликты", isOn: $model.conflictsOnly).toggleStyle(.checkbox)
                }

                if model.isScanning {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Чтение меню…")
                        Button("Отменить") { model.clearScan() }
                    }
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }

                if let result = model.result {
                    InspectorSnapshotSummary(
                        summary: "Найдено: \(result.hotkeys.count) · Показано: \(model.visibleHotkeys.count)",
                        date: result.date)
                        .help("Проверено AX-элементов: \(result.visitedCount)")
                    ForEach(result.warnings, id: \.self) { warning in
                        Text(warning).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        } content: {
            if let result = model.result {
                if model.visibleHotkeys.isEmpty {
                    ContentUnavailableView(
                        result.hotkeys.isEmpty ? "Сочетания не найдены" : "Нет совпадений",
                        systemImage: "magnifyingglass",
                        description: Text(
                            result.hotkeys.isEmpty
                                ? "Приложение может не предоставлять сочетания через меню. Попробуйте активировать его, открыть нужное меню и прочитать снова."
                                : "Измените поиск или фильтры."))
                } else {
                    shortcutTable
                }
            } else if !model.isScanning {
                ContentUnavailableView(
                    model.hasAccessibility ? "Выберите приложение" : "Ожидание разрешения macOS",
                    systemImage: model.hasAccessibility ? "keyboard" : "lock",
                    description: Text(
                        model.hasAccessibility
                            ? "Меню выбранного приложения загрузится автоматически."
                            : "Текущая копия HotkeyInspector ещё не получила Accessibility-доступ. Инструкция — выше."))
            } else {
                Spacer()
            }

        } footer: {
            InspectorSourceFooter("Источник: меню выбранного приложения. Скрытые и глобальные сочетания не охвачены.") {
                if let result = model.result {
                    Text("Проверено AX-элементов: \(result.visitedCount)")
                }
                Text("Переназначения учитываются, если приложение уже отразило их в меню. После изменения настроек перечитайте меню; иногда нужен перезапуск приложения.")
                Text("Конфликты — совпадения физических клавиш и модификаторов у доступных команд одного приложения. Контекст может различаться. Скрытые и глобальные сочетания не охвачены.")
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: model.visibleHotkeys.map(\.id)) { _, visibleIDs in
            selectedHotkeyIDs.formIntersection(visibleIDs)
        }
        .focusedSceneValue(
            \.inspectorMenuActions,
            InspectorCommandActions(
                find: { searchFocused = true },
                refresh: canRefreshMenu ? { model.scan() } : nil,
                cancel: model.isScanning ? { model.clearScan() } : nil
            ))
    }

    private var shortcutTable: some View {
        let conflicts = model.conflictIDs
        let copyText = MenuSelectionCopy.text(items: model.visibleHotkeys,
                                             selectedIDs: selectedHotkeyIDs, conflictIDs: conflicts)
        return Table(model.visibleHotkeys, selection: $selectedHotkeyIDs) {
            TableColumn("Сочетание") { item in
                ShortcutText(value: item.combination.display)
            }.width(min: 110, ideal: 150)
            TableColumn("Действие") { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.action)
                    Text(item.path).font(.caption).foregroundStyle(.secondary)
                }.help(item.path)
            }.width(min: 200, ideal: 330)
            TableColumn("Статус") { item in
                if conflicts.contains(item.id) {
                    Label("Совпадение", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                } else {
                    Text(item.isEnabled == true ? "Доступно" : item.isEnabled == false ? "Недоступно" : "Неизвестно")
                        .foregroundStyle(.secondary)
                }
            }.width(min: 110, ideal: 130)
        }
        .onCopyCommand(perform: copyText.map { text in
            { [NSItemProvider(object: text as NSString)] }
        })
        .contextMenu(forSelectionType: Hotkey.ID.self) { ids in
            if let text = MenuSelectionCopy.text(items: model.visibleHotkeys,
                                                 selectedIDs: ids, conflictIDs: conflicts) {
                Button("Копировать строки") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
    }
}

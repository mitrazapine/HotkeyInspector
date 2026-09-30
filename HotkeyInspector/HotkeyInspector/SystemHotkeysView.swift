import SwiftUI
import AppKit

struct SystemHotkeysView: View {
    @State private var snapshot: SystemHotkeySnapshot?
    @State private var errorMessage: String?
    @Binding var search: String
    @Binding var enabledOnly: Bool
    var find: () -> Void

    private var visibleItems: [SystemHotkeySetting] {
        snapshot?.items.filter { $0.matches(query: search, enabledOnly: enabledOnly) } ?? []
    }

    var body: some View {
        InspectorPane {
            VStack(alignment: .leading, spacing: 12) {
                AdaptiveControlRow(minimumHorizontalWidth: 620) {
                    InspectorSectionTitle(title: "Системные сочетания", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Button("Настройки клавиатуры") { openKeyboardSettings() }
                        Button("Обновить") { refresh() }
                    }.fixedSize()
                }
                Text("Accessibility-доступ для этой вкладки не требуется.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Toggle("Только включённые", isOn: $enabledOnly).toggleStyle(.checkbox)
                }

                if let snapshot {
                    InspectorSnapshotSummary(
                        summary: "Записей: \(snapshot.items.count) · Показано: \(visibleItems.count)",
                        date: snapshot.date)
                }
            }
        } content: {
            if let errorMessage {
                ContentUnavailableView(
                    "Не удалось прочитать настройки", systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage))
            } else if let snapshot {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        snapshot.items.isEmpty ? "Нет сохранённых назначений" : "Нет совпадений",
                        systemImage: "keyboard",
                        description: Text("Измените фильтры или проверьте настройки клавиатуры. Отсутствие записи не означает отсутствие системного сочетания."))
                } else {
                    Table(visibleItems) {
                        TableColumn("Сочетание") { item in
                            ShortcutText(value: item.shortcut)
                                .textSelection(.enabled)
                                .help(item.detail ?? item.shortcut ?? "")
                        }.width(min: 110, ideal: 140, max: 180)
                        TableColumn("Действие") { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.action)
                                if let detail = item.detail {
                                    Text(detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }.help(
                                item.hasReferenceLabel
                                    ? "Справочное название по системному ID. Сочетание прочитано из ваших настроек."
                                    : "macOS не предоставляет название этой команды в файле настроек.")
                        }.width(min: 220, ideal: 300)
                        TableColumn("Статус") { item in
                            Text(item.status).foregroundStyle(item.isEnabled == true ? .primary : .secondary)
                        }.width(min: 90, ideal: 100, max: 120)
                        TableColumn("ID") { item in Text(item.id).textSelection(.enabled) }
                            .width(45)
                    }
                }
            } else {
                Spacer()
            }
        } footer: {
            InspectorSourceFooter("Источник: сохранённые настройки macOS. Названия справочные; список неполный.") {
                if let snapshot {
                    Text(snapshot.sourceURL.path).textSelection(.enabled)
                }
                Text("Названия действий — справочные; системные ID и формат файла не документированы и могут меняться. Неизвестные команды показаны по ID.")
                Text("Источник не охватывает все системные, медиа- и глобальные сочетания. «Включено» отражает сохранённую настройку, а не проверку выполнения команды. После изменений в настройках нажмите «Обновить»; macOS может сохранить их с задержкой.")
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { refresh() }
        .focusedSceneValue(
            \.inspectorSystemActions,
            InspectorCommandActions(
                find: find,
                refresh: { refresh() }
            ))
    }

    private func refresh() {
        do {
            snapshot = try SystemHotkeyReader.read()
            errorMessage = nil
        } catch {
            snapshot = nil
            errorMessage = error.localizedDescription
        }
    }

    private func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

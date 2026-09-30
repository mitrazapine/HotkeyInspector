import SwiftUI

struct MonitorView: View {
    @ObservedObject var monitor: HotkeyMonitor

    var body: some View {
        InspectorPane {
            VStack(alignment: .leading, spacing: 12) {
                AdaptiveControlRow(minimumHorizontalWidth: 620) {
                    InspectorSectionTitle(title: "Монитор сочетаний", systemImage: "waveform")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Button(monitor.isRunning ? "Остановить" : "Запустить") {
                            if monitor.isRunning { monitor.stop() } else { monitor.start() }
                        }
                        Button("Очистить") { monitor.clear() }.disabled(monitor.entries.isEmpty)
                    }.fixedSize()
                }
                Label(monitor.status, systemImage: monitor.isRunning ? "record.circle" : "pause.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    "Только сочетания с ⌘/⌃ и клавиши F1–F20. Текст не читается; история только в памяти."
                )
                .font(.caption).foregroundStyle(.secondary)
                Button("Настройки мониторинга ввода") { monitor.openSettings() }
            }
        } content: {
            if monitor.entries.isEmpty {
                ContentUnavailableView(
                    "Нет событий", systemImage: "keyboard",
                    description: Text("Запустите монитор и нажмите сочетание."))
            } else {
                Table(monitor.entries) {
                    TableColumn("Время") { entry in
                        Text(entry.date.formatted(date: .omitted, time: .standard))
                    }.width(85)
                    TableColumn("Сочетание") { entry in
                        ShortcutText(value: entry.shortcut)
                    }.width(min: 120, ideal: 150)
                    TableColumn("Приложение в фокусе") { entry in Text(entry.applicationName) }
                    TableColumn("Код клавиши") { entry in Text("\(entry.keyCode)") }.width(100)
                }
            }
        } footer: {
            InspectorSourceFooter("Нажатие не подтверждает выполнение команды.") {
                Text("Обычные символы, Shift/Option без ⌘/⌃ и повторы отбрасываются. Текст полей не читается. До 100 событий хранятся только в памяти, без записи на диск и отправки по сети.")
                Text("Защищённый ввод не обходится; некоторые системные клавиши могут быть недоступны.")
                Text("Событие показывает нажатие и приложение в фокусе. Название клавиши берётся из текущей раскладки; физический код показан отдельно.")
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

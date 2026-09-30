import SwiftUI

struct AccessibilityPermissionView: View {
    @ObservedObject var model: InspectorModel

    var body: some View {
        if model.hasAccessibility {
            Label("Доступ к меню разрешён", systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Для чтения меню нужен доступ Accessibility", systemImage: "lock")
                    .font(.headline)
                Text("Разрешите доступ текущей копии HotkeyInspector в настройках macOS. После получения доступа меню загрузится автоматически.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Запросить доступ") { model.requestPermission() }
                        .buttonStyle(.borderedProminent)
                    Button("Настройки macOS") { model.openAccessibilitySettings() }
                }
                DisclosureGroup("Доступ включён, но меню не загружается?") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Разрешение могло остаться от другой сборки. Проверьте, что доступ выдан копии по указанному пути. При необходимости выключите и включите её разрешение, затем перезапустите приложение.")
                            .foregroundStyle(.secondary)
                        Text(model.applicationPath).textSelection(.enabled)
                        HStack {
                            Button("Показать приложение в Finder") { model.revealApplication() }
                            Button("Проверить доступ") { model.refreshPermission() }
                        }
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }
            .font(.callout)
        }
    }
}

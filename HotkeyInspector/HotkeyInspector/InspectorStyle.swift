import SwiftUI

struct InspectorSectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .symbolRenderingMode(.hierarchical)
    }
}

struct ShortcutText: View {
    let value: String?

    var body: some View {
        Text(value ?? "Нет данных")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(value == nil ? .secondary : .primary)
            .lineLimit(1)
    }
}

struct InspectorSnapshotSummary: View {
    let summary: String
    let date: Date

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(summary)
                Spacer(minLength: 12)
                snapshotTime
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(summary)
                snapshotTime
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private var snapshotTime: some View {
        Text("Снимок: \(date.formatted(date: .omitted, time: .shortened))")
            .help(date.formatted(date: .complete, time: .standard))
    }
}

struct InspectorSourceFooter<Details: View>: View {
    let summary: String
    private let details: Details

    init(_ summary: String, @ViewBuilder details: () -> Details) {
        self.summary = summary
        self.details = details()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary)
                .foregroundStyle(.secondary)
            DisclosureGroup("Источник и ограничения") {
                VStack(alignment: .leading, spacing: 8) {
                    details
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .font(.caption)
    }
}

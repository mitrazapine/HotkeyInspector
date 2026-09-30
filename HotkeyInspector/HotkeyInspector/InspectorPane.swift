import SwiftUI

// Preserve the table's viewport when instructions or diagnostics grow.
struct InspectorPane<Header: View, Content: View, Footer: View>: View {
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    private let header: Header
    private let content: Content
    private let footer: Footer

    init(@ViewBuilder header: () -> Header,
         @ViewBuilder content: () -> Content,
         @ViewBuilder footer: () -> Footer) {
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { geometry in
            let visibleFooterHeight = min(footerHeight, 100)
            let headerLimit = max(0, min(geometry.size.height * 0.5,
                                         geometry.size.height - 180 - visibleFooterHeight - 24))
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    header
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                }
                .frame(height: min(headerHeight, headerLimit))
                .scrollDisabled(headerHeight <= headerLimit)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)

                content
                    .frame(minHeight: 180, maxHeight: .infinity)
                    .frame(maxWidth: .infinity)

                ScrollView {
                    footer
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
                }
                .frame(height: visibleFooterHeight)
                .scrollDisabled(footerHeight <= 100)
            }
        }
    }
}

// AnyLayout changes placement without replacing the controls or their focus.
struct AdaptiveControlRow<Content: View>: View {
    @State private var availableWidth: CGFloat = 0
    private let minimumHorizontalWidth: CGFloat
    private let content: Content

    init(minimumHorizontalWidth: CGFloat = 680, @ViewBuilder content: () -> Content) {
        self.minimumHorizontalWidth = minimumHorizontalWidth
        self.content = content()
    }

    private var layout: AnyLayout {
        availableWidth >= minimumHorizontalWidth
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
    }

    var body: some View {
        layout { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
    }
}

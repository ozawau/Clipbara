import SwiftData
import SwiftUI

struct ClipPreviewSheet: View {
    let item: ClipboardItem
    let ui: ClipsUIState

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var library: ClipLibrary { ClipLibrary(context: context) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                    metadata
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(item.headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        library.copy(item)
                        ui.show(String(localized: "Copied"))
                        dismiss()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if let url = item.linkURL {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Open", systemImage: "safari")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.contentType {
        case .image:
            if let image = item.fullImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        case .color:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ClipStyle.tint(for: .color, colorHex: item.colorHex))
                .frame(height: 220)
                .overlay(alignment: .bottomLeading) {
                    Text(item.displayText.uppercased())
                        .font(.system(.title2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(16)
                }
        default:
            Text(item.displayText)
                .font(item.looksLikeCode ? .system(.callout, design: .monospaced) : .body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Type", value: item.contentType.displayName)
            LabeledContent("Date", value: item.copiedAt.formatted(date: .abbreviated, time: .shortened))
            if let source = item.sourceAppName {
                LabeledContent("Source", value: source)
            }
            LabeledContent("Details", value: item.detailSummary)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

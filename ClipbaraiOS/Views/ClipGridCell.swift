import SwiftData
import SwiftUI

struct ClipGridCell: View {
    let item: ClipboardItem
    let pinboards: [Pinboard]
    let currentPinboard: Pinboard?
    let ui: ClipsUIState

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    private var library: ClipLibrary { ClipLibrary(context: context) }
    private var isSelected: Bool { ui.selectedIDs.contains(item.id) }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ClipCardView(item: item, pinboardColor: firstPinboardColor)
            }
            .overlay(alignment: .bottomTrailing) { selectionBadge }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: ClipStyle.cardRadius, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                }
            }
            .scaleEffect(ui.isSelecting && isSelected ? 0.96 : 1)
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: ClipStyle.cardRadius, style: .continuous))
            .onTapGesture(perform: handleTap)
            .contextMenu {
                if !ui.isSelecting {
                    menu
                }
            } preview: {
                ClipCardView(item: item, style: .preview)
                    .frame(width: 340, height: previewHeight)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(item.headerTitle), \(item.displayText)"))
            .accessibilityHint(Text(ui.isSelecting ? "Toggles selection" : "Copies the clip"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("clipCard")
    }

    private var previewHeight: CGFloat {
        switch item.contentType {
        case .image:
            if let image = item.thumbnailImage(), image.size.width > 0 {
                return min(max(340 * image.size.height / image.size.width + 48, 200), 520)
            }
            return 340
        case .color, .fileURL: return 260
        case .url: return 240
        default:
            let length = item.displayText.count
            return min(max(CGFloat(length) * 0.9 + 110, 200), 520)
        }
    }

    private var firstPinboardColor: Color? {
        guard currentPinboard == nil, item.isPinned else { return nil }
        let pinned = pinboards.first { library.isItem(item, in: $0) }
        return pinned.map { PinboardPalette.color(for: $0, among: pinboards) }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if ui.isSelecting {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(isSelected ? Color.white : Color.secondary, isSelected ? Color.accentColor : Color.clear)
                .background(Circle().fill(.background).padding(2))
                .padding(10)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func handleTap() {
        if ui.isSelecting {
            withAnimation(.snappy(duration: 0.2)) { ui.toggleSelection(item) }
        } else {
            library.copy(item)
            ui.show(String(localized: "Copied"))
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var menu: some View {
        ControlGroup {
            Button {
                library.copy(item)
                ui.show(String(localized: "Copied"))
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            if item.canCopyAsPlainText {
                Button {
                    library.copy(item, asPlainText: true)
                    ui.show(String(localized: "Copied as Plain Text"))
                } label: {
                    Label("Copy as Plain Text", systemImage: "textformat")
                }
            }
            shareLink
        }

        if let url = item.linkURL {
            Button {
                openURL(url)
            } label: {
                Label("Open", systemImage: "safari")
            }
        }
        Button {
            ui.previewItem = item
        } label: {
            Label("Preview", systemImage: "eye")
        }
        Button {
            ui.beginRename(item)
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Menu {
            ForEach(pinboards) { pinboard in
                Button {
                    let wasPinned = library.isItem(item, in: pinboard)
                    library.toggle(item, in: pinboard)
                    ui.show(
                        wasPinned
                            ? String(localized: "Removed from \(pinboard.name)")
                            : String(localized: "Added to \(pinboard.name)"),
                        systemImage: wasPinned ? "pin.slash.fill" : "pin.fill"
                    )
                } label: {
                    if library.isItem(item, in: pinboard) {
                        Label(pinboard.name, systemImage: "checkmark")
                    } else {
                        Text(pinboard.name)
                    }
                }
            }
            if !pinboards.isEmpty { Divider() }
            Button {
                ui.beginNewPinboard(for: [item])
            } label: {
                Label("New Pinboard…", systemImage: "plus")
            }
        } label: {
            Label("Pin", systemImage: "pin")
        }

        if let currentPinboard {
            Button {
                library.remove([item], from: currentPinboard)
            } label: {
                Label("Remove from Pinboard", systemImage: "pin.slash")
            }
        }

        Button(role: .destructive) {
            withAnimation(.snappy) { library.delete([item]) }
        } label: {
            Label("Delete", systemImage: "trash")
        }

        Divider()

        Button {
            ui.beginSelecting(with: item)
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }
    }

    @ViewBuilder
    private var shareLink: some View {
        switch item.contentType {
        case .image:
            if let image = item.fullImage() {
                let swiftUIImage = Image(uiImage: image)
                ShareLink(item: swiftUIImage, preview: SharePreview(item.headerTitle, image: swiftUIImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        case .url:
            if let url = item.linkURL {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        default:
            ShareLink(item: item.displayText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}

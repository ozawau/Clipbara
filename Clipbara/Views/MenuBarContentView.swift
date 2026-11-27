import SwiftUI
import SwiftData
import KeyboardShortcuts

struct MenuBarContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var updaterViewModel: CheckForUpdatesViewModel
    @Query(sort: \ClipboardItem.copiedAt, order: .reverse)
    private var recentItems: [ClipboardItem]

    private var topItems: [ClipboardItem] {
        Array(recentItems.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if topItems.isEmpty {
                Text("No clipboard history")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                Text("Recent Copies")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(topItems) { item in
                    MenuBarItemRow(item: item)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Toggle(isOn: Binding(
                get: { appState.clipboardMonitor.isMonitoring },
                set: { _ in appState.clipboardMonitor.toggle() }
            )) {
                Label("Clipboard Monitoring", systemImage: "clipboard")
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            Button {
                appState.togglePanel()
            } label: {
                HStack {
                    Text("Open History")
                    Spacer()
                    Text(verbatim: "\u{21E7}\u{2318}V")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button {
                appState.toggleClipQueue()
            } label: {
                HStack {
                    appState.clipQueue.isActive ? Text("End Clip Queue") : Text("Start Clip Queue")
                    Spacer()
                    if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleClipQueue) {
                        Text(verbatim: shortcut.description)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            #if !APPSTORE
            Button("Check for Updates...") {
                updaterViewModel.checkForUpdates()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            #endif

            Button("Send Feedback...") {
                NSWorkspace.shared.open(ReviewPrompter.feedbackURL)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            #if APPSTORE
            Button("Rate on App Store") {
                NSWorkspace.shared.open(ReviewPrompter.writeReviewURL)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            #endif

            Button("Settings...") {
                openSettings()
                SettingsWindowFront.bring()
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button("Quit Clipbara") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 4)
        }
        .frame(width: 280)
    }
}

struct MenuBarItemRow: View {
    let item: ClipboardItem
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.clipQueue.stop()
            appState.bumpClipToFront(item)
            appState.clipboardMonitor.skipNextChange()
            appState.pasteService.paste(item: item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.contentType.systemImage)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.system(size: 13))

                    HStack(spacing: 4) {
                        if let appName = item.sourceAppName {
                            Text(appName)
                        }
                        Text(RelativeTimeFormatter.string(for: item.copiedAt))
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private var displayText: String {
        switch item.contentType {
        case .plainText, .richText, .html, .url:
            return item.textContent ?? "..."
        case .image:
            return String(localized: "Image")
        case .fileURL:
            return item.textContent ?? String(localized: "File")
        case .color:
            return item.textContent ?? String(localized: "Color")
        case .unknown:
            return String(localized: "Unknown")
        }
    }
}

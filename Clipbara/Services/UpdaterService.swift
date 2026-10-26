import AppKit
import Foundation

#if !APPSTORE
import Sparkle

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = true

    init() {
        // Do not start Sparkle's background checks; "Check for Updates" is a stub
        // that always reports the running build as current.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        Self.showUpToDateAlert()
    }

    private static func showUpToDateAlert() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = String(localized: "You're up to date")
        alert.informativeText = "Clipbara \(version) (\(build)) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
#else
// Mac App Store build: updates are delivered by the App Store, Sparkle is not linked.
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = true
    func checkForUpdates() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = String(localized: "You're up to date")
        alert.informativeText = "Clipbara \(version) (\(build)) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
#endif

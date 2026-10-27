import Foundation

/// Where this process's bundle lives on disk. Used to keep Login Items and
/// Accessibility lists from accumulating Debug, DMG-staging, and Downloads copies.
enum AppInstallLocation {
    nonisolated static let applicationsBundlePath = "/Applications/Clipbara.app"

    nonisolated static var bundlePath: String {
        Bundle.main.bundleURL.path
    }

    /// The shipped copy users install under /Applications.
    nonisolated static var isApplicationsCopy: Bool {
        isApplicationsPath(bundlePath)
    }

    nonisolated static func isApplicationsPath(_ path: String) -> Bool {
        path == applicationsBundlePath || path.hasPrefix(applicationsBundlePath + "/")
    }

    /// Xcode Debug, release staging (`build/dmg`), Downloads drops, or a mounted DMG.
    nonisolated static var isEphemeralCopy: Bool {
        if isApplicationsCopy { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = bundlePath
        if path.contains("/DerivedData/") { return true }
        if path.contains("/build/dmg/") || path.contains("/build/export/") { return true }
        if path.hasPrefix(home + "/Downloads/") { return true }
        if path.hasPrefix("/Volumes/") { return true }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Only the Applications build may register Login Items or prompt for Accessibility on launch.
    nonisolated static var supportsSystemIntegration: Bool {
        isApplicationsCopy && !isEphemeralCopy
    }
}

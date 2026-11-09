import CoreServices
import Foundation

/// Keeps Spotlight, the Accessibility app list, and other Launch Services UIs
/// from retaining stale Clipbara copies (Debug, DMG staging, Downloads, etc.).
enum LaunchServicesRegistry {
    private static let bundleId = "com.minsang.PasteClip"
    private static let lsregisterPath =
        "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

    /// Called when the /Applications build starts so only that copy stays registered.
    static func unregisterEphemeralCopies() {
        guard AppInstallLocation.isApplicationsCopy else { return }

        let paths = discoverRegisteredPaths()
            .filter { !AppInstallLocation.isApplicationsPath($0) }

        for path in paths {
            unregister(at: path)
        }
    }

    /// Xcode registers Debug builds; undo that so they do not appear in system app lists.
    static func unregisterCurrentBundleIfEphemeral() {
        guard AppInstallLocation.isEphemeralCopy else { return }
        unregister(at: AppInstallLocation.bundlePath)
    }

    private static func discoverRegisteredPaths() -> [String] {
        // Spotlight only — `lsregister -dump` can take tens of seconds and used
        // to block App.init on the main thread so the menu bar never appeared.
        let query = "kMDItemCFBundleIdentifier == '\(bundleId)'" as CFString
        return MDQueryBridge.paths(matching: query) ?? []
    }

    private static func unregister(at appPath: String) {
        guard FileManager.default.fileExists(atPath: appPath)
            || appPath.contains("Clipbara.app") else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregisterPath)
        process.arguments = ["-f", "-u", appPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

/// Minimal Spotlight query wrapper (AppKit-free for strict concurrency).
private enum MDQueryBridge {
    static func paths(matching query: CFString) -> [String]? {
        guard let queryRef = MDQueryCreate(kCFAllocatorDefault, query, nil, nil) else {
            return nil
        }
        guard MDQueryExecute(queryRef, CFOptionFlags(kMDQuerySynchronous.rawValue)) else {
            return nil
        }
        let count = MDQueryGetResultCount(queryRef)
        guard count > 0 else { return [] }

        var paths: [String] = []
        paths.reserveCapacity(count)
        for index in 0..<count {
            guard let raw = MDQueryGetResultAtIndex(queryRef, index) else { continue }
            // Results are MDItem refs, not toll-free bridged objects — `as! MDItem`
            // traps (failed cast) and used to crash every /Applications launch.
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard CFGetTypeID(item) == MDItemGetTypeID() else { continue }
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String else { continue }
            paths.append(path)
        }
        return paths
    }
}

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
        var paths: [String] = []

        let query = "kMDItemCFBundleIdentifier == '\(bundleId)'" as CFString
        if let found = MDQueryBridge.paths(matching: query) {
            paths.append(contentsOf: found)
        }

        if let dump = dumpRegisteredPaths() {
            paths.append(contentsOf: dump)
        }

        return paths
    }

    private static func dumpRegisteredPaths() -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregisterPath)
        process.arguments = ["-dump"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        return text.split(separator: "\n").compactMap { line in
            let s = String(line).trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix("path:") else { return nil }
            guard s.contains("Clipbara.app") else { return nil }
            guard let range = s.range(of: "Clipbara.app") else { return nil }
            let prefix = s[s.index(s.startIndex, offsetBy: 6)..<range.upperBound]
            return String(prefix).trimmingCharacters(in: .whitespaces)
        }
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
        MDQueryExecute(queryRef, CFOptionFlags(kMDQuerySynchronous.rawValue))
        let count = MDQueryGetResultCount(queryRef)
        guard count > 0 else { return [] }

        var paths: [String] = []
        paths.reserveCapacity(count)
        for index in 0..<count {
            guard let raw = MDQueryGetResultAtIndex(queryRef, index) else { continue }
            let item = raw as! MDItem
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String else { continue }
            paths.append(path)
        }
        return paths
    }
}

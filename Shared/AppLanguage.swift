import Foundation
#if os(macOS)
import AppKit
#endif

/// Per-app language. `rawValue` is stored in UserDefaults and, except for
/// `.system`, written to `AppleLanguages`.
///
/// The names of the fixed languages stay in that language, so the menu is
/// readable after a switch. The running process keeps the language it
/// launched with; the new choice applies on the next launch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"

    static let defaultsKey = "appLanguage"
    /// Shared with the iPhone keyboard extension.
    static let appGroupID = "group.com.minsang.Clipbara"

    var id: String { rawValue }

    /// Every language the app ships, in picker order. `.system` follows the
    /// language chosen in System Settings.
    static var supported: [AppLanguage] { allCases }

    var nativeName: String {
        switch self {
        case .system: String(localized: "System")
        case .english: "English"
        case .korean: "한국어"
        case .simplifiedChinese: "简体中文"
        }
    }

    /// Writes the choice for the next launch of this app and the keyboard extension.
    func apply() {
        let defaults = UserDefaults.standard
        if rawValue.isEmpty {
            defaults.removeObject(forKey: Self.defaultsKey)
        } else {
            defaults.set(rawValue, forKey: Self.defaultsKey)
        }
        Self.writeAppleLanguages(rawValue, to: defaults)
        if let shared = UserDefaults(suiteName: Self.appGroupID) {
            if rawValue.isEmpty {
                shared.removeObject(forKey: Self.defaultsKey)
            } else {
                shared.set(rawValue, forKey: Self.defaultsKey)
            }
            Self.writeAppleLanguages(rawValue, to: shared)
        }
    }

    /// Call before any localized string is loaded. A keyboard extension has
    /// its own defaults, so it copies the choice the app published.
    static func installPreferredLanguageForThisProcess() {
        let code = UserDefaults(suiteName: appGroupID)?.string(forKey: defaultsKey) ?? ""
        writeAppleLanguages(code, to: .standard)
    }

    private static func writeAppleLanguages(_ code: String, to defaults: UserDefaults) {
        if code.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([code], forKey: "AppleLanguages")
        }
    }

    #if os(macOS)
    /// Quits and opens this copy again, so the new language is the one the process starts with.
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.4; open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
    #endif
}

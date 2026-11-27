import Foundation

/// Clears a trial lock written by older builds into the app group.
///
/// The keyboard no longer reads this. Publishing `open` keeps an already
/// installed keyboard extension from staying locked until it is updated.
enum KeyboardAccess {
    private static let modeKey = "keyboardAccessMode"

    static func publishOpen(to defaults: UserDefaults = ClipStore.defaults) {
        defaults.set("open", forKey: modeKey)
    }
}

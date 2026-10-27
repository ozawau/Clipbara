import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Optional "paste into the active app": after a clip is copied and the panel
/// closes, Clipbara presses ⌘V for the user. Off by default. Posting a key
/// event needs Accessibility permission, and without it the clip is only
/// copied, exactly as when the setting is off.
@MainActor
enum DirectPaste {
    nonisolated static let enabledDefaultsKey = "pasteIntoActiveApp"

    /// Stamped on the ⌘V events Clipbara posts, so they can be told apart from
    /// the user's own ⌘V.
    nonisolated static let syntheticEventMarker: Int64 = 0x436C_6970 // "Clip"

    /// Whether this build offers pasting into the active app. App Review rejected
    /// it in the App Store build under guideline 2.4.5 (Accessibility used for
    /// something other than accessibility), so only the DMG build has it. The
    /// Clip Queue no longer needs Accessibility and is in both builds.
    #if APPSTORE
    nonisolated static let isAvailable = false
    #else
    nonisolated static let isAvailable = true
    #endif

    /// On by default. `bool(forKey:)` is false when the key is missing, so
    /// treat a missing value as enabled and only honor an explicit `false`.
    static var isEnabled: Bool {
        guard isAvailable else { return false }
        if UserDefaults.standard.object(forKey: enabledDefaultsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: enabledDefaultsKey)
    }

    /// Reads the Accessibility grant live. `CGPreflightPostEventAccess` kept
    /// answering true inside a running process after the grant was removed in
    /// System Settings, so the settings warning never appeared and ⌘V was
    /// silently dropped. The Accessibility grant alone is enough to post it.
    static var hasPermission: Bool {
        isAvailable && AXIsProcessTrusted()
    }

    /// Whether the next paste should be followed by ⌘V.
    static var isReady: Bool {
        isEnabled && hasPermission
    }

    /// Path of the running binary — useful when Accessibility lists a stale copy.
    static var runningAppPath: String {
        Bundle.main.bundleURL.path
    }

    /// Asks for Accessibility access. A sandboxed build gets no prompt and is
    /// not added to the list (the request is only checked), so Settings tells
    /// the user to add Clipbara with the + button.
    @discardableResult
    static func requestPermission() -> Bool {
        guard isAvailable else { return false }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Clears every Clipbara row in Accessibility (Debug, Downloads, etc.). Re-add
    /// only `/Applications/Clipbara.app` afterward.
    static func resetAccessibilityEntries() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.minsang.PasteClip"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Sends ⌘V after optionally handing focus back to `targetApp`.
    ///
    /// Call only after the panel is off screen. Releases any still-held
    /// modifiers first so ⇧Return does not turn into ⌘⇧V.
    @discardableResult
    static func sendPasteShortcut(to targetApp: NSRunningApplication? = nil) -> Bool {
        guard hasPermission else { return false }

        if let targetApp, targetApp != .current, !targetApp.isTerminated {
            targetApp.activate()
        }

        let keyCode = PasteKeyCode.current()
        let source = CGEventSource(stateID: .hidSystemState)
        // Keep keys the user is still holding from mixing into the shortcut.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        source?.localEventsSuppressionInterval = 0.15

        releaseHeldModifiers(source: source)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        // Include the left Command device bit; some apps ignore a Command flag
        // that no physical side key accounts for.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x0000_0008)
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        keyUp.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    /// Posts key-ups for Shift / Control / Option / Command on both sides so a
    /// still-held ⇧ from ⇧Return cannot contaminate the synthetic ⌘V.
    private static func releaseHeldModifiers(source: CGEventSource?) {
        let modifierKeyCodes: [CGKeyCode] = [
            CGKeyCode(kVK_Shift),
            CGKeyCode(kVK_RightShift),
            CGKeyCode(kVK_Control),
            CGKeyCode(kVK_RightControl),
            CGKeyCode(kVK_Option),
            CGKeyCode(kVK_RightOption),
            CGKeyCode(kVK_Command),
            CGKeyCode(kVK_RightCommand),
        ]
        for code in modifierKeyCodes {
            let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
            up?.flags = []
            up?.post(tap: .cghidEventTap)
        }
    }
}

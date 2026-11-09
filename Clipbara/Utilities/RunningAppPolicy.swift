import AppKit
import ServiceManagement

@MainActor
enum RunningAppPolicy {
    private static let bundleId = "com.minsang.PasteClip"

    /// Prefer a single running instance: the /Applications copy wins; ephemeral
    /// builds exit when that copy is already running.
    static func applyOnLaunch() {
        reconcileLoginItemRegistration()

        // Launch Services cleanup talks to Spotlight / lsregister — never block
        // App.init on it or the menu bar and hotkeys stay dead until it finishes.
        Task.detached(priority: .utility) {
            LaunchServicesRegistry.unregisterEphemeralCopies()
            LaunchServicesRegistry.unregisterCurrentBundleIfEphemeral()
        }

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if AppInstallLocation.isApplicationsCopy {
            for app in others {
                app.terminate()
            }
            return
        }

        if AppInstallLocation.isEphemeralCopy,
           others.contains(where: { $0.bundleURL?.path == AppInstallLocation.applicationsBundlePath }) {
            NSApp.terminate(nil)
        }
    }

    /// Ephemeral builds must not stay registered in Login Items.
    static func reconcileLoginItemRegistration() {
        guard AppInstallLocation.isEphemeralCopy else { return }
        guard SMAppService.mainApp.status == .enabled else { return }
        try? SMAppService.mainApp.unregister()
    }
}

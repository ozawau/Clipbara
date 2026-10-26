import AppKit

/// Receives `clipbara://` links; see `URLCommand`.
@MainActor
final class URLCommandHandler: NSObject {
    static let shared = URLCommandHandler()

    private weak var appState: AppState?
    /// The most recent regular app other than Clipbara to come to the front.
    /// Launchers such as Raycast are agent apps: activating one after it has
    /// hidden leaves it active with no window, and it swallows the keyboard.
    private var lastOtherApp: NSRunningApplication?
    /// A command waiting for focus to return to the app the user was in.
    private var pendingCommand: URLCommand?
    private var settleTimer: Timer?
    private var settleStarted = Date()
    private var settleStableSince = Date()
    private var settleFrontPID: pid_t?

    func install(appState: AppState) {
        self.appState = appState
        let front = NSWorkspace.shared.frontmostApplication
        if let front, Self.isFocusTarget(front) {
            lastOtherApp = front
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app, Self.isFocusTarget(app) else { return }
                self.lastOtherApp = app
            }
        }
        registerEventHandler()
        // SwiftUI may register its own URL handler while the app finishes
        // launching, which would replace this one. Register again after.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.registerEventHandler()
            }
        }
    }

    private static func isFocusTarget(_ app: NSRunningApplication) -> Bool {
        app != .current && app.activationPolicy == .regular
    }

    private func registerEventHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string),
              let command = URLCommand(url: url) else { return }

        // Opening a link brings Clipbara to the front, which takes focus from
        // the app the user wants to paste into. Hand focus back, then wait for
        // it to settle, since a launcher such as Raycast also hands focus back
        // as it hides. A panel opened before that did not become the key
        // window, so arrow keys and Esc went to the app behind it.
        if NSApp.isActive, let app = lastOtherApp, !app.isTerminated {
            app.activate()
        }
        pendingCommand = command
        waitForFocusToSettle()
    }

    private func waitForFocusToSettle() {
        settleTimer?.invalidate()
        settleStarted = Date()
        settleStableSince = settleStarted
        settleFrontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        settleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkFocusSettled()
            }
        }
    }

    private func checkFocusSettled() {
        let now = Date()
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != settleFrontPID || front == .current {
            settleFrontPID = front?.processIdentifier
            settleStableSince = now
        }
        let settled = !NSApp.isActive && front != .current
            && now.timeIntervalSince(settleStableSince) >= 0.15
        guard settled || now.timeIntervalSince(settleStarted) > 1 else { return }
        settleTimer?.invalidate()
        settleTimer = nil
        runPendingCommand()
    }

    private func runPendingCommand() {
        guard let command = pendingCommand else { return }
        pendingCommand = nil
        run(command)
    }

    private func run(_ command: URLCommand) {
        guard let appState else { return }
        switch command {
        case .open:
            if !appState.panelController.isPresented { appState.togglePanel() }
        case .toggle:
            if appState.panelController.isPresented {
                appState.hidePanel()
            } else {
                appState.togglePanel()
            }
        case .queue:
            appState.toggleClipQueue()
        }
    }
}

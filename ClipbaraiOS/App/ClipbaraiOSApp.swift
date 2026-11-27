import SwiftData
import SwiftUI
import UIKit

@main
struct ClipbaraiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container: ModelContainer
    private let snapshots: SnapshotPublisher

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(OnboardingView.doneKey, store: ClipStore.defaults) private var onboardingDone = false

    private var onboardingBinding: Binding<Bool> {
        Binding(get: { !onboardingDone }, set: { if !$0 { onboardingDone = true } })
    }

    init() {
        #if DEBUG
        let demo = ProcessInfo.processInfo.arguments.contains("-ClipbaraDemoData")
        container = ClipStore.makeContainer(inMemory: demo)
        if demo {
            DemoData.seed(into: container.mainContext)
        }
        #else
        let demo = false
        container = ClipStore.makeContainer()
        #endif
        snapshots = SnapshotPublisher(container: container)
        snapshots.start()
        KeyboardAccess.publishOpen()
        if !demo {
            ClipSync.shared.configure(container: container, defaults: ClipStore.defaults)
        }
    }

    var body: some Scene {
        WindowGroup {
            ClipsScreen()
                .fullScreenCover(isPresented: onboardingBinding) {
                    OnboardingView()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                snapshots.refresh()
                ClipSync.shared.syncOnOpen()
                ClipSync.shared.startLivePolling()
            } else {
                ClipSync.shared.stopLivePolling()
            }
            if phase == .background { snapshots.publish() }
        }
    }
}

/// CloudKit tells the sync engine about changes from other devices with silent pushes.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}

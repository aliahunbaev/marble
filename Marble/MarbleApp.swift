import SwiftUI
import SwiftData
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Foreground dedupe for the rest-timer bell: when the app is open,
    /// the in-app tick already rings the bell with haptics — suppress
    /// the local notification entirely so it never double-sounds.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}

@main
struct MarbleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var auth = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
        .modelContainer(for: [
            Exercise.self,
            WorkoutTemplate.self,
            Workout.self,
            ExerciseLog.self,
            WorkoutSet.self,
            TrackedLift.self,
            ProgressPhoto.self,
            BodyweightEntry.self
        ]) { result in
            if case .success(let container) = result {
                ExerciseSeed.seedIfNeeded(context: container.mainContext)
                // Repair templates whose `.exercises` relationship is
                // empty but `exerciseNames` is populated — the legacy
                // fingerprint of the pre-8c234ac upload bug. Runs after
                // seeds so the Exercise lookup table is fully present;
                // idempotent, no-op on healthy templates.
                CloudSyncService.shared.repairBrokenTemplates(context: container.mainContext)
                Task { @MainActor in
                    auth.modelContext = container.mainContext
                }
            }
        }
    }
}

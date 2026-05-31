import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
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
                Task { @MainActor in
                    auth.modelContext = container.mainContext
                }
            }
        }
    }
}

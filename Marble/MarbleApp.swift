import SwiftUI
import SwiftData

@main
struct MarbleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Exercise.self,
            WorkoutTemplate.self,
            Workout.self,
            ExerciseLog.self,
            WorkoutSet.self,
            TrackedLift.self
        ]) { result in
            if case .success(let container) = result {
                ExerciseSeed.seedIfNeeded(context: container.mainContext)
            }
        }
    }
}

import SwiftUI
import SwiftData

@main
struct MarbleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            FoodEntry.self,
            WeightEntry.self,
            WorkoutEntry.self,
            ExerciseSet.self,
            ProgressPhoto.self
        ])
    }
}

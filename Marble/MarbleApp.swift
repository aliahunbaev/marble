import SwiftUI
import SwiftData

@main
struct MarbleApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodEntry.self,
            WeightEntry.self,
            WorkoutEntry.self, // Legacy model (keep for migration)
            WorkoutSession.self, // New workout model
            ExercisePerformance.self, // Links exercises to workout sessions
            Exercise.self, // Exercise library
            ExerciseSet.self,
            ProgressPhoto.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task { @MainActor in
                        ExerciseDatabase.shared.seedExercisesIfNeeded(
                            modelContext: sharedModelContainer.mainContext
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

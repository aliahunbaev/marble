import Foundation
import SwiftData

@MainActor
class ExerciseDatabase {
    static let shared = ExerciseDatabase()

    private init() {}

    /// Seeds the database with pre-populated exercises from JSON
    func seedExercisesIfNeeded(modelContext: ModelContext) {
        // Check if already seeded
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { !$0.isCustom }
        )

        do {
            let existingExercises = try modelContext.fetch(descriptor)
            if !existingExercises.isEmpty {
                print("✓ Exercises already seeded (\(existingExercises.count) exercises)")
                return
            }
        } catch {
            print("⚠️ Error checking existing exercises: \(error)")
        }

        // Load and seed exercises
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let exerciseDataList = try? JSONDecoder().decode([ExerciseData].self, from: data) else {
            print("⚠️ Failed to load exercises.json")
            return
        }

        for exerciseData in exerciseDataList {
            let exercise = Exercise(
                name: exerciseData.name,
                equipment: exerciseData.equipment,
                category: exerciseData.category,
                muscleGroups: exerciseData.muscleGroups,
                isCustom: false
            )
            modelContext.insert(exercise)
        }

        do {
            try modelContext.save()
            print("✓ Seeded \(exerciseDataList.count) exercises")
        } catch {
            print("⚠️ Failed to save exercises: \(error)")
        }
    }

    /// Fetch all exercises, sorted by name
    func fetchAllExercises(modelContext: ModelContext) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch exercises grouped by category
    func fetchExercisesByCategory(modelContext: ModelContext) -> [(String, [Exercise])] {
        let exercises = fetchAllExercises(modelContext: modelContext)

        let categoryOrder = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio"]
        let grouped = Dictionary(grouping: exercises) { $0.category }

        return categoryOrder.compactMap { category in
            guard let exercises = grouped[category] else { return nil }
            return (category, exercises.sorted { $0.displayName < $1.displayName })
        }
    }

    /// Search exercises by name
    func searchExercises(query: String, modelContext: ModelContext) -> [Exercise] {
        guard !query.isEmpty else {
            return fetchAllExercises(modelContext: modelContext)
        }

        let lowercasedQuery = query.lowercased()
        let descriptor = FetchDescriptor<Exercise>()

        guard let allExercises = try? modelContext.fetch(descriptor) else {
            return []
        }

        return allExercises.filter { exercise in
            exercise.name.lowercased().contains(lowercasedQuery) ||
            exercise.equipment.lowercased().contains(lowercasedQuery) ||
            exercise.category.lowercased().contains(lowercasedQuery)
        }
    }

    /// Create a custom exercise
    func createCustomExercise(
        name: String,
        equipment: String,
        category: String,
        muscleGroups: [String],
        modelContext: ModelContext
    ) -> Exercise {
        let exercise = Exercise(
            name: name,
            equipment: equipment,
            category: category,
            muscleGroups: muscleGroups,
            isCustom: true
        )
        modelContext.insert(exercise)
        return exercise
    }

    /// Fetch recently used exercises (based on workout history)
    func fetchRecentExercises(modelContext: ModelContext, limit: Int = 5) -> [Exercise] {
        // Get all completed workout sessions
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let sessions = try? modelContext.fetch(descriptor) else {
            return []
        }

        // Collect exercises from recent sessions
        var seenExercises = Set<UUID>()
        var recentExercises: [Exercise] = []

        for session in sessions.prefix(10) {
            for performance in session.exercises {
                if let exercise = performance.exercise,
                   !seenExercises.contains(exercise.id) {
                    seenExercises.insert(exercise.id)
                    recentExercises.append(exercise)

                    if recentExercises.count >= limit {
                        return recentExercises
                    }
                }
            }
        }

        return recentExercises
    }

    /// Fetch previous workout data for a specific exercise
    /// Returns the most recent ExercisePerformance for the given exercise
    func fetchPreviousWorkout(
        for exercise: Exercise,
        modelContext: ModelContext
    ) -> ExercisePerformance? {
        let descriptor = FetchDescriptor<ExercisePerformance>()

        guard let allPerformances = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Filter performances for this exercise and get the most recent
        let matchingPerformances = allPerformances.filter { performance in
            performance.exercise?.id == exercise.id
        }

        // Sort by workout session date
        let sorted = matchingPerformances.sorted { perf1, perf2 in
            guard let date1 = perf1.workoutSession?.date,
                  let date2 = perf2.workoutSession?.date else {
                return false
            }
            return date1 > date2
        }

        return sorted.first
    }
}

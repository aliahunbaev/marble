import Foundation
import SwiftData

enum PreviousPerformance {
    /// Returns the sets from the most recent completed workout for a given exercise.
    static func previousSets(for exercise: Exercise, context: ModelContext) -> [WorkoutSet] {
        var descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        guard let workouts = try? context.fetch(descriptor) else { return [] }

        for workout in workouts {
            if let log = workout.exerciseLogs.first(where: { $0.exercise?.persistentModelID == exercise.persistentModelID }) {
                return log.sets
            }
        }
        return []
    }

    /// Formatted string for a specific set index, e.g. "225 × 8". Unit is
    /// already conveyed by the LBS column header — repeating it in every row
    /// is noise.
    static func formattedPrevious(for exercise: Exercise, setIndex: Int, context: ModelContext) -> String? {
        let sets = previousSets(for: exercise, context: context)
        guard setIndex < sets.count else { return nil }
        let set = sets[setIndex]
        guard set.weight > 0 || set.reps > 0 else { return nil }

        let weightStr: String
        if set.weight == floor(set.weight) {
            weightStr = "\(Int(set.weight))"
        } else {
            weightStr = String(format: "%.1f", set.weight)
        }
        return "\(weightStr) × \(set.reps)"
    }
}

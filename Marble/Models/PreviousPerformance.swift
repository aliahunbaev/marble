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

    /// Component values for a specific set index — weight and reps as
    /// editable strings. Used to populate ghost-placeholder text inside
    /// the LBS and REPS input fields. Returns nil for either component
    /// when no previous set exists at that index or the value is zero
    /// (zero is meaningless as a suggestion).
    static func previousComponents(
        for exercise: Exercise,
        setIndex: Int,
        context: ModelContext
    ) -> (weight: String?, reps: String?) {
        let sets = previousSets(for: exercise, context: context)
        guard setIndex < sets.count else { return (nil, nil) }
        let set = sets[setIndex]

        let weightStr: String?
        if set.weight > 0 {
            weightStr = set.weight == floor(set.weight)
                ? "\(Int(set.weight))"
                : String(format: "%.1f", set.weight)
        } else {
            weightStr = nil
        }

        let repsStr: String? = set.reps > 0 ? "\(set.reps)" : nil
        return (weightStr, repsStr)
    }
}

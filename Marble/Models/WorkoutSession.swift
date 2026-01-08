import Foundation
import SwiftData

/// Represents a complete workout session (Strong-style)
/// Contains multiple exercises performed in one session
@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var name: String // e.g., "Midday Workout", "Push Day"
    var startTime: Date
    var endTime: Date?
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \ExercisePerformance.workoutSession)
    var exercises: [ExercisePerformance]

    /// Duration in seconds (if workout is finished)
    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    init(name: String, date: Date = Date(), startTime: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.name = name
        self.startTime = startTime
        self.notes = notes
        self.exercises = []
    }
}

/// Represents one exercise performed within a workout session
/// Links to the Exercise library and tracks sets for that exercise
@Model
final class ExercisePerformance {
    var id: UUID
    var exercise: Exercise? // Links to Exercise library
    var order: Int // Display order within the workout
    var notes: String?

    var workoutSession: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercisePerformance)
    var sets: [ExerciseSet]

    init(exercise: Exercise?, order: Int, notes: String? = nil) {
        self.id = UUID()
        self.exercise = exercise
        self.order = order
        self.notes = notes
        self.sets = []
    }
}

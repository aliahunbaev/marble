import Foundation
import SwiftData

@Model
final class WorkoutEntry {
    var id: UUID
    var date: Date
    var exerciseName: String
    var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workout)
    var sets: [ExerciseSet]

    init(exerciseName: String, date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.exerciseName = exerciseName
        self.notes = notes
        self.sets = []
    }
}

@Model
final class ExerciseSet {
    var id: UUID
    var reps: Int
    var weight: Double // in lbs or kg
    var completed: Bool // Checkmark in Strong-style UI
    var restTimer: Int? // Rest duration in seconds (e.g., 120 for 2:00)

    // Relationships (supporting both old and new models)
    var workout: WorkoutEntry? // Legacy relationship
    var exercisePerformance: ExercisePerformance? // New relationship

    init(reps: Int, weight: Double, completed: Bool = false, restTimer: Int? = nil) {
        self.id = UUID()
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.restTimer = restTimer
    }
}

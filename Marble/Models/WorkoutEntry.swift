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
    var workout: WorkoutEntry?

    init(reps: Int, weight: Double) {
        self.id = UUID()
        self.reps = reps
        self.weight = weight
    }
}

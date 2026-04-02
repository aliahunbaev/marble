import Foundation
import SwiftData

@Model
final class ExerciseLog {
    var exercise: Exercise?
    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet]

    init(exercise: Exercise? = nil, sets: [WorkoutSet] = []) {
        self.exercise = exercise
        self.sets = sets
    }
}

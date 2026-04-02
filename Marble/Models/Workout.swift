import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var date: Date
    var duration: TimeInterval
    @Relationship(deleteRule: .cascade)
    var exerciseLogs: [ExerciseLog]

    init(name: String, date: Date = .now, duration: TimeInterval = 0, exerciseLogs: [ExerciseLog] = []) {
        self.name = name
        self.date = date
        self.duration = duration
        self.exerciseLogs = exerciseLogs
    }
}

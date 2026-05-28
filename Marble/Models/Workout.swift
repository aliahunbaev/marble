import Foundation
import SwiftData

@Model
final class Workout {
    var cloudID: String = UUID().uuidString
    var name: String = ""
    var date: Date = Date()
    var duration: TimeInterval = 0
    var notes: String?
    @Relationship(deleteRule: .cascade)
    var exerciseLogs: [ExerciseLog] = []

    init(name: String, date: Date = .now, duration: TimeInterval = 0, notes: String? = nil, exerciseLogs: [ExerciseLog] = []) {
        self.cloudID = UUID().uuidString
        self.name = name
        self.date = date
        self.duration = duration
        self.notes = notes
        self.exerciseLogs = exerciseLogs
    }
}

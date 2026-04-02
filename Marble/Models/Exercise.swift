import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var muscleGroup: String
    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    var logs: [ExerciseLog]

    init(name: String, muscleGroup: String) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.logs = []
    }
}

import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var name: String
    @Relationship(deleteRule: .nullify)
    var exercises: [Exercise]

    init(name: String, exercises: [Exercise] = []) {
        self.name = name
        self.exercises = exercises
    }
}

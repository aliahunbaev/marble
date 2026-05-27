import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var cloudID: String = UUID().uuidString
    var name: String = ""
    @Relationship(deleteRule: .nullify)
    var exercises: [Exercise] = []

    init(name: String, exercises: [Exercise] = []) {
        self.cloudID = UUID().uuidString
        self.name = name
        self.exercises = exercises
    }
}

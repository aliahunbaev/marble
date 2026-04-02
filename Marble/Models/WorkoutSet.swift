import Foundation
import SwiftData

@Model
final class WorkoutSet {
    var weight: Double
    var reps: Int
    var isCompleted: Bool

    init(weight: Double = 0, reps: Int = 0, isCompleted: Bool = false) {
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}

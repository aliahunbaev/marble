import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var muscleGroup: String
    /// Equipment category — Barbell / Dumbbell / Machine / Cable /
    /// Bodyweight. Defaulted to "" so rows that predate this field
    /// migrate cleanly (lightweight migration); `ExerciseSeed` backfills
    /// the stock library on next launch. Empty reads as "uncategorized"
    /// and only surfaces under the "All equipment" filter — that's the
    /// state of user-created custom exercises.
    var equipment: String = ""
    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    var logs: [ExerciseLog]

    init(name: String, muscleGroup: String, equipment: String = "") {
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.logs = []
    }
}

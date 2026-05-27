import Foundation
import SwiftData

@Model
final class TrackedLift {
    var cloudID: String = UUID().uuidString
    var exercise: Exercise?
    var metricType: String = "bestWeight"
    var displayOrder: Int = 0
    var manualBestWeight: Double?
    var manualBestWeightReps: Int?
    var manualOneRepMax: Double?
    var manualMaxVolume: Double?

    init(exercise: Exercise? = nil, metricType: String = "bestWeight", displayOrder: Int = 0) {
        self.cloudID = UUID().uuidString
        self.exercise = exercise
        self.metricType = metricType
        self.displayOrder = displayOrder
        self.manualBestWeight = nil
        self.manualBestWeightReps = nil
        self.manualOneRepMax = nil
        self.manualMaxVolume = nil
    }
}

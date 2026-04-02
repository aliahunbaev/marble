import Foundation
import SwiftData

@Model
final class TrackedLift {
    var exercise: Exercise?
    var metricType: String
    var displayOrder: Int
    var manualBestWeight: Double?
    var manualBestWeightReps: Int?
    var manualOneRepMax: Double?
    var manualMaxVolume: Double?

    init(exercise: Exercise? = nil, metricType: String = "bestWeight", displayOrder: Int = 0) {
        self.exercise = exercise
        self.metricType = metricType
        self.displayOrder = displayOrder
        self.manualBestWeight = nil
        self.manualBestWeightReps = nil
        self.manualOneRepMax = nil
        self.manualMaxVolume = nil
    }
}

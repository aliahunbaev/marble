import Foundation
import SwiftData

/// A single bodyweight log. Weight is always stored in lbs as the canonical
/// unit — the UI converts to kg at display time based on the user's weight
/// preference (same pattern as workout sets).
@Model
final class BodyweightEntry {
    var cloudID: String = UUID().uuidString
    var date: Date = Date()
    /// Weight in pounds (canonical storage unit).
    var weight: Double = 0
    var createdAt: Date = Date()

    init(weight: Double, date: Date = .now) {
        self.cloudID = UUID().uuidString
        self.weight = weight
        self.date = date
        self.createdAt = .now
    }
}

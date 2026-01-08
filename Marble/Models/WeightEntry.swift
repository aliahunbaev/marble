import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weight: Double // in lbs or kg based on user preference
    var notes: String?

    init(weight: Double, date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.notes = notes
    }
}

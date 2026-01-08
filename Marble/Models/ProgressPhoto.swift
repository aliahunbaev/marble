import Foundation
import SwiftData

@Model
final class ProgressPhoto {
    var id: UUID
    var date: Date
    var imageData: Data
    var notes: String?

    init(imageData: Data, date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.date = date
        self.imageData = imageData
        self.notes = notes
    }
}

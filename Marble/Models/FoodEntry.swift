import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var date: Date
    var name: String
    var servingSize: Double
    var servingUnit: String
    var portionDescription: String?

    // Macros per serving
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    // USDA FoodData Central ID (optional, for re-searching)
    var fdcId: String?

    init(
        name: String,
        servingSize: Double,
        servingUnit: String,
        portionDescription: String? = nil,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fdcId: String? = nil,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.name = name
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.portionDescription = portionDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fdcId = fdcId
    }

    var servingDisplayText: String {
        if let portion = portionDescription, !portion.isEmpty {
            return "\(portion) (\(Int(servingSize))g)"
        }
        return "\(Int(servingSize))g"
    }
}

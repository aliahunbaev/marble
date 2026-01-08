import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID
    var name: String
    var equipment: String // Barbell, Dumbbell, Machine, Cable, Bodyweight, Other
    var category: String // Chest, Back, Shoulders, Arms, Legs, Core, Cardio
    var muscleGroups: [String] // Primary and secondary muscles
    var isCustom: Bool // User-created vs pre-populated

    /// Display name in Strong format: "Bench Press (Barbell)"
    var displayName: String {
        "\(name) (\(equipment))"
    }

    init(
        name: String,
        equipment: String,
        category: String,
        muscleGroups: [String],
        isCustom: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.equipment = equipment
        self.category = category
        self.muscleGroups = muscleGroups
        self.isCustom = isCustom
    }
}

// MARK: - Codable for JSON loading

struct ExerciseData: Codable, Identifiable {
    let id: UUID
    let name: String
    let equipment: String
    let category: String
    let muscleGroups: [String]

    init(name: String, equipment: String, category: String, muscleGroups: [String]) {
        self.id = UUID()
        self.name = name
        self.equipment = equipment
        self.category = category
        self.muscleGroups = muscleGroups
    }
}

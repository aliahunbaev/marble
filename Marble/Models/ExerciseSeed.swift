import Foundation
import SwiftData

enum ExerciseSeed {
    static let exercises: [(name: String, muscleGroup: String)] = [
        ("Bench Press", "Chest"),
        ("Incline Bench Press", "Chest"),
        ("Dumbbell Fly", "Chest"),
        ("Overhead Press", "Shoulders"),
        ("Lateral Raise", "Shoulders"),
        ("Face Pull", "Shoulders"),
        ("Squat", "Legs"),
        ("Leg Press", "Legs"),
        ("Leg Extension", "Legs"),
        ("Leg Curl", "Legs"),
        ("Romanian Deadlift", "Legs"),
        ("Calf Raise", "Legs"),
        ("Deadlift", "Back"),
        ("Pull Up", "Back"),
        ("Barbell Row", "Back"),
        ("Lat Pulldown", "Back"),
        ("Cable Row", "Back"),
        ("Bicep Curl", "Arms"),
        ("Hammer Curl", "Arms"),
        ("Tricep Pushdown", "Arms"),
        ("Skull Crusher", "Arms"),
        ("Cable Crunch", "Core"),
        ("Hanging Leg Raise", "Core"),
        ("Russian Twist", "Core"),
    ]

    static let defaultTemplates: [(name: String, exerciseNames: [String])] = [
        ("Push", ["Bench Press", "Incline Bench Press", "Overhead Press", "Lateral Raise", "Tricep Pushdown"]),
        ("Pull", ["Pull Up", "Barbell Row", "Lat Pulldown", "Face Pull", "Bicep Curl", "Hammer Curl"]),
        ("Legs", ["Squat", "Leg Press", "Romanian Deadlift", "Leg Extension", "Leg Curl", "Calf Raise"]),
    ]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // Insert exercises
        var exerciseMap: [String: Exercise] = [:]
        for entry in exercises {
            let exercise = Exercise(name: entry.name, muscleGroup: entry.muscleGroup)
            context.insert(exercise)
            exerciseMap[entry.name] = exercise
        }

        // Insert default templates
        for template in defaultTemplates {
            let exercises = template.exerciseNames.compactMap { exerciseMap[$0] }
            let workoutTemplate = WorkoutTemplate(name: template.name, exercises: exercises)
            context.insert(workoutTemplate)
        }

        try? context.save()
    }
}

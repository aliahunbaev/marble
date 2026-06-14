import Foundation
import SwiftData

/// Seeds the local store with the universal exercise library on first
/// launch. Exercises are the building blocks the rest of the app
/// references by name (templates point at them, workouts log against
/// them, the library picker reads from this list) — without them, the
/// app can't function, so this runs unconditionally when the local
/// `Exercise` table is empty.
///
/// Default *templates* (Push/Pull/Legs) ARE seeded for fresh users,
/// but NOT here — see `TemplateSeed`. The naive "reseed whenever the
/// templates table is empty, every launch" approach caused three bugs
/// (reseed-after-deletion, duplicate-vs-cloud-restore, cloud
/// resurrection); `TemplateSeed.seedIfFreshStart` is built to avoid
/// all three via a persistent once-only flag and post-cloud-restore
/// timing. Exercise seeding stays unconditional because the app can't
/// function without the library.
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

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for entry in exercises {
            let exercise = Exercise(name: entry.name, muscleGroup: entry.muscleGroup)
            context.insert(exercise)
        }

        try? context.save()
    }
}

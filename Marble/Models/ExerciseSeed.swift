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
    /// Bumped whenever `exercises` gains new entries. The top-up path
    /// (existing installs) runs once per value of this key, so raising
    /// the suffix re-runs the reconcile and delivers the new movements
    /// to users who first launched on an older library.
    private static let didTopUpKey = "Marble.exerciseLibraryToppedUp.v2"

    static let exercises: [(name: String, muscleGroup: String, equipment: String)] = [
        // Chest
        ("Bench Press", "Chest", "Barbell"),
        ("Incline Bench Press", "Chest", "Barbell"),
        ("Dumbbell Fly", "Chest", "Dumbbell"),
        ("Cable Fly", "Chest", "Cable"),
        ("Chest Press", "Chest", "Machine"),
        ("Dip", "Chest", "Bodyweight"),
        ("Push Up", "Chest", "Bodyweight"),
        // Shoulders
        ("Overhead Press", "Shoulders", "Barbell"),
        ("Dumbbell Shoulder Press", "Shoulders", "Dumbbell"),
        ("Arnold Press", "Shoulders", "Dumbbell"),
        ("Lateral Raise", "Shoulders", "Dumbbell"),
        ("Rear Delt Fly", "Shoulders", "Machine"),
        ("Face Pull", "Shoulders", "Cable"),
        ("Shrug", "Shoulders", "Dumbbell"),
        // Back
        ("Deadlift", "Back", "Barbell"),
        ("Pull Up", "Back", "Bodyweight"),
        ("Chin Up", "Back", "Bodyweight"),
        ("Barbell Row", "Back", "Barbell"),
        ("Single-Arm Dumbbell Row", "Back", "Dumbbell"),
        ("Lat Pulldown", "Back", "Cable"),
        ("Cable Row", "Back", "Cable"),
        ("Seated Machine Row", "Back", "Machine"),
        // Legs
        ("Squat", "Legs", "Barbell"),
        ("Leg Press", "Legs", "Machine"),
        ("Hack Squat", "Legs", "Machine"),
        ("Leg Extension", "Legs", "Machine"),
        ("Leg Curl", "Legs", "Machine"),
        ("Romanian Deadlift", "Legs", "Barbell"),
        ("Calf Raise", "Legs", "Machine"),
        ("Hip Thrust", "Legs", "Barbell"),
        ("Lunge", "Legs", "Dumbbell"),
        ("Bulgarian Split Squat", "Legs", "Dumbbell"),
        ("Hip Abduction", "Legs", "Machine"),
        // Arms
        ("Bicep Curl", "Arms", "Dumbbell"),
        ("Hammer Curl", "Arms", "Dumbbell"),
        ("Preacher Curl", "Arms", "Machine"),
        ("Tricep Pushdown", "Arms", "Cable"),
        ("Overhead Tricep Extension", "Arms", "Cable"),
        ("Skull Crusher", "Arms", "Barbell"),
        ("Close-Grip Bench Press", "Arms", "Barbell"),
        // Core
        ("Cable Crunch", "Core", "Cable"),
        ("Hanging Leg Raise", "Core", "Bodyweight"),
        ("Russian Twist", "Core", "Bodyweight"),
        ("Plank", "Core", "Bodyweight"),
        ("Decline Sit Up", "Core", "Bodyweight"),
        ("Ab Wheel Rollout", "Core", "Bodyweight"),
    ]

    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        // Fresh install: seed the whole library, then mark the top-up
        // done so the reconcile path below never re-runs for this user.
        if existing.isEmpty {
            for entry in exercises {
                context.insert(Exercise(name: entry.name,
                                        muscleGroup: entry.muscleGroup,
                                        equipment: entry.equipment))
            }
            try? context.save()
            UserDefaults.standard.set(true, forKey: didTopUpKey)
            return
        }

        // Existing install: reconcile once. Insert library movements
        // added after this user first launched, and backfill `equipment`
        // on stock rows that predate the field. Gated by a version flag
        // (mirrors TemplateSeed) so a user who deletes a stock exercise
        // doesn't have it reappear on every launch.
        guard !UserDefaults.standard.bool(forKey: didTopUpKey) else { return }

        let byName = Dictionary(existing.map { ($0.name, $0) },
                                uniquingKeysWith: { first, _ in first })
        for entry in exercises {
            if let match = byName[entry.name] {
                if match.equipment.isEmpty { match.equipment = entry.equipment }
            } else {
                context.insert(Exercise(name: entry.name,
                                        muscleGroup: entry.muscleGroup,
                                        equipment: entry.equipment))
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: didTopUpKey)
    }
}

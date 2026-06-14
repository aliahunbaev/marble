import Foundation
import SwiftData

/// Seeds Push / Pull / Legs starter templates for a genuinely-fresh
/// user, so the Train tab isn't a cold empty canvas on first run.
///
/// Template seeding was removed once before (see ExerciseSeed's note)
/// because the naive version — reseed whenever the templates table is
/// empty, on every launch — caused three bugs. This implementation is
/// built specifically to avoid them:
///
///   1. Reseed-after-deletion. A persistent UserDefaults flag means
///      that once we've seeded (or decided not to), we never seed
///      again on this install — deleting all three starters does NOT
///      bring them back next launch.
///   2. Duplicate vs cloud-restored. `seedIfFreshStart` is only called
///      AFTER cloud restore has completed (the authenticated path) or
///      when there is no account at all (the skip path), and it bails
///      the moment it sees any existing template. A returning user's
///      cloud templates are already present, so we skip + mark done.
///   3. Cloud resurrection. We never reseed, so a deleted starter stays
///      deleted; its cloud delete propagates through the normal path.
enum TemplateSeed {
    private static let didSeedKey = "Marble.hasSeededStarterTemplates.v1"

    /// The three starter programs. Exercise names must match entries in
    /// `ExerciseSeed.exercises` exactly — they're resolved by name
    /// against the seeded library.
    static let starterTemplates: [(name: String, exercises: [String])] = [
        ("Push", ["Bench Press", "Overhead Press", "Incline Bench Press", "Lateral Raise", "Tricep Pushdown"]),
        ("Pull", ["Deadlift", "Pull Up", "Barbell Row", "Lat Pulldown", "Face Pull", "Bicep Curl"]),
        ("Legs", ["Squat", "Romanian Deadlift", "Leg Press", "Leg Curl", "Calf Raise"]),
    ]

    /// Seed the starter templates iff this is a fresh start. Idempotent
    /// and safe to call from multiple entry points (authenticated
    /// post-restore + the onboarding skip path) — the flag guarantees
    /// at-most-once.
    static func seedIfFreshStart(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didSeedKey) else { return }

        // If templates already exist (the user's own, or cloud-
        // restored), don't seed — but mark done so we never reconsider
        // on this install.
        let templateCount = (try? context.fetchCount(FetchDescriptor<WorkoutTemplate>())) ?? 0
        guard templateCount == 0 else {
            defaults.set(true, forKey: didSeedKey)
            return
        }

        // Resolve exercises by name from the seeded library.
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let byName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })

        for (order, tmpl) in starterTemplates.enumerated() {
            let exercises = tmpl.exercises.compactMap { byName[$0] }
            guard !exercises.isEmpty else { continue }
            let template = WorkoutTemplate(name: tmpl.name, exercises: exercises)
            template.displayOrder = order
            context.insert(template)
        }
        try? context.save()
        defaults.set(true, forKey: didSeedKey)
    }
}

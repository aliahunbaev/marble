import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var cloudID: String = UUID().uuidString
    var name: String = ""
    /// User-defined ordering for the Train tab template list. New
    /// templates default to 0; ordering ties are broken by insertion
    /// (SwiftData @Query sort stable order). Reorder UI updates this.
    var displayOrder: Int = 0

    /// The set of exercises in this template. Persisted as a SwiftData
    /// to-many relationship for cardinality + delete semantics. Order
    /// is NOT trustworthy on this property — SwiftData's change
    /// tracking for uninverted to-many relationships doesn't fire on
    /// pure reorder (same Exercise refs, different order). Read order
    /// via `orderedExercises` instead, which uses `exerciseNames` as
    /// the source of truth.
    @Relationship(deleteRule: .nullify)
    var exercises: [Exercise] = []

    /// Source of truth for exercise *order*. Plain `[String]` stored
    /// property — no relationship semantics, so reorders persist
    /// reliably. Aligns with how the cloud DTO already serializes
    /// templates. Writes here happen alongside `exercises =` so the
    /// two stay in sync; reads that care about order should go through
    /// `orderedExercises`.
    var exerciseNames: [String] = []

    /// Number of sets each exercise prescribes, parallel to
    /// `exerciseNames` by index. Templates are *structural* — they
    /// store the exercise + how many sets, never weights/reps (those
    /// come from your previous performance, surfaced live in the
    /// workout). Empty for legacy templates created before this
    /// existed; reads fall back to a default of 3. Always written
    /// alongside `exerciseNames` so the two stay index-aligned. See
    /// `orderedExercisesWithSetCounts()`.
    var setCounts: [Int] = []

    init(name: String, exercises: [Exercise] = []) {
        self.cloudID = UUID().uuidString
        self.name = name
        self.exercises = exercises
        self.exerciseNames = exercises.map(\.name)
        self.setCounts = exercises.map { _ in Self.defaultSetCount }
    }

    /// Default set count for an exercise with no stored value (new
    /// exercises, legacy templates).
    static let defaultSetCount = 3

    /// Exercises in display order. Resolves `exerciseNames` against the
    /// `exercises` relationship by name. Falls back to the raw
    /// relationship when `exerciseNames` is empty (legacy templates
    /// created before this property existed) so existing data
    /// continues to read correctly.
    func orderedExercises() -> [Exercise] {
        guard !exerciseNames.isEmpty else { return exercises }
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })
        return exerciseNames.compactMap { byName[$0] }
    }

    /// Exercises in display order paired with their prescribed set
    /// count. The single read path for both the editor (to rebuild
    /// rows) and `WorkoutSession.start` (to seed the right number of
    /// empty sets). `setCounts` is index-aligned with the ordered
    /// exercises; any missing/legacy entry defaults to 3.
    func orderedExercisesWithSetCounts() -> [(exercise: Exercise, setCount: Int)] {
        orderedExercises().enumerated().map { index, exercise in
            let count = index < setCounts.count ? setCounts[index] : Self.defaultSetCount
            return (exercise, max(1, count))
        }
    }
}

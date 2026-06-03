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

    init(name: String, exercises: [Exercise] = []) {
        self.cloudID = UUID().uuidString
        self.name = name
        self.exercises = exercises
        self.exerciseNames = exercises.map(\.name)
    }

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
}

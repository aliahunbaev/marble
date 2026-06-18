import SwiftUI
import SwiftData

/// Shared workout state, lifted out of ActiveWorkoutView so an in-progress
/// workout survives across tab navigation and view dismissal. Holds the
/// authoritative copy of name, entries, timer state, and rest timer.
///
/// Drives the mini-player pattern: when isExpanded == false but isActive
/// == true, ContentView renders a mini-bar above the tab bar. Tapping
/// the bar sets isExpanded = true → ActiveWorkoutView re-presents as a
/// fullScreenCover. Workout continues recording the whole time because
/// the timer lives here, not in any view.
@Observable
final class WorkoutSession {
    // MARK: - Workout state
    var name: String = "Workout"
    var entries: [ExerciseEntry] = []
    var startDate: Date = Date()
    var elapsedSeconds: Int = 0
    var sourceTemplate: WorkoutTemplate?

    /// True while a workout is in progress. Drives both the mini-bar
    /// visibility and the fullScreenCover presentation in ContentView.
    var isActive: Bool = false

    /// True when the workout is displayed full-screen. False when the
    /// user has minimized it (mini-bar visible, tabs interactive).
    var isExpanded: Bool = false

    /// Rest timer instance — lives here so it keeps counting down even
    /// if the user minimizes the workout to navigate other tabs.
    var restTimer = RestTimerState()

    private var timer: Timer?

    // MARK: - Computed

    /// "1:23" / "12:34" formatted elapsed time. Used on the workout
    /// screen itself and on the mini-bar.
    var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Lifecycle

    /// Start a fresh workout. Pass `template` to pre-populate exercises
    /// with the template's prescribed number of empty sets each; pass
    /// nil for an empty workout the user fills in.
    func start(template: WorkoutTemplate? = nil) {
        sourceTemplate = template
        if let template {
            name = template.name
            entries = template.orderedExercisesWithSetCounts().map { pair in
                ExerciseEntry(
                    exercise: pair.exercise,
                    sets: (0..<pair.setCount).map { _ in EditableSet() }
                )
            }
        } else {
            name = "Workout"
            entries = []
        }
        startDate = Date()
        elapsedSeconds = 0
        isActive = true
        isExpanded = true
        startTimer()
        saveSnapshot()
    }

    /// Collapse the workout to the mini-bar without ending it. Tabs
    /// become interactive; the timer keeps running.
    func minimize() {
        isExpanded = false
    }

    /// Re-present the workout full-screen from the mini-bar.
    func expand() {
        isExpanded = true
    }

    /// End the workout entirely — tear down timer + clear state. Called
    /// after a successful save OR a discard.
    func end() {
        timer?.invalidate()
        timer = nil
        restTimer.stop()
        isActive = false
        isExpanded = false
        sourceTemplate = nil
        entries = []
        name = "Workout"
        elapsedSeconds = 0
        UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
    }

    /// Resume the timer without resetting startDate. Used by the undo-
    /// finish flow (back chevron on closing ritual).
    func resumeTimer() {
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(self.startDate))
        }
    }

    /// Stop the workout timer (but not the rest timer). Called by the
    /// finish flow before the closing ritual displays.
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Persistence
    //
    // Save the active workout's state to UserDefaults so it survives
    // the app being backgrounded or killed. On launch we re-hydrate
    // by ID-looking-up the exercise references through the
    // ModelContext, then recompute elapsedSeconds from real wall-clock
    // time (so a workout left running while the app was closed for
    // 20 minutes resumes with the correct elapsed timer instead of
    // jumping back to where it was when we last saved). Clearing the
    // saved blob on `end()` ensures we don't accidentally restore a
    // finished workout.

    private static let persistenceKey = "Marble.WorkoutSession.v1"

    private struct PersistedEntry: Codable {
        let id: UUID
        let exerciseName: String
        let sets: [EditableSet]
    }

    private struct PersistedState: Codable {
        let name: String
        let entries: [PersistedEntry]
        let startDate: Date
        let isExpanded: Bool
        let sourceTemplateName: String?
    }

    /// Snapshot the live session to UserDefaults. Call after any
    /// meaningful state change (we wire it into start/end and also
    /// at app-backgrounding to catch in-flight edits).
    func saveSnapshot() {
        guard isActive else {
            UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
            return
        }
        let persisted = PersistedState(
            name: name,
            entries: entries.map { entry in
                PersistedEntry(
                    id: entry.id,
                    exerciseName: entry.exercise.name,
                    sets: entry.sets
                )
            },
            startDate: startDate,
            isExpanded: isExpanded,
            sourceTemplateName: sourceTemplate?.name
        )
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    /// Attempt to rehydrate the session from a saved snapshot.
    /// Returns true if a workout was restored (so the caller knows
    /// to present it). No-op if nothing's saved or the saved
    /// exercises can no longer be resolved.
    @discardableResult
    func restoreSnapshot(context: ModelContext) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let persisted = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return false
        }

        // Resolve exercise references by name. We could use
        // PersistentIdentifier here, but name lookup is simpler and
        // more forgiving across schema migrations / store rebuilds.
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        guard let allExercises = try? context.fetch(exerciseDescriptor) else {
            return false
        }
        let byName = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.name, $0) })

        let resolved = persisted.entries.compactMap { saved -> ExerciseEntry? in
            guard let exercise = byName[saved.exerciseName] else { return nil }
            return ExerciseEntry(id: saved.id, exercise: exercise, sets: saved.sets)
        }
        // If we couldn't find ANY of the saved exercises (e.g. store
        // was wiped), don't restore an empty husk — discard the
        // snapshot instead.
        guard !resolved.isEmpty || persisted.entries.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
            return false
        }

        // Source template lookup (optional — workout still works
        // without it).
        if let templateName = persisted.sourceTemplateName {
            let templateDescriptor = FetchDescriptor<WorkoutTemplate>()
            if let templates = try? context.fetch(templateDescriptor) {
                sourceTemplate = templates.first { $0.name == templateName }
            }
        }

        name = persisted.name
        entries = resolved
        startDate = persisted.startDate
        // Recompute elapsed from real time so the timer's correct
        // even if the app was closed for hours.
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(persisted.startDate)))
        isActive = true
        isExpanded = persisted.isExpanded
        startTimer()
        return true
    }
}

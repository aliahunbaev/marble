import SwiftUI

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

    /// Start a fresh workout. Pass `template` to pre-populate exercises +
    /// 3 empty sets each; pass nil for an empty workout the user fills in.
    func start(template: WorkoutTemplate? = nil) {
        sourceTemplate = template
        if let template {
            name = template.name
            entries = template.orderedExercises().map { exercise in
                ExerciseEntry(exercise: exercise, sets: [
                    EditableSet(), EditableSet(), EditableSet()
                ])
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
}

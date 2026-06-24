import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Shared workout state — name/entries/timer all live here so the
    /// workout survives across tab navigation, minimize-to-mini-bar, etc.
    @Environment(WorkoutSession.self) private var session

    // View-local presentation state (sheets, alerts) — distinct from
    // workout data, doesn't need to survive minimization.
    @State private var showingLibrary = false
    @State private var showingRestTimer = false
    @State private var showingDiscardAlert = false
    @State private var completedWorkout: Workout?
    @State private var showingSummary = false
    @State private var showingPhotoCapture = false
    @State private var capturedPhoto: ProgressPhoto?
    @State private var showingEmptyFinishAlert = false
    /// When set, the next exercise picked from the library replaces this
    /// entry instead of being toggled into the entries list. Cleared
    /// after a successful replace.
    @State private var replacingEntryID: UUID?
    /// Shared collapse state across all exercise cells. Bridge sets
    /// it on drag start (synchronously, no animation — so the
    /// snapshot is small) and clears it on drag end (with animation).
    @StateObject private var reorderState = ExerciseReorderState()

    @AppStorage("defaultRestTimer") private var defaultRestTimer: Int = 90
    @AppStorage("restTimerAutoStart") private var restTimerAutoStart: Bool = true

    /// Auto-start the rest countdown when a set is marked complete.
    /// No-op when the user has switched auto-start off in Settings.
    /// `entryID`/`setID` anchor the inline countdown bar directly beneath
    /// the set that was just completed.
    private func startRestTimer(forExercise entryID: UUID, set setID: UUID) {
        guard restTimerAutoStart else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            session.restTimer.start(
                duration: defaultRestTimer,
                originExerciseID: entryID,
                originSetID: setID
            )
        }
    }

    /// Cancel the rest timer if it was auto-started by this exact set —
    /// unchecking that set means the rest no longer applies. A timer the
    /// user started manually (or from a different set) is left alone.
    private func stopRestTimer(ifStartedBy setID: UUID) {
        guard session.restTimer.originSetID == setID else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            session.restTimer.skip()
        }
    }

    var body: some View {
        if showingSummary, let workout = completedWorkout {
            ClosingRitualView(workout: workout, onBack: { undoFinish(workout: workout) })
                .onDisappear {
                    // Only dismiss the outer cover if the user actually
                    // completed the ritual. Back-chevron path clears
                    // completedWorkout before dismount, so we stay inside
                    // the workout view in that case.
                    if completedWorkout != nil {
                        session.end()
                        dismiss()
                    }
                }
        } else {
            workoutContentView
        }
    }

    /// Undo the finish: delete the just-saved workout from the model
    /// context, resume the timer (preserving the original startDate so
    /// elapsed time keeps accumulating), and drop back to the workout
    /// content view. Entries are still in the session, so they reappear.
    private func undoFinish(workout: Workout) {
        let cloudID = workout.cloudID
        // Cascade-delete any photos taken during the just-finished
        // workout (the user is reverting the whole save, so the
        // pump pic + library imports go with it).
        PhotoStorageService.shared.deletePhotosLinkedToWorkout(
            cloudID: cloudID,
            context: modelContext
        )
        modelContext.delete(workout)
        try? modelContext.save()
        Task { await CloudSyncService.shared.deleteWorkout(cloudID: cloudID) }

        session.resumeTimer()

        completedWorkout = nil
        withAnimation { showingSummary = false }
    }

    private var workoutContentView: some View {
        @Bindable var session = session

        return ZStack(alignment: .top) {
            unifiedCanvas(session: session)

            // Floating glass buttons over the workout content
            floatingToolbar
        }
        .background(Color("marbleBackground"))
        .marbleKeyboardDismiss()
        .sheet(isPresented: $showingLibrary, onDismiss: {
            replacingEntryID = nil
        }) {
            let replacingName: String? = {
                guard let id = replacingEntryID,
                      let entry = session.entries.first(where: { $0.id == id })
                else { return nil }
                return entry.exercise.name
            }()
            ExerciseLibraryView(
                onPick: { picked in
                    if let replaceID = replacingEntryID, let exercise = picked.first {
                        // Replace mode: swap in place, preserve sets.
                        if let idx = session.entries.firstIndex(where: { $0.id == replaceID }) {
                            let preservedSets = session.entries[idx].sets
                            session.entries[idx] = ExerciseEntry(
                                exercise: exercise,
                                sets: preservedSets
                            )
                        }
                    } else {
                        // Add mode: append all picked. Each appended
                        // exercise gets the default 3 empty sets.
                        for exercise in picked {
                            let entry = ExerciseEntry(exercise: exercise, sets: [
                                EditableSet(), EditableSet(), EditableSet()
                            ])
                            session.entries.append(entry)
                        }
                    }
                },
                replacingExerciseName: replacingName
            )
        }
        .sheet(isPresented: $showingRestTimer) {
            RestTimerModal(state: session.restTimer)
        }
        .marbleDialog(
            "Discard this workout?",
            message: "All progress will be lost.",
            isPresented: $showingDiscardAlert,
            buttons: [
                .destructive("Discard") {
                    session.end()
                    dismiss()
                },
                .cancel(),
            ]
        )
        .marbleDialog(
            "No sets completed",
            message: "There's nothing to save yet. Discard the workout, or keep going.",
            isPresented: $showingEmptyFinishAlert,
            buttons: [
                .destructive("Discard") {
                    session.end()
                    dismiss()
                },
                .cancel("Keep going"),
            ]
        )
    }

    // MARK: - List Rows

    /// Workout name + duration as the first list row. Extra top padding
    /// gives breathing room below the floating toolbar that overlays.
    @ViewBuilder
    private func workoutHeaderRow(session: WorkoutSession) -> some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 6) {
            TextField("Workout", text: $session.name)
                .font(.marbleBody(32))
                .foregroundStyle(Color("marblePrimary"))

            Text(session.formattedTime)
                .font(.marbleMono(13))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 88)
        .padding(.bottom, 32)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// Hairline row between exercises — replaces the visual separation
    /// that Sections used to provide. Lives in the List as a regular
    /// row so it scrolls with content.
    private var exerciseDividerRow: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.06))
            .frame(height: 0.5)
            .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// Normal expanded rendering — header + sets + +SET per exercise,
    /// with hairline dividers between exercises.
    @ViewBuilder
    private func expandedExercisesContent(entries: Binding<[ExerciseEntry]>) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, $entry in
            if index > 0 {
                exerciseDividerRow
            }
            exerciseHeaderRow(entry: $entry)
            ForEach($entry.sets) { $set in
                setRowItem(entry: $entry, set: $set)
            }
            addSetRow(entry: $entry)
        }
    }

    /// Single canvas — workout header + reorderable exercise list +
    /// add-exercise row. Each exercise cell observes `reorderState`
    /// and renders expanded or compact in place. Long-press on any
    /// cell triggers reorder (UCV bridge's recognizer), all cells
    /// collapse to titles with animation, drag to reorder, release
    /// to expand back. One continuous gesture. No mode switch, no
    /// DONE button.
    @ViewBuilder
    private func unifiedCanvas(session: WorkoutSession) -> some View {
        @Bindable var session = session
        // UIKit-backed scroll view so the ReorderableList bridge can
        // anchor the dragged cell at the touch point — SwiftUI's
        // built-in ScrollView reverts our contentInset writes within
        // one runloop tick (proven in logs). See BackedScrollView.swift.
        BackedScrollView {
            VStack(alignment: .leading, spacing: 0) {
                workoutHeaderInline(session: session)

                ReorderableList(
                    items: session.entries,
                    itemID: { $0.id.uuidString },
                    onReorder: { newOrder in session.entries = newOrder },
                    onTap: nil,
                    onDragStart: {
                        // Animate the collapse so cells flow smoothly
                        // into title-only instead of snapping. The
                        // bridge polls cell.bounds.height until the
                        // animation has actually compacted the cell
                        // past 80pt before calling beginInteractive
                        // MovementForItem, so UCV's snapshot still
                        // captures the fully-compact cell (no
                        // mid-animation snapshot).
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            reorderState.isReordering = true
                        }
                    },
                    onDragEnd: {
                        // Animated. UCV's drop is already done by
                        // this point; nothing else is running in
                        // parallel, so the spring animates cleanly.
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            reorderState.isReordering = false
                        }
                    },
                    // Include each entry's set IDs so adding/removing
                    // a set within any cell forces that cell to
                    // reconfigure with the new content. Without this,
                    // UCV reuses the cached cell (same exercise ID,
                    // no diff) and the visible row list is stale even
                    // though the underlying data changed.
                    // Only the reorder state drives a full reconfigure
                    // now. Set add/remove/edit re-render the cell in
                    // place via Observation (ExerciseCell observes the
                    // session) so SwiftUI animates the rows natively —
                    // no rebuild, no "space appears late" jump.
                    reconfigureKey: AnyHashable("\(reorderState.isReordering)")
                ) { entry in
                    ExerciseCell(
                        entry: entry,
                        entries: $session.entries,
                        reorderState: reorderState,
                        onReplace: { entryID in
                            replacingEntryID = entryID
                            showingLibrary = true
                        },
                        onComplete: { entryID, setID in
                            startRestTimer(forExercise: entryID, set: setID)
                        },
                        onUncomplete: { _, setID in
                            stopRestTimer(ifStartedBy: setID)
                        },
                        onRestTap: { showingRestTimer = true }
                    )
                    // Inject the session so the cell can observe set
                    // changes and re-render in place.
                    .environment(session)
                }

                addExerciseInline
            }
            .padding(.bottom, 140)
        }
        .background(Color("marbleBackground"))
    }

    /// Workout name + duration as a flat top-of-canvas header.
    @ViewBuilder
    private func workoutHeaderInline(session: WorkoutSession) -> some View {
        @Bindable var session = session
        VStack(alignment: .leading, spacing: 6) {
            TextField("Workout", text: $session.name)
                .font(.marbleBody(32))
                .foregroundStyle(Color("marblePrimary"))

            Text(session.formattedTime)
                .font(.marbleMono(13))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 88)
        .padding(.bottom, 32)
    }

    /// + EXERCISE button at the bottom of the list.
    private var addExerciseInline: some View {
        Button {
            showingLibrary = true
        } label: {
            HStack(spacing: 6) {
                Text("+")
                Text("EXERCISE").tracking(1)
            }
            .marbleSecondaryButton()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    /// Exercise header as a regular List row (not a Section header) so
    /// it scrolls naturally instead of getting List's default
    /// pinned-to-top behavior.
    @ViewBuilder
    private func exerciseHeaderRow(entry: Binding<ExerciseEntry>) -> some View {
        // Capture the ID at body-evaluation time so the Menu actions
        // don't hold the Binding into the closure (the SwiftUI footgun
        // that crashed Remove — the binding becomes invalid the moment
        // session.entries is mutated).
        let entryID = entry.wrappedValue.id
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(entry.wrappedValue.exercise.name)
                    .font(.marbleBody(22))
                    .foregroundStyle(Color("marblePrimary"))

                Spacer()

                Menu {
                    Button {
                        DispatchQueue.main.async {
                            replacingEntryID = entryID
                            showingLibrary = true
                        }
                    } label: {
                        Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        DispatchQueue.main.async {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                session.entries.removeAll { $0.id == entryID }
                            }
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .marbleGlassCapsule(size: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Column headers — widths track SetRowView field sizes.
            HStack(spacing: 14) {
                Text("SET").frame(width: 32, alignment: .center)
                Spacer()
                Text("LBS").frame(width: 100, alignment: .center)
                Text("REPS").frame(width: 100, alignment: .center)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .light))
                    .frame(width: 44, alignment: .center)
            }
            .font(.marbleMono(11))
            .tracking(1.5)
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    /// + SET row at the end of each exercise's set list.
    private func addSetRow(entry: Binding<ExerciseEntry>) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                entry.wrappedValue.sets.append(EditableSet())
            }
        } label: {
            HStack(spacing: 6) {
                Text("+")
                Text("SET").tracking(1)
            }
            .marbleSecondaryButton()
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func setRowItem(
        entry: Binding<ExerciseEntry>,
        set: Binding<EditableSet>
    ) -> some View {
        let index = entry.wrappedValue.sets.firstIndex(where: { $0.id == set.wrappedValue.id }) ?? 0
        let prev = PreviousPerformance.previousComponents(
            for: entry.wrappedValue.exercise,
            setIndex: index,
            context: modelContext
        )
        // Cascade-fill: prefer the closest non-empty (weight, reps)
        // pair ABOVE this set in the current workout, fall back to
        // the previous workout's value.
        let cascade = priorFilledValues(in: entry.wrappedValue.sets, forSetAt: index)
        let placeholderWeight = cascade.weight ?? prev.weight
        let placeholderReps = cascade.reps ?? prev.reps

        SetRowView(
            setNumber: index + 1,
            weight: set.weight,
            reps: set.reps,
            isCompleted: set.isCompleted,
            previousWeight: placeholderWeight,
            previousReps: placeholderReps,
            showCheckmark: true,
            onComplete: nil
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(
            // Subtle warm wash on completed rows. Reads as "settled /
            // polished marble" instead of "selected spreadsheet row."
            set.wrappedValue.isCompleted
                ? Color("marblePrimary").opacity(0.04)
                : Color.clear
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // Text-only label (no trash icon) on the system red background.
            // Cleaner, more editorial than the default labeled-with-icon.
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    entry.wrappedValue.sets.removeAll { $0.id == set.wrappedValue.id }
                }
            } label: {
                Text("Delete")
            }
        }
    }

    private var addExerciseRow: some View {
        Button {
            showingLibrary = true
        } label: {
            HStack(spacing: 6) {
                Text("+")
                Text("EXERCISE").tracking(1)
            }
            .marbleSecondaryButton()
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 120, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Floating Toolbar (iOS-26 liquid glass)

    private var floatingToolbar: some View {
        normalToolbar
    }

    private var normalToolbar: some View {
        HStack(spacing: 10) {
            // Minimize → mini-bar.
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                session.minimize()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .marbleGlassCapsule(size: 44)
            }
            .buttonStyle(.plain)

            FloatingRestTimerButton(state: session.restTimer) {
                showingRestTimer = true
            }

            Spacer()

            // Workout-level menu — discard only now. Reorder is
            // triggered via long-press on an exercise name (no
            // dedicated menu button).
            Menu {
                Button(role: .destructive) {
                    showingDiscardAlert = true
                } label: {
                    Label("Discard workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .medium))
                    .marbleGlassCapsule(size: 44)
            }
            .buttonStyle(.plain)

            Button {
                attemptFinish()
            } label: {
                Text("FINISH")
                    .marbleGlassPill()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Gate FINISH on having at least one completed set.
    private func attemptFinish() {
        let completedCount = session.entries.reduce(0) { acc, entry in
            acc + entry.sets.filter(\.isCompleted).count
        }
        if completedCount == 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showingEmptyFinishAlert = true
        } else {
            finishWorkout()
        }
    }

    // MARK: - Actions

    private func finishWorkout() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        session.stopTimer()
        session.restTimer.stop()

        let duration = Date().timeIntervalSince(session.startDate)
        let workoutName = session.name.trimmingCharacters(in: .whitespaces)

        var exerciseLogs: [ExerciseLog] = []

        for entry in session.entries {
            var workoutSets: [WorkoutSet] = []
            for set in entry.sets where set.isCompleted {
                let weight = Double(set.weight) ?? 0
                let reps = Int(set.reps) ?? 0
                let workoutSet = WorkoutSet(weight: weight, reps: reps, isCompleted: true)
                modelContext.insert(workoutSet)
                workoutSets.append(workoutSet)
            }

            if !workoutSets.isEmpty {
                let log = ExerciseLog(exercise: entry.exercise, sets: workoutSets)
                modelContext.insert(log)
                exerciseLogs.append(log)
            }
        }

        let workout = Workout(
            name: workoutName.isEmpty ? "Workout" : workoutName,
            date: session.startDate,
            duration: duration,
            exerciseLogs: exerciseLogs
        )
        modelContext.insert(workout)
        try? modelContext.save()
        CloudSyncService.shared.uploadWorkout(workout)

        completedWorkout = workout
        withAnimation {
            showingSummary = true
        }
    }
}

#Preview {
    ActiveWorkoutView()
        .environment(WorkoutSession())
        .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}

// MARK: - Exercise reorder state

/// Shared across all exercise cells in a workout / template editor.
/// Bridge sets `isReordering = true` (no animation) when drag begins
/// so the cells re-render compact before UCV takes its snapshot.
/// Cleared with animation on drag end so the expand reflow is smooth.
final class ExerciseReorderState: ObservableObject {
    @Published var isReordering: Bool = false
}

// MARK: - Exercise cell

/// One exercise inside the unified canvas. Renders the full expanded
/// view (header + sets + +SET) by default; collapses to a single
/// title row while `reorderState.isReordering` is true. The transition
/// animates via the spring set on the SwiftUI .animation modifier so
/// all cells visually compact together when any one is being dragged.
struct ExerciseCell: View {
    @Environment(\.modelContext) private var modelContext
    /// The live workout's session, injected into the cell's environment
    /// by ActiveWorkoutView (nil for the template editor, which has no
    /// session). Reading `observedSession?.entries` in `body` registers
    /// an Observation dependency on the @Observable session, so the
    /// hosting cell re-renders IN PLACE when a set is added/removed/
    /// edited — that lets SwiftUI animate the row insert/remove natively
    /// (siblings stay put, the space opens/closes), instead of the UCV
    /// rebuilding the whole cell (which couldn't animate and looked like
    /// the space appeared a beat after the content). The template editor
    /// keeps the reconfigure-key path since it has no session to observe.
    @Environment(WorkoutSession.self) private var observedSession: WorkoutSession?

    let entry: ExerciseEntry
    @Binding var entries: [ExerciseEntry]
    @ObservedObject var reorderState: ExerciseReorderState
    let onReplace: (UUID) -> Void
    /// Fires when a set in this exercise is marked complete — passes this
    /// exercise entry's id and the completed set's id, so the parent can
    /// anchor the rest timer right beneath that set.
    let onComplete: ((UUID, UUID) -> Void)?
    /// Fires when a set is unchecked — passes the entry id and set id so
    /// the parent can cancel a rest timer that set had started.
    var onUncomplete: ((UUID, UUID) -> Void)? = nil
    /// Opens the rest-timer modal (tapped on the inline countdown bar).
    var onRestTap: (() -> Void)? = nil
    /// Show the checkmark column on each set row. False for templates
    /// (which are structural — no "completed" concept). True for live
    /// workouts.
    var showCheckmark: Bool = true
    /// Structural mode (templates): set rows show only the set number,
    /// no weight/reps fields, no checkmark, no previous-performance
    /// ghost. Templates store exercise + set count; the numbers come
    /// from previous performance, surfaced live in the workout.
    var structural: Bool = false

    /// The entry as it currently exists in `entries`. The cell's
    /// `entry` parameter is captured by value at the time the cell
    /// was last reconfigured — its `sets` array is a stale snapshot.
    /// Reading mutating fields (weight / reps / isCompleted / sets
    /// count) through `live` instead of `entry` ensures the cell's
    /// body re-evaluates against the latest binding source whenever
    /// entries changes, so typed values persist, the checkmark flips
    /// when tapped, and the +SET / swipe-to-delete actions stay in
    /// sync with the visible state. Falls back to the captured value
    /// if the entry was just removed (mid-animation only).
    private var live: ExerciseEntry {
        entries.first(where: { $0.id == entry.id }) ?? entry
    }

    /// Cells collapse to title-only during drag. UCV's interactive
    /// movement snapshots the cell synchronously when it begins —
    /// but the bridge defers `beginInteractiveMovementForItem` to
    /// the next runloop tick AFTER setting `isReordering = true`,
    /// so SwiftUI has time to render the compact form first. The
    /// snapshot is then small (just the title row), UCV centers
    /// that small snapshot on the finger with minimal offset, and
    /// the cell stays where the finger is.
    var body: some View {
        // Register an Observation dependency on the session's entries so
        // this cell re-renders in place on any set change (see the
        // observedSession doc above). No-op for the template editor.
        _ = observedSession?.entries
        return VStack(alignment: .leading, spacing: 0) {
            titleBar

            if !reorderState.isReordering {
                Group {
                    // Templates render a stack of set "boxes" — no
                    // fields, just the count. The stack's height
                    // visualizes volume and keeps parity with the
                    // workout's row layout.
                    if structural {
                        structuralSetsSection
                    } else {
                        setsSection
                    }
                }
                .transition(.opacity)
            }

            Rectangle()
                .fill(Color("marblePrimary").opacity(0.08))
                .frame(height: 0.5)
        }
    }

    /// Structural (template) set list — a stack of full-width set
    /// "boxes," each a tactile object carrying just its set number.
    /// The stack's height visualizes how many sets, and it keeps the
    /// row layout / +SET / swipe-to-delete parity with the workout.
    /// No fields, no checkmark, no previous-performance ghost — a
    /// template stores only the count. Swiping away the last set
    /// removes the exercise (handled in `removeSet`).
    private var structuralSetsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETS")
                .font(.marbleMono(11))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                ForEach(setsBinding) { $set in
                    let index = live.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                    SwipeToDismissRow(onDelete: {
                        let setID = set.id
                        withAnimation(.easeOut(duration: 0.25)) {
                            removeSet(id: setID)
                        }
                    }) {
                        HStack {
                            Text("\(index + 1)")
                                .font(.marbleBody(20))
                                .foregroundStyle(Color("marblePrimary").opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color("marblePrimary").opacity(0.05))
                        )
                        .padding(.horizontal, 20)
                    }
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Plain ease, no spring overshoot (the bounce), at a
                // duration close to the collection view's own resize so
                // the rows and the cell height move up/down together.
                withAnimation(.easeOut(duration: 0.25)) {
                    addSet()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("+")
                    Text("SET").tracking(1)
                }
                .marbleSecondaryButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    /// Title bar — name + ⋯ menu. Menu hides during reorder so the
    /// title can sit cleanly alongside its siblings. Padding stays
    /// constant in both modes so the title doesn't shift vertically.
    private var titleBar: some View {
        HStack {
            Text(entry.exercise.name)
                .font(.marbleBody(22))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()

            Menu {
                Button {
                    DispatchQueue.main.async {
                        onReplace(entry.id)
                    }
                } label: {
                    Label("Replace exercise", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    let entryID = entry.id
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            entries.removeAll { $0.id == entryID }
                        }
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .marbleGlassCapsule(size: 32)
            }
            .buttonStyle(.plain)
            .opacity(reorderState.isReordering ? 0 : 1)
            .allowsHitTesting(!reorderState.isReordering)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    /// Sets section — column headers + sets + +SET button. Conditional
    /// rendering with `.transition(.opacity)` so SwiftUI handles the
    /// fade and adjacent views slide up automatically when this
    /// section is removed.
    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            HStack(spacing: 14) {
                Text("SET").frame(width: 32, alignment: .center)
                Spacer()
                Text("LBS").frame(width: 100, alignment: .center)
                Text("REPS").frame(width: 100, alignment: .center)
                if showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .light))
                        .frame(width: 44, alignment: .center)
                }
            }
            .font(.marbleMono(11))
            .tracking(1.5)
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Native SwiftUI List for the set rows — its built-in row
            // insert/delete animation is smooth and bounce-free. The
            // hand-rolled VStack version had to choreograph the reflow
            // itself and ended up bouncing / overlapping; List just does
            // it right (this is the build-8 behavior we're restoring).
            // `.scrollDisabled` plus an EXACT measured height (each row
            // is 48pt field + 2×6 padding = 60pt) make it lay out
            // statically inside the UCV-bridged exercise cell instead of
            // trying to fill/scroll. Only the live workout uses this —
            // templates render the structural boxes (structuralSetsSection),
            // so the old "List blanks out in the template's plain
            // ScrollView" problem no longer applies.
            List {
                ForEach(setsBinding) { $set in
                    let index = live.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                    let prev = PreviousPerformance.previousComponents(
                        for: live.exercise,
                        setIndex: index,
                        context: modelContext
                    )
                    // Cascade placeholder: prefer the closest filled
                    // set ABOVE this one in the current workout (so
                    // typing 225 × 8 in set 1 shows 225/8 as the ghost
                    // text for sets 2, 3…). Falls back to the previous
                    // workout's value if nothing's been typed yet.
                    let cascade = cascadeFill(forSetAt: index)
                    let placeholderWeight = cascade.weight ?? prev.weight
                    let placeholderReps = cascade.reps ?? prev.reps
                    SwipeToDeleteRow(
                        onDelete: {
                            let setID = set.id
                            // Critically damped (no overshoot) so the rows
                            // flow up smoothly with no bounce.
                            withAnimation(.spring(response: 0.35, dampingFraction: 1)) {
                                removeSet(id: setID)
                            }
                        }
                    ) {
                        SetRowView(
                            setNumber: index + 1,
                            weight: $set.weight,
                            reps: $set.reps,
                            isCompleted: $set.isCompleted,
                            previousWeight: placeholderWeight,
                            previousReps: placeholderReps,
                            showCheckmark: showCheckmark,
                            onComplete: onComplete.map { handler in { handler(entry.id, set.id) } },
                            onUncomplete: onUncomplete.map { handler in { handler(entry.id, set.id) } }
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            set.isCompleted
                                ? Color("marblePrimary").opacity(0.04)
                                : Color("marbleBackground")
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    // Inline rest bar, slotted directly beneath the set you
                    // just completed (and above the next set). Lives as its
                    // own List row so the surrounding rows reflow around it.
                    if let rest = observedSession?.restTimer, rest.isActive,
                       rest.originExerciseID == entry.id, rest.originSetID == set.id {
                        InlineRestTimerBar(
                            state: rest,
                            onTap: { onRestTap?() },
                            onSkip: { withAnimation(.easeInOut(duration: 0.2)) { rest.skip() } }
                        )
                        .frame(height: Self.restBarHeight)
                        .padding(.horizontal, 20)
                        // Symmetric vertical padding so the bar sits
                        // equidistant from the set above and below, matching
                        // the set rows' rhythm (48pt content + 6 + 6 = 60pt,
                        // a 12pt gap on each side).
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: restBarVisible)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            // Exact height = rows × 60pt so List lays out statically
            // (no fill/scroll) inside the self-sizing exercise cell.
            // Add the rest bar's row height when it's slotted in.
            .frame(height: CGFloat(live.sets.count) * 60
                   + (restBarVisible ? Self.restBarHeight + 12 : 0))

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // Critically damped (dampingFraction 1) — same spring
                // timing as before but with no overshoot, so the new
                // row eases in and settles without the little bounce.
                withAnimation(.spring(response: 0.4, dampingFraction: 1)) {
                    addSet()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("+")
                    Text("SET").tracking(1)
                }
                .marbleSecondaryButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    /// Height of the inline rest bar's content (excludes its row padding).
    static let restBarHeight: CGFloat = 40

    /// True when the inline rest bar should render inside this exercise —
    /// the rest is running, it was started here, and the originating set
    /// still exists (so a deleted set doesn't leave a phantom gap).
    private var restBarVisible: Bool {
        guard let rest = observedSession?.restTimer, rest.isActive,
              rest.originExerciseID == entry.id, let sid = rest.originSetID
        else { return false }
        return live.sets.contains { $0.id == sid }
    }

    /// Binding into the SwiftData-backed entries array for *this*
    /// entry's sets. Reads through `entries` (not the captured
    /// `entry`) so the getter returns the latest values — typed
    /// weights/reps and tapped checkmarks all flow back through
    /// here, and the downstream Bindings created by ForEach($)
    /// see the updated state on the next read.
    private var setsBinding: Binding<[EditableSet]> {
        Binding(
            get: {
                entries.first(where: { $0.id == entry.id })?.sets ?? entry.sets
            },
            set: { newSets in
                guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
                entries[idx].sets = newSets
            }
        )
    }

    // Plain mutations — the animation lives at the call sites (the
    // +SET button and the swipe's onDelete), matching the original
    // workout behavior where the spring reflow felt right.
    private func addSet() {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].sets.append(EditableSet())
    }

    private func removeSet(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        // In a template, swiping away the last set removes the whole
        // exercise — a template should never hold a 0-set exercise.
        // Live workouts keep the exercise even at zero sets (you might
        // be mid-session and about to re-add).
        if structural && entries[idx].sets.count <= 1 {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            entries.remove(at: idx)
        } else {
            entries[idx].sets.removeAll { $0.id == id }
        }
    }

    private func cascadeFill(forSetAt index: Int) -> (weight: String?, reps: String?) {
        priorFilledValues(in: live.sets, forSetAt: index)
    }
}

// MARK: - Swipe to delete (custom, for set rows)

/// Custom swipe-to-delete affordance. iOS's native `.swipeActions`
/// renders the action button with system-controlled rounded corners
/// and margin — we want a flat, full-bleed red strip with the word
/// DELETE in the same uppercase/tracked treatment as the +SET button
/// so it reads as part of the editorial vocabulary. Two phases:
///   - Partial swipe past `deleteThreshold` → row snaps to that
///     offset, revealing the DELETE strip. Tap content to dismiss.
///   - Full swipe past `fullSwipeThreshold` → commits the delete
///     in one motion without the second tap.
///
/// Hosted inside a SwiftUI `List` (which is no longer using
/// `.swipeActions` for these rows). The List provides predictable
/// gesture coordination for the surrounding scroll + field-tap
/// interactions; our horizontal DragGesture only activates after
/// 15pt of motion, so TextField focus and List scroll both still
/// work.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0

    /// Distance the user has to drag before release commits the
    /// delete. Below this, the row springs back to zero. Tuned to
    /// feel decisive — a short tentative drag won't accidentally
    /// nuke a row, but a confident swipe past the midpoint will.
    private let commitThreshold: CGFloat = -140

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Text("DELETE")
                    .font(.marbleMono(13, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 28)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.red)
            .opacity(offset < 0 ? 1 : 0)

            content()
                .offset(x: offset)
        }
        .clipped()
        .highPriorityGesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        return
                    }
                    offset = min(0, value.translation.width)
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        snapBack()
                        return
                    }
                    if offset < commitThreshold {
                        commitDelete()
                    } else {
                        snapBack()
                    }
                }
        )
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            offset = 0
        }
    }

    private func commitDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Slide the content fully off-screen so the row briefly
        // shows as solid red, then hand off to the parent's
        // removeSet (wrapped in a spring withAnimation) — SwiftUI's
        // diff animates the row's removal and the surrounding sets
        // flow into the space without an explicit vertical-collapse
        // step here.
        withAnimation(.easeOut(duration: 0.18)) {
            offset = -UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDelete()
        }
    }
}

// MARK: - Swipe to dismiss (template set boxes)

/// Swipe a template set box left to remove it — no red reveal. The box
/// just slides out and fades as it goes, then the parent removes it.
/// The workout's full-bleed red `SwipeToDeleteRow` looks wrong behind a
/// rounded, inset box, so the boxes use this lighter affordance instead.
struct SwipeToDismissRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0

    private let commitThreshold: CGFloat = -110

    var body: some View {
        content()
            .offset(x: offset)
            // Fade gently as it's dragged out (offset is negative), so
            // it clearly reads as "being removed."
            .opacity(max(0, 1 + Double(offset) / 360))
            .highPriorityGesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        offset = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            snapBack()
                            return
                        }
                        if offset < commitThreshold {
                            commit()
                        } else {
                            snapBack()
                        }
                    }
            )
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 0
        }
    }

    private func commit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            offset = -UIScreen.main.bounds.width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDelete()
        }
    }
}

/// Look upward through `sets` from `index - 1` and return the
/// closest non-empty (weight, reps) found. Either component can
/// come from a different set — if set 1 has weight=225 reps="" and
/// set 2 has weight="" reps=8, the cascade for set 3 yields (225,
/// 8). Returns nil for any component that's empty all the way up.
/// Empty after the usual whitespace trim.
func priorFilledValues(
    in sets: [EditableSet],
    forSetAt index: Int
) -> (weight: String?, reps: String?) {
    guard index > 0 else { return (nil, nil) }
    var weight: String? = nil
    var reps: String? = nil
    for prior in stride(from: index - 1, through: 0, by: -1) {
        guard prior < sets.count else { continue }
        let s = sets[prior]
        if weight == nil {
            let w = s.weight.trimmingCharacters(in: .whitespaces)
            if !w.isEmpty { weight = w }
        }
        if reps == nil {
            let r = s.reps.trimmingCharacters(in: .whitespaces)
            if !r.isEmpty { reps = r }
        }
        if weight != nil && reps != nil { break }
    }
    return (weight, reps)
}

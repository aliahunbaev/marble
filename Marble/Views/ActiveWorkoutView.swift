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
    /// Long-press on an exercise header flips this on, collapsing the
    /// sets to titles-only so the user can drag-reorder. The Done glass
    /// pill in the toolbar exits the mode.
    @State private var isReordering: Bool = false

    @AppStorage("defaultRestTimer") private var defaultRestTimer: Int = 90

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
            // Native List handles swipe-to-delete and vertical scroll
            // natively at the framework level. Flat structure (no
            // Sections) so exercise headers don't get the sticky-pin
            // behavior that List gives section headers — they scroll
            // with content like everything else.
            //
            // Reorder mode: when isReordering is true, the sets collapse
            // and a single ForEach of headers replaces the expanded
            // structure so native .onMove drag-to-reorder works on the
            // exercise list. Exit via Done in the toolbar.
            List {
                workoutHeaderRow(session: session)

                if isReordering {
                    reorderingHeadersForEach(entries: $session.entries)
                } else {
                    expandedExercisesContent(entries: $session.entries)
                    addExerciseRow
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.defaultMinListRowHeight, 0)
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))

            // Floating glass buttons over the workout content
            floatingToolbar
        }
        .background(Color("marbleBackground"))
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
        .alert("Discard this workout?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                session.end()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All progress will be lost.")
        }
        .alert("No sets completed", isPresented: $showingEmptyFinishAlert) {
            Button("Discard", role: .destructive) {
                session.end()
                dismiss()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("There's nothing to save yet. Discard the workout, or keep going.")
        }
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
        .padding(.top, 52)
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

    /// Reorder mode rendering — just exercise titles with hairlines,
    /// wrapped in a single ForEach with .onMove so native iOS drag-to-
    /// reorder activates. Edit mode is forced .active on the List so the
    /// drag handles + ordering gestures kick in immediately, without
    /// needing the user to long-press a row first.
    @ViewBuilder
    private func reorderingHeadersForEach(entries: Binding<[ExerciseEntry]>) -> some View {
        ForEach(entries) { $entry in
            reorderingTitleRow(entry: $entry)
        }
        .onMove { from, to in
            session.entries.move(fromOffsets: from, toOffset: to)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func reorderingTitleRow(entry: Binding<ExerciseEntry>) -> some View {
        Text(entry.wrappedValue.exercise.name)
            .font(.marbleBody(22))
            .foregroundStyle(Color("marblePrimary"))
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.visible, edges: .bottom)
            .listRowSeparatorTint(Color("marblePrimary").opacity(0.08))
            .listRowBackground(Color.clear)
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

        SetRowView(
            setNumber: index + 1,
            weight: set.weight,
            reps: set.reps,
            isCompleted: set.isCompleted,
            previousWeight: prev.weight,
            previousReps: prev.reps,
            showCheckmark: true,
            onComplete: nil
        )
        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
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

    @ViewBuilder
    private var floatingToolbar: some View {
        if isReordering {
            reorderingToolbar
        } else {
            normalToolbar
        }
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

            // Workout-level menu — reorder + discard live here.
            // Note: iOS 26's Liquid Glass Menu transition animation can
            // briefly show the trigger's elevation/shadow state during
            // open/close. It's a platform rendering artifact that's hard
            // to fully suppress without losing the native Menu UX.
            Menu {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isReordering = true
                    }
                } label: {
                    Label("Reorder exercises", systemImage: "arrow.up.arrow.down")
                }
                .disabled(session.entries.count < 2)

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

    /// Reorder-mode toolbar — just a Done glass pill that exits back to
    /// the expanded layout. Hides the other actions to keep focus.
    private var reorderingToolbar: some View {
        HStack {
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isReordering = false
                }
            } label: {
                Text("DONE")
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

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Shared workout state — name/entries/timer all live here so the
    /// workout survives across tab navigation, minimize-to-mini-bar, etc.
    @Environment(WorkoutSession.self) private var session

    // View-local presentation state (sheets, alerts, drag) — distinct
    // from workout data, doesn't need to survive minimization.
    @State private var showingLibrary = false
    @State private var showingRestTimer = false
    @State private var showingDiscardAlert = false
    @State private var completedWorkout: Workout?
    @State private var showingSummary = false
    @State private var showingPhotoCapture = false
    @State private var capturedPhoto: ProgressPhoto?
    @State private var draggingEntryID: UUID?
    @State private var lastSwapOffset: CGFloat = 0
    @State private var showingEmptyFinishAlert = false

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
        CloudSyncService.shared.deleteWorkout(cloudID: cloudID)

        session.resumeTimer()

        completedWorkout = nil
        withAnimation { showingSummary = false }
    }

    private var workoutContentView: some View {
        @Bindable var session = session

        return ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Workout", text: $session.name)
                        .font(.marbleBody(32))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 64) // breathing room below floating buttons
                        .padding(.bottom, 6)

                    Text(session.formattedTime)
                        .font(.marbleMono(13))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)

                    if draggingEntryID != nil {
                        ForEach(session.entries) { entry in
                            reorderRow(entry: entry)
                        }
                    } else {
                        ForEach($session.entries) { $entry in
                            ExerciseSetTable(
                                entry: $entry,
                                onRemove: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        session.entries.removeAll { $0.id == entry.id }
                                    }
                                },
                                isWorkoutMode: true,
                                onSetCompleted: {
                                    // Rest timer auto-start removed — manual only
                                },
                                onStartRestTimer: {
                                    showingRestTimer = true
                                },
                                onReplaceExercise: {
                                    showingLibrary = true
                                },
                                dragHandle: false
                            )
                            exerciseDivider
                        }
                    }

                    addExerciseButton
                        .padding(.top, session.entries.isEmpty ? 0 : 4)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }

            // Floating glass buttons over the workout content
            floatingToolbar
        }
        .background(Color("marbleBackground"))
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
        .sheet(isPresented: $showingLibrary) {
            let selectedExercises = session.entries.map(\.exercise)
            ExerciseLibraryView(selectedExercises: selectedExercises) { exercise in
                toggleExercise(exercise)
            }
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

    // MARK: - Floating Toolbar (iOS-26 liquid glass)

    private var floatingToolbar: some View {
        HStack(spacing: 10) {
            // Minimize → mini-bar. Drops back to the underlying tab, keeps
            // the workout running. Tap the mini-bar later to re-expand.
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

            // Workout-level menu — discard lives here.
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

    // MARK: - Shared Components

    private var exerciseDivider: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
    }

    private var addExerciseButton: some View {
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
    }

    // MARK: - Actions

    private func toggleExercise(_ exercise: Exercise) {
        if let index = session.entries.firstIndex(where: { $0.exercise.id == exercise.id }) {
            session.entries.remove(at: index)
        } else {
            let entry = ExerciseEntry(exercise: exercise, sets: [
                EditableSet(), EditableSet(), EditableSet()
            ])
            session.entries.append(entry)
        }
    }

    private func reorderRow(entry: ExerciseEntry) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color("marbleTertiary"))
                .padding(.trailing, 6)

            Text(entry.exercise.name)
                .font(.marbleBody(16))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()

            Text("\(entry.sets.count) sets")
                .font(.marbleMono(11))
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(draggingEntryID == entry.id ? Color("marblePrimary").opacity(0.06) : Color.clear)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(entryID: entry.id, translation: value.translation.height)
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        draggingEntryID = nil
                    }
                    lastSwapOffset = 0
                }
        )
    }

    private func handleDrag(entryID: UUID, translation: CGFloat) {
        if draggingEntryID == nil {
            draggingEntryID = entryID
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        guard let currentIndex = session.entries.firstIndex(where: { $0.id == entryID }) else { return }
        let delta = translation - lastSwapOffset
        let threshold: CGFloat = 50

        if delta > threshold, currentIndex < session.entries.count - 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                session.entries.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: currentIndex + 2)
            }
            lastSwapOffset = translation
        } else if delta < -threshold, currentIndex > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                session.entries.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: currentIndex - 1)
            }
            lastSwapOffset = translation
        }
    }

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

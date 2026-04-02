import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var entries: [ExerciseEntry]
    @State private var showingLibrary = false
    @State private var showingRestTimer = false
    @State private var elapsedSeconds: Int = 0
    @State private var workoutTimer: Timer?
    @State private var startDate = Date()
    @State private var restTimer = RestTimerState()
    @State private var showingDiscardAlert = false

    private let sourceTemplate: WorkoutTemplate?

    init(template: WorkoutTemplate) {
        self.sourceTemplate = template
        _name = State(initialValue: template.name)
        _entries = State(initialValue: template.exercises.map { exercise in
            ExerciseEntry(exercise: exercise, sets: [
                EditableSet(), EditableSet(), EditableSet()
            ])
        })
    }

    init() {
        self.sourceTemplate = nil
        _name = State(initialValue: "Workout")
        _entries = State(initialValue: [])
    }

    var body: some View {
        VStack(spacing: 0) {
            workoutToolbar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Workout", text: $name)
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    Text(formattedTime)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    ForEach($entries) { $entry in
                        ExerciseSetTable(
                            entry: $entry,
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    entries.removeAll { $0.id == entry.id }
                                }
                            },
                            isWorkoutMode: true
                        )

                        if entry.id != entries.last?.id {
                            exerciseDivider
                        }
                    }

                    addExerciseButton
                        .padding(.top, entries.isEmpty ? 0 : 24)
                        .padding(.horizontal, 20)

                    discardButton
                        .padding(.top, 24)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear { startWorkoutTimer() }
        .onDisappear { stopWorkoutTimer(); restTimer.stop() }
        .sheet(isPresented: $showingLibrary) {
            let selectedExercises = entries.map(\.exercise)
            ExerciseLibraryView(selectedExercises: selectedExercises) { exercise in
                toggleExercise(exercise)
            }
        }
        .sheet(isPresented: $showingRestTimer) {
            RestTimerModal(state: restTimer)
        }
        .alert("Discard this workout?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                stopWorkoutTimer()
                restTimer.stop()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All progress will be lost.")
        }
    }

    // MARK: - Toolbar

    private var workoutToolbar: some View {
        HStack {
            RestTimerButton(state: restTimer) {
                showingRestTimer = true
            }

            Spacer()

            Button {
                finishWorkout()
            } label: {
                Text("FINISH")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGreen))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Shared Components

    private var exerciseDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
    }

    private var addExerciseButton: some View {
        Button {
            showingLibrary = true
        } label: {
            HStack(spacing: 6) {
                Text("+")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                Text("EXERCISE")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGreen).opacity(0.1))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Discard Button

    private var discardButton: some View {
        Button {
            showingDiscardAlert = true
        } label: {
            Text("Discard Workout")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workout Timer

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startWorkoutTimer() {
        startDate = Date()
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds = Int(Date().timeIntervalSince(startDate))
        }
    }

    private func stopWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
    }

    // MARK: - Actions

    private func toggleExercise(_ exercise: Exercise) {
        if let index = entries.firstIndex(where: { $0.exercise.id == exercise.id }) {
            entries.remove(at: index)
        } else {
            let entry = ExerciseEntry(exercise: exercise, sets: [
                EditableSet(), EditableSet(), EditableSet()
            ])
            entries.append(entry)
        }
    }

    private func finishWorkout() {
        stopWorkoutTimer()
        restTimer.stop()

        let duration = Date().timeIntervalSince(startDate)
        let workoutName = name.trimmingCharacters(in: .whitespaces)

        var exerciseLogs: [ExerciseLog] = []

        for entry in entries {
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
            date: startDate,
            duration: duration,
            exerciseLogs: exerciseLogs
        )
        modelContext.insert(workout)
        try? modelContext.save()

        dismiss()
    }
}

#Preview {
    ActiveWorkoutView()
        .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}

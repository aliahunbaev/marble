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
    @State private var completedWorkout: Workout?
    @State private var showingSummary = false

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
        if showingSummary, let workout = completedWorkout {
            workoutSummaryView(workout: workout)
        } else {
            workoutContentView
        }
    }

    private var workoutContentView: some View {
        VStack(spacing: 0) {
            workoutToolbar
            Rectangle()
                .fill(Color("marbleTertiary"))
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Workout", text: $name)
                        .font(.system(size: 28, weight: .medium, design: .default))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    Text(formattedTime)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(Color("marbleSecondary"))
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
        .background(Color("marbleBackground"))
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
                    .foregroundStyle(Color("marbleBackground"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("marblePrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Shared Components

    private var exerciseDivider: some View {
        Rectangle()
            .fill(Color("marbleTertiary"))
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
            .foregroundStyle(Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color("marbleCard"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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

        completedWorkout = workout
        withAnimation {
            showingSummary = true
        }
    }

    // MARK: - Workout Summary

    private func workoutSummaryView(workout: Workout) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Checkmark
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(Color("marblePrimary"))

                // Title
                Text("Workout Complete")
                    .font(.system(size: 24, weight: .medium, design: .default))
                    .foregroundStyle(Color("marblePrimary"))

                // Workout name
                Text(workout.name)
                    .font(.system(size: 17, design: .default))
                    .foregroundStyle(Color("marbleSecondary"))

                // Stats
                VStack(spacing: 28) {
                    summaryStatView(
                        label: "DURATION",
                        value: formattedDuration(workout.duration)
                    )

                    summaryStatView(
                        label: "EXERCISES",
                        value: "\(workout.exerciseLogs.count)"
                    )

                    summaryStatView(
                        label: "SETS",
                        value: "\(totalSets(workout))"
                    )

                    summaryStatView(
                        label: "VOLUME",
                        value: formattedVolume(workout)
                    )
                }
                .padding(.top, 8)
            }

            Spacer()

            // Done button
            Button {
                dismiss()
            } label: {
                Text("DONE")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color("marbleBackground"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color("marblePrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color("marbleBackground"))
    }

    private func summaryStatView(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 36, weight: .medium, design: .monospaced))
                .foregroundStyle(Color("marblePrimary"))
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))
        }
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func totalSets(_ workout: Workout) -> Int {
        workout.exerciseLogs.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    private func totalVolume(_ workout: Workout) -> Double {
        workout.exerciseLogs.reduce(0.0) { total, log in
            total + log.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
    }

    private func formattedVolume(_ workout: Workout) -> String {
        let volume = Int(totalVolume(workout))
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: volume)) ?? "\(volume)"
        return "\(formatted) lbs"
    }
}

#Preview {
    ActiveWorkoutView()
        .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}

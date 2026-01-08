import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workoutSession: WorkoutSession
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingExercisePicker = false
    @State private var showingCancelAlert = false

    init(workoutSession: WorkoutSession? = nil) {
        let session = workoutSession ?? WorkoutSession(name: "Workout", startTime: Date())
        _workoutSession = State(initialValue: session)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MarbleSpacing.s) {
                    // Workout header
                    WorkoutHeader(
                        workoutSession: $workoutSession,
                        elapsedTime: elapsedTime
                    )

                    // Exercise list
                    if workoutSession.exercises.isEmpty {
                        EmptyWorkoutState()
                    } else {
                        ForEach(workoutSession.exercises.sorted(by: { $0.order < $1.order })) { exercisePerformance in
                            ExerciseSection(
                                exercisePerformance: exercisePerformance,
                                modelContext: modelContext
                            )
                        }
                    }

                    // Add Exercises button
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Text("Add Exercises")
                            .font(.marbleBody)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MarbleSpacing.xs)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, MarbleSpacing.xs)

                    // Cancel Workout button
                    Button {
                        showingCancelAlert = true
                    } label: {
                        Text("Cancel Workout")
                            .font(.marbleBody)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, MarbleSpacing.xs)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, MarbleSpacing.xs)
                }
                .padding(.vertical, MarbleSpacing.xs)
            }
            .background(Color.marbleBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingCancelAlert = true
                    } label: {
                        Image(systemName: "arrow.left")
                            .fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(formatDuration(elapsedTime))
                        .font(.marbleBody)
                        .fontWeight(.medium)
                        .foregroundColor(.marblePrimary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Finish") {
                        finishWorkout()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, MarbleSpacing.xs)
                    .padding(.vertical, MarbleSpacing.xxs)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                }
            }
            .alert("Cancel Workout", isPresented: $showingCancelAlert) {
                Button("Keep Going", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to discard this workout?")
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(workoutSession.startTime)
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let newOrder = (workoutSession.exercises.map { $0.order }.max() ?? -1) + 1
        let performance = ExercisePerformance(exercise: exercise, order: newOrder)
        performance.workoutSession = workoutSession
        workoutSession.exercises.append(performance)
        modelContext.insert(performance)
    }

    private func finishWorkout() {
        workoutSession.endTime = Date()
        modelContext.insert(workoutSession)
        dismiss()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WorkoutHeader: View {
    @Binding var workoutSession: WorkoutSession
    let elapsedTime: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xxs) {
            Text(workoutSession.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.marblePrimary)

            HStack(spacing: MarbleSpacing.xs) {
                Label {
                    Text(workoutSession.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                }

                Label {
                    Text(formatDuration(elapsedTime))
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MarbleSpacing.xs)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct EmptyWorkoutState: View {
    var body: some View {
        VStack(spacing: MarbleSpacing.xs) {
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundColor(.marbleSecondary)

            Text("No exercises added yet")
                .font(.marbleBody)
                .foregroundColor(.marbleSecondary)

            Text("Tap \"Add Exercises\" to get started")
                .font(.marbleCaption)
                .foregroundColor(.marbleSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MarbleSpacing.xl)
    }
}

struct ExerciseSection: View {
    @Bindable var exercisePerformance: ExercisePerformance
    let modelContext: ModelContext

    @State private var editingSets: [UUID: SetEditData] = [:]
    @State private var previousPerformance: ExercisePerformance?

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xs) {
            // Exercise name header
            HStack {
                Text(exercisePerformance.exercise?.displayName ?? "Unknown Exercise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)

                Spacer()

                Button {
                    // TODO: Show exercise history
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                }

                Button {
                    // TODO: Exercise options menu
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.marbleSecondary)
                }
            }
            .padding(.horizontal, MarbleSpacing.xs)

            // Table header
            HStack(spacing: 8) {
                Text("Set")
                    .font(.marbleCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.marbleSecondary)
                    .frame(width: 40, alignment: .leading)

                Text("Previous")
                    .font(.marbleCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.marbleSecondary)
                    .frame(width: 80, alignment: .leading)

                Text("lbs")
                    .font(.marbleCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.marbleSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Reps")
                    .font(.marbleCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.marbleSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("")
                    .frame(width: 40)
            }
            .padding(.horizontal, MarbleSpacing.xs)

            // Sets list
            ForEach(Array(exercisePerformance.sets.enumerated()), id: \.offset) { index, set in
                SetRow(
                    setNumber: index + 1,
                    set: set,
                    previousSet: previousPerformance?.sets.indices.contains(index) == true ? previousPerformance?.sets[index] : nil,
                    editData: Binding(
                        get: { editingSets[set.id] ?? SetEditData(set: set) },
                        set: { editingSets[set.id] = $0 }
                    ),
                    onComplete: {
                        set.completed.toggle()
                    }
                )
            }

            // Add Set button
            Button {
                addSet()
            } label: {
                Text("+ Add Set (2:00)")
                    .font(.marbleBody)
                    .foregroundColor(.marbleSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MarbleSpacing.xs)
                    .background(Color.marbleSecondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, MarbleSpacing.xs)
        }
        .padding(.vertical, MarbleSpacing.xs)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, MarbleSpacing.xs)
        .onAppear {
            loadPreviousWorkout()
        }
    }

    private func loadPreviousWorkout() {
        guard let exercise = exercisePerformance.exercise else { return }
        previousPerformance = ExerciseDatabase.shared.fetchPreviousWorkout(
            for: exercise,
            modelContext: modelContext
        )
    }

    private func addSet() {
        let newSet = ExerciseSet(reps: 0, weight: 0, completed: false, restTimer: 120)
        newSet.exercisePerformance = exercisePerformance
        exercisePerformance.sets.append(newSet)
        modelContext.insert(newSet)
    }

    private func copyPreviousWorkout() {
        guard let previousPerformance = previousPerformance else { return }

        // Clear existing sets
        exercisePerformance.sets.removeAll()

        // Copy sets from previous workout
        for previousSet in previousPerformance.sets {
            let newSet = ExerciseSet(
                reps: previousSet.reps,
                weight: previousSet.weight,
                completed: false,
                restTimer: 120
            )
            newSet.exercisePerformance = exercisePerformance
            exercisePerformance.sets.append(newSet)
            modelContext.insert(newSet)
        }
    }
}

struct SetRow: View {
    let setNumber: Int
    @Bindable var set: ExerciseSet
    let previousSet: ExerciseSet?
    @Binding var editData: SetEditData
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text("\(setNumber)")
                .font(.marbleDataValue)
                .foregroundColor(.marbleSecondary)
                .frame(width: 40, alignment: .leading)

            // Previous workout data
            if let previousSet = previousSet {
                Text("\(Int(previousSet.weight)) lb × \(previousSet.reps)")
                    .font(.marbleDataValue)
                    .foregroundColor(.marbleSecondary)
                    .frame(width: 80, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("—")
                    .font(.marbleDataValue)
                    .foregroundColor(.marbleSecondary)
                    .frame(width: 80, alignment: .leading)
            }

            // Weight input
            TextField("0", text: $editData.weight)
                .keyboardType(.decimalPad)
                .font(.marbleDataValue)
                .foregroundColor(.marblePrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color.marbleSecondary.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
                .onChange(of: editData.weight) { _, newValue in
                    if let weight = Double(newValue) {
                        set.weight = weight
                    }
                }

            // Reps input
            TextField("0", text: $editData.reps)
                .keyboardType(.numberPad)
                .font(.marbleDataValue)
                .foregroundColor(.marblePrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color.marbleSecondary.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: .infinity)
                .onChange(of: editData.reps) { _, newValue in
                    if let reps = Int(newValue) {
                        set.reps = reps
                    }
                }

            // Checkmark
            Button {
                onComplete()
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(set.completed ? .green : .marbleSecondary)
            }
            .frame(width: 40)
        }
        .padding(.horizontal, MarbleSpacing.xs)
    }
}

struct SetEditData {
    var weight: String
    var reps: String

    init(set: ExerciseSet) {
        self.weight = set.weight > 0 ? String(Int(set.weight)) : ""
        self.reps = set.reps > 0 ? String(set.reps) : ""
    }
}

#Preview {
    ActiveWorkoutView()
        .modelContainer(for: [WorkoutSession.self, ExercisePerformance.self, Exercise.self, ExerciseSet.self])
}

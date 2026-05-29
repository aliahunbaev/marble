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
    @State private var showingPhotoCapture = false
    @State private var capturedPhoto: ProgressPhoto?
    @State private var draggingEntryID: UUID?
    @State private var lastSwapOffset: CGFloat = 0

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
            ClosingRitualView(workout: workout)
                .onDisappear {
                    dismiss()
                }
        } else {
            workoutContentView
        }
    }

    private var workoutContentView: some View {
        VStack(spacing: 0) {
            workoutToolbar
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.06))
                .frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Workout", text: $name)
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 26).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    Text(formattedTime)
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 14).weight(.light))
                        .foregroundStyle(Color("marbleSecondary"))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    if draggingEntryID != nil {
                        ForEach(entries) { entry in
                            reorderRow(entry: entry)
                        }
                    } else {
                        ForEach($entries) { $entry in
                            ExerciseSetTable(
                                entry: $entry,
                                onRemove: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        entries.removeAll { $0.id == entry.id }
                                    }
                                },
                                isWorkoutMode: true,
                                onSetCompleted: {
                                    // Rest timer auto-start removed — manual only
                                },
                                dragHandle: false
                            )
                            if entry.id != entries.last?.id {
                                exerciseDivider
                            }
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
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
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
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                    .tracking(1)
                    .foregroundStyle(Color("marbleBackground"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color("marblePrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 14).weight(.light))
                Text("EXERCISE")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                    .tracking(1)
            }
            .foregroundStyle(Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Discard Button

    private var discardButton: some View {
        Button {
            showingDiscardAlert = true
        } label: {
            Text("Discard Workout")
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
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

    private func reorderRow(entry: ExerciseEntry) -> some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color("marbleTertiary"))
                .padding(.trailing, 6)

            Text(entry.exercise.name)
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 16).weight(.light))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()

            Text("\(entry.sets.count) sets")
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
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

        guard let currentIndex = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let delta = translation - lastSwapOffset
        let threshold: CGFloat = 50

        if delta > threshold, currentIndex < entries.count - 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                entries.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: currentIndex + 2)
            }
            lastSwapOffset = translation
        } else if delta < -threshold, currentIndex > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                entries.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: currentIndex - 1)
            }
            lastSwapOffset = translation
        }
    }

    @AppStorage("defaultRestTimer") private var defaultRestTimer: Int = 90

    private func startRestTimerIfNeeded() {
        guard !restTimer.isActive else { return }
        restTimer.start(duration: defaultRestTimer)
    }

    private func finishWorkout() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        CloudSyncService.shared.uploadWorkout(workout)

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
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 24).weight(.light))
                    .foregroundStyle(Color("marblePrimary"))

                // Workout name
                Text(workout.name)
                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 16).weight(.light))
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

            // Capture / done buttons
            VStack(spacing: 10) {
                if capturedPhoto == nil {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showingPhotoCapture = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.system(size: 14, weight: .light))
                            Text("MARK IT")
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.medium))
                                .tracking(2)
                        }
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            Capsule()
                                .stroke(Color("marblePrimary").opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .light))
                        Text("MARKED")
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.medium))
                            .tracking(2)
                    }
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }

                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 16).weight(.light))
                        .foregroundStyle(Color("marbleBackground"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("marblePrimary"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color("marbleBackground"))
        .sheet(isPresented: $showingPhotoCapture) {
            PhotoCaptureSheet(
                workoutCloudID: workout.cloudID,
                onCaptured: { photo in
                    capturedPhoto = photo
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    private func summaryStatView(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 32).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
            Text(label)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
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

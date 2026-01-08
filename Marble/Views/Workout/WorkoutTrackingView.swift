import SwiftUI
import SwiftData

struct WorkoutTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var legacyWorkouts: [WorkoutEntry]
    @State private var showingActiveWorkout = false

    private var allWorkoutsGrouped: [(String, [WorkoutDisplayItem])] {
        var allItems: [WorkoutDisplayItem] = []

        // Add new workout sessions
        allItems.append(contentsOf: workoutSessions.map { .session($0) })

        // Add legacy workouts
        allItems.append(contentsOf: legacyWorkouts.map { .legacy($0) })

        // Group by date
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allItems) { item in
            calendar.startOfDay(for: item.date)
        }

        return grouped.sorted { $0.key > $1.key }.map { (key, value) in
            (formatDate(key), value.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            if workoutSessions.isEmpty && legacyWorkouts.isEmpty {
                ContentUnavailableView(
                    "No workouts logged",
                    systemImage: "dumbbell.fill",
                    description: Text("Tap + to start your first workout")
                )
            } else {
                List {
                    ForEach(allWorkoutsGrouped, id: \.0) { date, dayWorkouts in
                        Section(date) {
                            ForEach(dayWorkouts) { item in
                                switch item {
                                case .session(let session):
                                    WorkoutSessionRow(session: session)
                                case .legacy(let workout):
                                    LegacyWorkoutRow(workout: workout)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("TRAIN")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingActiveWorkout = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.medium)
                }
            }
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            ActiveWorkoutView()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Workout Display Items

enum WorkoutDisplayItem: Identifiable {
    case session(WorkoutSession)
    case legacy(WorkoutEntry)

    var id: UUID {
        switch self {
        case .session(let session): return session.id
        case .legacy(let workout): return workout.id
        }
    }

    var date: Date {
        switch self {
        case .session(let session): return session.date
        case .legacy(let workout): return workout.date
        }
    }
}

// MARK: - Row Views

struct WorkoutSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xxs) {
            HStack {
                Text(session.name)
                    .font(.marbleBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.marblePrimary)

                Spacer()

                if let duration = session.duration {
                    Text(formatDuration(duration))
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                }
            }

            if !session.exercises.isEmpty {
                Text("\(session.exercises.count) exercises • \(totalSets) sets")
                    .font(.marbleCaption)
                    .foregroundColor(.marbleSecondary)

                ForEach(session.exercises.sorted(by: { $0.order < $1.order }).prefix(3)) { performance in
                    if let exercise = performance.exercise {
                        Text("• \(exercise.displayName)")
                            .font(.marbleDataValue)
                            .foregroundColor(.marbleSecondary)
                            .lineLimit(1)
                    }
                }

                if session.exercises.count > 3 {
                    Text("+ \(session.exercises.count - 3) more")
                        .font(.marbleCaption)
                        .foregroundColor(.marbleSecondary)
                }
            }
        }
        .padding(.vertical, MarbleSpacing.xxxs)
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %ds", minutes, seconds)
    }
}

struct LegacyWorkoutRow: View {
    let workout: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xxs) {
            HStack {
                Text(workout.exerciseName)
                    .font(.marbleBody)
                    .foregroundColor(.marblePrimary)

                Spacer()

                Text("LEGACY")
                    .font(.marbleCaption)
                    .foregroundColor(.marbleSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.marbleSecondary.opacity(0.1))
                    .cornerRadius(4)
            }

            if !workout.sets.isEmpty {
                VStack(alignment: .leading, spacing: MarbleSpacing.xxxs) {
                    ForEach(Array(workout.sets.enumerated()), id: \.offset) { index, set in
                        Text("\(index + 1). \(set.reps) × \(Int(set.weight)) LBS")
                            .font(.marbleDataValue)
                            .foregroundColor(.marbleSecondary)
                    }
                }
            }

            if let notes = workout.notes, !notes.isEmpty {
                Text(notes)
                    .font(.marbleCaption)
                    .foregroundColor(.marbleSecondary)
            }
        }
        .padding(.vertical, MarbleSpacing.xxxs)
    }
}

#Preview {
    WorkoutTrackingView()
        .modelContainer(for: [WorkoutSession.self, WorkoutEntry.self, ExercisePerformance.self, Exercise.self, ExerciseSet.self])
}

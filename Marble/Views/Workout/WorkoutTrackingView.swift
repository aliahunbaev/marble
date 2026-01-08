import SwiftUI
import SwiftData

struct WorkoutTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workouts: [WorkoutEntry]
    @State private var showingAddWorkout = false

    private var groupedWorkouts: [(String, [WorkoutEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.startOfDay(for: workout.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { (key, value) in
            (formatDate(key), value.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts logged",
                    systemImage: "dumbbell.fill",
                    description: Text("Tap + to log your first workout")
                )
            } else {
                List {
                    ForEach(groupedWorkouts, id: \.0) { date, dayWorkouts in
                        Section(date) {
                            ForEach(dayWorkouts) { workout in
                                WorkoutRow(workout: workout)
                            }
                            .onDelete { offsets in
                                deleteWorkouts(dayWorkouts, at: offsets)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            NavigationStack {
            }
            .navigationTitle("TRAIN")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
            }
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

    private func deleteWorkouts(_ workouts: [WorkoutEntry], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
    }
}

struct WorkoutRow: View {
    let workout: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: MarbleSpacing.xxs) {
            Text(workout.exerciseName)
                .font(.marbleBody)
                .foregroundColor(.marblePrimary)

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
        .modelContainer(for: [WorkoutEntry.self, ExerciseSet.self])
}

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 28, weight: .medium, design: .default))
                        .foregroundStyle(Color("marblePrimary"))

                    HStack(spacing: 12) {
                        Text(formattedDate)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color("marbleSecondary"))

                        Text(formattedDuration)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Exercise logs
                ForEach(Array(workout.exerciseLogs.enumerated()), id: \.element.id) { index, log in
                    exerciseSection(log: log)

                    if index < workout.exerciseLogs.count - 1 {
                        Rectangle()
                            .fill(Color("marbleTertiary"))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color("marbleBackground"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Delete this workout? This cannot be undone.", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(workout)
                try? modelContext.save()
                dismiss()
            }
        }
    }

    private func exerciseSection(log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Exercise name
            Text(log.exercise?.name ?? "Unknown")
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundStyle(Color("marblePrimary"))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // Column headers
            HStack(spacing: 12) {
                Text("SET")
                    .frame(width: 36, alignment: .center)
                Text("LBS")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Set rows
            let completedSets = log.sets.filter { $0.isCompleted }
            ForEach(Array(completedSets.enumerated()), id: \.offset) { index, set in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(width: 36, alignment: .center)

                    Text(formattedWeight(set.weight))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)

                    Text("\(set.reps)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        if weight == floor(weight) {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: workout.date)
    }

    private var formattedDuration: String {
        let minutes = Int(workout.duration) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: Workout(name: "Push Day", date: .now, duration: 3600))
    }
    .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}

import SwiftUI
import SwiftData

struct TrackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \TrackedLift.displayOrder) private var trackedLifts: [TrackedLift]

    @State private var showingAddLift = false
    @State private var workoutToDelete: Workout?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    contributionGrid
                    myLiftsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddLift) {
                AddTrackedLiftSheet(trackedLifts: trackedLifts)
            }
            .alert("Delete this workout? This cannot be undone.", isPresented: Binding<Bool>(
                get: { workoutToDelete != nil },
                set: { if !$0 { workoutToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let workout = workoutToDelete {
                        modelContext.delete(workout)
                        try? modelContext.save()
                        workoutToDelete = nil
                    }
                }
            }
        }
    }

    // MARK: - Contribution Grid

    private var contributionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACTIVITY")

            let gridData = buildGridData()

            VStack(spacing: 0) {
                // Month labels row
                HStack(spacing: 0) {
                    // Spacer for day labels column
                    Color.clear
                        .frame(width: 18)

                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            let label = gridData.monthLabels[col]
                            Text(label)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color("marbleSecondary"))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.bottom, 4)

                // Grid rows (Mon-Sun)
                let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
                ForEach(0..<7, id: \.self) { row in
                    HStack(spacing: 0) {
                        Text(dayLabels[row])
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color("marbleSecondary"))
                            .frame(width: 18, alignment: .leading)

                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                let hasWorkout = gridData.cells[row][col]
                                Circle()
                                    .fill(hasWorkout ? Color("marblePrimary") : Color("marbleTertiary"))
                                    .frame(width: 10, height: 10)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
            .background(Color("marbleCard"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private struct GridData {
        var cells: [[Bool]] // [row (day of week 0=Mon)][col (week 0=oldest)]
        var monthLabels: [String] // one per column
    }

    private func buildGridData() -> GridData {
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: Date())

        // Find the Monday of the current week
        let todayWeekday = calendar.component(.weekday, from: today)
        // ISO: Monday=2..Sunday=1 -> offset
        let daysFromMonday = (todayWeekday + 5) % 7
        guard let currentWeekMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return GridData(cells: Array(repeating: Array(repeating: false, count: 8), count: 7), monthLabels: Array(repeating: "", count: 8))
        }

        // 8 weeks: start from 7 weeks before current week's Monday
        guard let gridStart = calendar.date(byAdding: .weekOfYear, value: -7, to: currentWeekMonday) else {
            return GridData(cells: Array(repeating: Array(repeating: false, count: 8), count: 7), monthLabels: Array(repeating: "", count: 8))
        }

        // Build set of workout dates
        var workoutDates = Set<Date>()
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            workoutDates.insert(day)
        }

        var cells = Array(repeating: Array(repeating: false, count: 8), count: 7)
        var monthLabels = Array(repeating: "", count: 8)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        var lastMonth = -1

        for col in 0..<8 {
            guard let weekStart = calendar.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }

            let month = calendar.component(.month, from: weekStart)
            if month != lastMonth {
                monthLabels[col] = monthFormatter.string(from: weekStart)
                lastMonth = month
            }

            for row in 0..<7 {
                guard let cellDate = calendar.date(byAdding: .day, value: row, to: weekStart) else { continue }
                if cellDate <= today {
                    cells[row][col] = workoutDates.contains(cellDate)
                }
            }
        }

        return GridData(cells: cells, monthLabels: monthLabels)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "HISTORY")

            if workouts.isEmpty {
                Text("No workouts yet")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.name)
                                        .font(.system(size: 14, weight: .medium, design: .default))
                                        .foregroundStyle(Color("marblePrimary"))

                                    Text(historyDateString(workout.date))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(Color("marbleSecondary"))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color("marbleTertiary"))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                workoutToDelete = workout
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        if index < workouts.count - 1 {
                            Rectangle()
                                .fill(Color("marbleTertiary"))
                                .frame(height: 1)
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(Color("marbleCard"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            }
        }
    }

    private func historyDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    // MARK: - My Lifts

    private var myLiftsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "MY LIFTS")
                Spacer()
                Button {
                    showingAddLift = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(width: 32, height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("marblePrimary"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if trackedLifts.isEmpty {
                Text("Tap + to track your lifts")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(trackedLifts, id: \.id) { lift in
                        if let exercise = lift.exercise {
                            NavigationLink(destination: ExerciseLiftDetailView(trackedLift: lift)) {
                                LiftCardView(lift: lift, exercise: exercise, workouts: workouts)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(lift)
                                    try? modelContext.save()
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Lift Card View

private struct LiftCardView: View {
    let lift: TrackedLift
    let exercise: Exercise
    let workouts: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Text(metricValue)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metricLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color("marbleSecondary"))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(minHeight: 110)
        .background(Color("marbleCard"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var metricLabel: String {
        switch lift.metricType {
        case "bestWeight": return "Best Weight"
        case "maxVolume": return "Max Volume"
        case "oneRepMax": return "Est. 1RM"
        default: return "Best Weight"
        }
    }

    private var metricValue: String {
        let metrics = LiftMetrics.compute(for: exercise, workouts: workouts, lift: lift)

        switch lift.metricType {
        case "bestWeight":
            return metrics.bestWeightFormatted
        case "oneRepMax":
            return metrics.oneRepMaxFormatted
        case "maxVolume":
            return metrics.maxVolumeFormatted
        default:
            return metrics.bestWeightFormatted
        }
    }
}

// MARK: - Add Tracked Lift Sheet

private struct AddTrackedLiftSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let trackedLifts: [TrackedLift]

    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty { return allExercises }
        return allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return grouped.sorted { $0.key < $1.key }
    }

    private func isTracked(_ exercise: Exercise) -> Bool {
        trackedLifts.contains { $0.exercise?.persistentModelID == exercise.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color("marbleSecondary"))
                            .font(.system(size: 14))
                        TextField("Search exercises", text: $searchText)
                            .font(.system(.body, design: .default))
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color("marbleFieldBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    ForEach(groupedExercises, id: \.0) { group, exercises in
                        VStack(alignment: .leading, spacing: 0) {
                            SectionHeader(title: group.uppercased())
                                .padding(.horizontal, 20)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ForEach(exercises) { exercise in
                                    Button {
                                        toggleTracked(exercise)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.name)
                                                    .font(.system(.body, design: .default))
                                                    .foregroundStyle(Color("marblePrimary"))
                                                Text(exercise.muscleGroup)
                                                    .font(.system(.caption, design: .monospaced))
                                                    .foregroundStyle(Color("marbleSecondary"))
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(isTracked(exercise) ? Color("marbleAccent").opacity(0.1) : Color.clear)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if exercise.id != exercises.last?.id {
                                        Rectangle()
                                            .fill(Color("marbleTertiary"))
                                            .frame(height: 1)
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color("marbleTertiary")),
                                alignment: .top
                            )
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color("marbleTertiary")),
                                alignment: .bottom
                            )
                            .padding(.bottom, 24)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationTitle("Track Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { dismiss() }
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
            }
        }
    }

    private func toggleTracked(_ exercise: Exercise) {
        if let existing = trackedLifts.first(where: { $0.exercise?.persistentModelID == exercise.persistentModelID }) {
            modelContext.delete(existing)
        } else {
            let lift = TrackedLift(exercise: exercise, metricType: "bestWeight", displayOrder: trackedLifts.count)
            modelContext.insert(lift)
        }
        try? modelContext.save()
    }
}

// MARK: - Lift Metrics Helper

struct LiftMetrics {
    var bestWeight: Double
    var bestWeightReps: Int
    var oneRepMax: Double
    var maxVolume: Double
    var isManualBestWeight: Bool
    var isManualOneRepMax: Bool
    var isManualMaxVolume: Bool

    var bestWeightFormatted: String {
        guard bestWeight > 0 else { return "-" }
        let w = bestWeight == floor(bestWeight) ? "\(Int(bestWeight))" : String(format: "%.1f", bestWeight)
        return "\(w) x \(bestWeightReps)"
    }

    var oneRepMaxFormatted: String {
        guard oneRepMax > 0 else { return "-" }
        let prefix = isManualOneRepMax ? "" : "~"
        return "\(prefix)\(Int(oneRepMax)) lbs"
    }

    var maxVolumeFormatted: String {
        guard maxVolume > 0 else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: maxVolume)) ?? "0"
        return "\(formatted) lbs"
    }

    // Auto-computed values (ignoring manual overrides)
    var autoBestWeight: Double
    var autoBestWeightReps: Int
    var autoOneRepMax: Double
    var autoMaxVolume: Double

    var autoBestWeightFormatted: String {
        guard autoBestWeight > 0 else { return "-" }
        let w = autoBestWeight == floor(autoBestWeight) ? "\(Int(autoBestWeight))" : String(format: "%.1f", autoBestWeight)
        return "\(w) x \(autoBestWeightReps)"
    }

    var autoOneRepMaxFormatted: String {
        guard autoOneRepMax > 0 else { return "-" }
        return "~\(Int(autoOneRepMax)) lbs"
    }

    var autoMaxVolumeFormatted: String {
        guard autoMaxVolume > 0 else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: autoMaxVolume)) ?? "0"
        return "\(formatted) lbs"
    }

    static func compute(for exercise: Exercise, workouts: [Workout], lift: TrackedLift? = nil) -> LiftMetrics {
        let allSets = completedSets(for: exercise, workouts: workouts)

        // Auto-computed values
        var autoBW: Double = 0
        var autoBWReps: Int = 0
        var autoORM: Double = 0
        var autoMV: Double = 0

        if let best = allSets.max(by: { a, b in
            a.weight < b.weight || (a.weight == b.weight && a.reps < b.reps)
        }) {
            autoBW = best.weight
            autoBWReps = best.reps
        }

        if let best = allSets.max(by: {
            ($0.weight * (1.0 + Double($0.reps) / 30.0)) < ($1.weight * (1.0 + Double($1.reps) / 30.0))
        }) {
            autoORM = best.weight * (1.0 + Double(best.reps) / 30.0)
        }

        if let best = allSets.max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) {
            autoMV = best.weight * Double(best.reps)
        }

        // Apply manual overrides
        let finalBW = lift?.manualBestWeight ?? autoBW
        let finalBWReps = lift?.manualBestWeightReps ?? autoBWReps
        let finalORM = lift?.manualOneRepMax ?? autoORM
        let finalMV = lift?.manualMaxVolume ?? autoMV

        return LiftMetrics(
            bestWeight: finalBW,
            bestWeightReps: finalBWReps,
            oneRepMax: finalORM,
            maxVolume: finalMV,
            isManualBestWeight: lift?.manualBestWeight != nil,
            isManualOneRepMax: lift?.manualOneRepMax != nil,
            isManualMaxVolume: lift?.manualMaxVolume != nil,
            autoBestWeight: autoBW,
            autoBestWeightReps: autoBWReps,
            autoOneRepMax: autoORM,
            autoMaxVolume: autoMV
        )
    }

    static func completedSets(for exercise: Exercise, workouts: [Workout]) -> [(weight: Double, reps: Int)] {
        var result: [(weight: Double, reps: Int)] = []
        for workout in workouts {
            for log in workout.exerciseLogs {
                guard let ex = log.exercise, ex.persistentModelID == exercise.persistentModelID else { continue }
                for set in log.sets where set.isCompleted && set.weight > 0 {
                    result.append((weight: set.weight, reps: set.reps))
                }
            }
        }
        return result
    }
}

#Preview {
    TrackView()
        .modelContainer(for: [Workout.self, Exercise.self, TrackedLift.self], inMemory: true)
}

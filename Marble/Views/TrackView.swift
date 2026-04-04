import SwiftUI
import SwiftData

struct TrackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \TrackedLift.displayOrder) private var trackedLifts: [TrackedLift]
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

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
                    summaryStats
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

    // MARK: - Summary Stats

    private var summaryStats: some View {
        HStack(spacing: 0) {
            statCell(value: "\(workoutsThisWeek)", label: "THIS WEEK")
            statCell(value: "\(currentStreak)", label: "STREAK")
            statCell(value: formattedWeeklyVolume, label: "VOLUME")
        }
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 22).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 9).weight(.light))
                .tracking(0.5)
                .foregroundStyle(Color("marbleSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var workoutsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return workouts.filter { $0.date >= startOfWeek }.count
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's a workout today, if not start from yesterday
        let todayWorkouts = workouts.filter { calendar.isDate($0.date, inSameDayAs: checkDate) }
        if todayWorkouts.isEmpty {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let hasWorkout = workouts.contains { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if hasWorkout {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    private var formattedWeeklyVolume: String {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekWorkouts = workouts.filter { $0.date >= startOfWeek }

        var total: Double = 0
        for workout in weekWorkouts {
            for log in workout.exerciseLogs {
                for set in log.sets where set.isCompleted {
                    total += set.weight * Double(set.reps)
                }
            }
        }

        if total == 0 { return "0" }
        if total >= 1000 {
            let k = total / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(Int(total))"
    }

    // MARK: - Contribution Grid

    private var contributionGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACTIVITY")

            let gridData = buildGridData()

            VStack(spacing: 0) {
                // Month labels row
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 18)

                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            let label = gridData.monthLabels[col]
                            Text(label)
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
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
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
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
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5))
        }
    }

    private struct GridData {
        var cells: [[Bool]]
        var monthLabels: [String]
    }

    private func buildGridData() -> GridData {
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: Date())

        let todayWeekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (todayWeekday + 5) % 7
        guard let currentWeekMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else {
            return GridData(cells: Array(repeating: Array(repeating: false, count: 8), count: 7), monthLabels: Array(repeating: "", count: 8))
        }

        guard let gridStart = calendar.date(byAdding: .weekOfYear, value: -7, to: currentWeekMonday) else {
            return GridData(cells: Array(repeating: Array(repeating: false, count: 8), count: 7), monthLabels: Array(repeating: "", count: 8))
        }

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
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }

            if trackedLifts.isEmpty {
                Text("Tap + to track your lifts")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(trackedLifts, id: \.id) { lift in
                        if let exercise = lift.exercise {
                            NavigationLink(destination: ExerciseLiftDetailView(trackedLift: lift)) {
                                LiftCardView(lift: lift, exercise: exercise, workouts: workouts, weightUnit: weightUnit)
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

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "HISTORY")

            if workouts.isEmpty {
                Text("No workouts yet")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.name)
                                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                                        .foregroundStyle(Color("marblePrimary"))

                                    HStack(spacing: 8) {
                                        Text(historyDateString(workout.date))
                                        Text("·")
                                        Text(formattedDuration(workout.duration))
                                        Text("·")
                                        Text("\(workout.exerciseLogs.count) exercises")
                                    }
                                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                                    .foregroundStyle(Color("marbleSecondary"))
                                }
                                Spacer()
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
                                .fill(Color("marblePrimary").opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }
                }
            }
        }
    }

    private func historyDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Lift Card View

private struct LiftCardView: View {
    let lift: TrackedLift
    let exercise: Exercise
    let workouts: [Workout]
    let weightUnit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Text(metricValue)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 20).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metricLabel)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                .foregroundStyle(Color("marbleSecondary"))
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(minHeight: 110)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5))
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
                            .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color("marbleFieldBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
                                                    .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                                                    .foregroundStyle(Color("marblePrimary"))
                                                Text(exercise.muscleGroup)
                                                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                                                    .foregroundStyle(Color("marbleSecondary"))
                                            }
                                            Spacer()
                                            if isTracked(exercise) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(Color("marblePrimary"))
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if exercise.id != exercises.last?.id {
                                        Rectangle()
                                            .fill(Color("marblePrimary").opacity(0.06))
                                            .frame(height: 0.5)
                                            .padding(.leading, 20)
                                    }
                                }
                            }
                            .overlay(
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundStyle(Color("marblePrimary").opacity(0.06)),
                                alignment: .top
                            )
                            .overlay(
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundStyle(Color("marblePrimary").opacity(0.06)),
                                alignment: .bottom
                            )
                            .padding(.bottom, 24)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Track Exercise")
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 14).weight(.light))
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

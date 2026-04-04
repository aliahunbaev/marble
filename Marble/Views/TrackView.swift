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

            VStack(spacing: 8) {
                // Grid — tight squares
                HStack(spacing: 3) {
                    ForEach(0..<gridData.columns, id: \.self) { col in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                let state = gridData.cells[row][col]
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(
                                        state == .active
                                            ? Color("marblePrimary")
                                            : state == .empty
                                                ? Color("marbleTertiary").opacity(0.5)
                                                : Color.clear
                                    )
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }

                // Summary line
                Text(gridSummary(gridData))
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5))
        }
    }

    private enum CellState {
        case active, empty, future
    }

    private struct GridData {
        var cells: [[CellState]] // [row 0=Mon..6=Sun][col 0=oldest]
        var columns: Int
        var totalWorkouts: Int
        var totalWeeks: Int
    }

    private func buildGridData() -> GridData {
        let calendar = Calendar(identifier: .iso8601)
        let today = calendar.startOfDay(for: Date())
        let numWeeks = 8

        // Find Monday of current week
        let todayWeekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (todayWeekday + 5) % 7
        guard let currentWeekMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today),
              let gridStart = calendar.date(byAdding: .weekOfYear, value: -(numWeeks - 1), to: currentWeekMonday) else {
            return GridData(cells: Array(repeating: Array(repeating: .empty, count: numWeeks), count: 7), columns: numWeeks, totalWorkouts: 0, totalWeeks: numWeeks)
        }

        var workoutDates = Set<Date>()
        for workout in workouts {
            workoutDates.insert(calendar.startOfDay(for: workout.date))
        }

        var cells = Array(repeating: Array(repeating: CellState.future, count: numWeeks), count: 7)
        var totalWorkouts = 0

        for col in 0..<numWeeks {
            guard let weekStart = calendar.date(byAdding: .day, value: col * 7, to: gridStart) else { continue }
            for row in 0..<7 {
                guard let cellDate = calendar.date(byAdding: .day, value: row, to: weekStart) else { continue }
                if cellDate > today {
                    cells[row][col] = .future
                } else if workoutDates.contains(cellDate) {
                    cells[row][col] = .active
                    totalWorkouts += 1
                } else {
                    cells[row][col] = .empty
                }
            }
        }

        return GridData(cells: cells, columns: numWeeks, totalWorkouts: totalWorkouts, totalWeeks: numWeeks)
    }

    private func gridSummary(_ data: GridData) -> String {
        let workouts = data.totalWorkouts
        let weeks = data.totalWeeks
        if workouts == 0 {
            return "No workouts in the last \(weeks) weeks"
        }
        let avg = Double(workouts) / Double(weeks)
        let avgStr = avg == floor(avg) ? "\(Int(avg))" : String(format: "%.1f", avg)
        return "\(workouts) workouts · \(avgStr)/week"
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

    var body: some View {
        let metrics = LiftMetrics.compute(for: exercise, workouts: workouts, lift: lift)
        let trend = computeTrend(metrics: metrics)

        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Text(metricValue(metrics))
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 20).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                Text(metricLabel)
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .tracking(0.3)

                if let trend {
                    Text(trend)
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 10).weight(.light))
                        .foregroundStyle(trend.hasPrefix("+") ? Color.green.opacity(0.8) : Color("marbleSecondary"))
                }
            }
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

    private func metricValue(_ metrics: LiftMetrics) -> String {
        switch lift.metricType {
        case "bestWeight": return metrics.bestWeightFormatted
        case "oneRepMax": return metrics.oneRepMaxFormatted
        case "maxVolume": return metrics.maxVolumeFormatted
        default: return metrics.bestWeightFormatted
        }
    }

    // Compare current best to previous best (before last workout)
    private func computeTrend(metrics: LiftMetrics) -> String? {
        let exerciseID = exercise.persistentModelID

        // Filter workouts containing this exercise with completed sets
        let relevantWorkouts: [Workout] = workouts.filter { workout in
            for log in workout.exerciseLogs {
                guard log.exercise?.persistentModelID == exerciseID else { continue }
                for s in log.sets where s.isCompleted && s.weight > 0 {
                    return true
                }
            }
            return false
        }
        guard relevantWorkouts.count >= 2 else { return nil }

        let latestSets = setsFromWorkout(relevantWorkouts[0])
        let previousWorkouts = Array(relevantWorkouts.dropFirst())
        var allPreviousSets: [(weight: Double, reps: Int)] = []
        for w in previousWorkouts {
            allPreviousSets.append(contentsOf: setsFromWorkout(w))
        }

        switch lift.metricType {
        case "bestWeight":
            guard let latest = latestSets.max(by: { $0.weight < $1.weight }),
                  let prevBest = allPreviousSets.max(by: { $0.weight < $1.weight }) else { return nil }
            return formatDelta(current: latest.weight, previous: prevBest.weight)

        case "oneRepMax":
            let latestORM: Double = latestSets.map { s in s.weight * (1.0 + Double(s.reps) / 30.0) }.max() ?? 0
            let prevORM: Double = allPreviousSets.map { s in s.weight * (1.0 + Double(s.reps) / 30.0) }.max() ?? 0
            guard latestORM > 0, prevORM > 0 else { return nil }
            return formatDelta(current: latestORM, previous: prevORM)

        case "maxVolume":
            let latestVol: Double = latestSets.map { s in s.weight * Double(s.reps) }.max() ?? 0
            let prevVol: Double = allPreviousSets.map { s in s.weight * Double(s.reps) }.max() ?? 0
            guard latestVol > 0, prevVol > 0 else { return nil }
            return formatDelta(current: latestVol, previous: prevVol)

        default:
            return nil
        }
    }

    private func setsFromWorkout(_ workout: Workout) -> [(weight: Double, reps: Int)] {
        workout.exerciseLogs
            .filter { $0.exercise?.persistentModelID == exercise.persistentModelID }
            .flatMap { $0.sets.filter { $0.isCompleted && $0.weight > 0 } }
            .map { (weight: $0.weight, reps: $0.reps) }
    }

    private func formatDelta(current: Double, previous: Double) -> String? {
        guard previous > 0 else { return nil }
        let pct = ((current - previous) / previous) * 100
        guard abs(pct) >= 0.5 else { return nil } // ignore noise
        if pct > 0 {
            return "+\(Int(round(pct)))%"
        } else {
            return "\(Int(round(pct)))%"
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

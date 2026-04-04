import SwiftUI
import SwiftData

struct ExerciseLiftDetailView: View {
    @Bindable var trackedLift: TrackedLift
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var showingManualEntry = false
    @State private var manualWeightText = ""
    @State private var manualRepsText = ""
    @State private var manualValueText = ""

    private var exercise: Exercise? { trackedLift.exercise }

    private var metrics: LiftMetrics {
        guard let exercise else {
            return LiftMetrics(
                bestWeight: 0, bestWeightReps: 0, oneRepMax: 0, maxVolume: 0,
                isManualBestWeight: false, isManualOneRepMax: false, isManualMaxVolume: false,
                autoBestWeight: 0, autoBestWeightReps: 0, autoOneRepMax: 0, autoMaxVolume: 0
            )
        }
        return LiftMetrics.compute(for: exercise, workouts: workouts, lift: trackedLift)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Exercise name
                if let exercise {
                    Text(exercise.name)
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 24).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                // Metric cards
                metricCardsSection

                // Manual entry section
                manualEntrySection

                // History
                historySection

                // Remove button
                Button(role: .destructive) {
                    modelContext.delete(trackedLift)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    Text("Remove from Tracking")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color("marbleBackground"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(manualEntryTitle, isPresented: $showingManualEntry) {
            manualEntryAlertContent
        } message: {
            Text("Enter value manually")
        }
    }

    // MARK: - Metric Cards

    private var metricCardsSection: some View {
        HStack(spacing: 8) {
            MetricTile(
                title: "Best Weight",
                value: metrics.bestWeightFormatted,
                isSelected: trackedLift.metricType == "bestWeight",
                isManual: metrics.isManualBestWeight
            ) {
                trackedLift.metricType = "bestWeight"
                try? modelContext.save()
            }

            MetricTile(
                title: "Est. 1RM",
                value: metrics.oneRepMaxFormatted,
                isSelected: trackedLift.metricType == "oneRepMax",
                isManual: metrics.isManualOneRepMax
            ) {
                trackedLift.metricType = "oneRepMax"
                try? modelContext.save()
            }

            MetricTile(
                title: "Max Volume",
                value: metrics.maxVolumeFormatted,
                isSelected: trackedLift.metricType == "maxVolume",
                isManual: metrics.isManualMaxVolume
            ) {
                trackedLift.metricType = "maxVolume"
                try? modelContext.save()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Manual Entry Section

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "RECORD MANUALLY")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                // Current metric manual entry
                manualEntryRow

                // Show auto value for comparison if manual exists
                if hasManualValueForCurrentMetric {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.leading, 14)

                    HStack {
                        Text("From workouts")
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                            .foregroundStyle(Color("marbleSecondary"))
                        Spacer()
                        Text(autoValueForCurrentMetric)
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
        }
    }

    private var manualEntryRow: some View {
        HStack {
            if hasManualValueForCurrentMetric {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(manualValueForCurrentMetric)
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 14).weight(.light))
                            .foregroundStyle(Color("marblePrimary"))
                        Text("Manual")
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 9).weight(.light))
                            .foregroundStyle(Color("marbleSecondary"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    }
                }

                Spacer()

                Button {
                    clearManualValue()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(width: 28, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    prepareManualEntry()
                    showingManualEntry = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .light))
                        Text("Record \(currentMetricName)")
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                    }
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Manual Entry Helpers

    private var currentMetricName: String {
        switch trackedLift.metricType {
        case "bestWeight": return "Best Weight"
        case "oneRepMax": return "1RM"
        case "maxVolume": return "Max Volume"
        default: return "Best Weight"
        }
    }

    private var hasManualValueForCurrentMetric: Bool {
        switch trackedLift.metricType {
        case "bestWeight": return trackedLift.manualBestWeight != nil
        case "oneRepMax": return trackedLift.manualOneRepMax != nil
        case "maxVolume": return trackedLift.manualMaxVolume != nil
        default: return false
        }
    }

    private var manualValueForCurrentMetric: String {
        switch trackedLift.metricType {
        case "bestWeight":
            if let w = trackedLift.manualBestWeight, let r = trackedLift.manualBestWeightReps {
                let ws = w == floor(w) ? "\(Int(w))" : String(format: "%.1f", w)
                return "\(ws) x \(r)"
            }
            return "-"
        case "oneRepMax":
            if let v = trackedLift.manualOneRepMax {
                return "\(Int(v)) lbs"
            }
            return "-"
        case "maxVolume":
            if let v = trackedLift.manualMaxVolume {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 0
                return "\(formatter.string(from: NSNumber(value: v)) ?? "0") lbs"
            }
            return "-"
        default: return "-"
        }
    }

    private var autoValueForCurrentMetric: String {
        switch trackedLift.metricType {
        case "bestWeight": return metrics.autoBestWeightFormatted
        case "oneRepMax": return metrics.autoOneRepMaxFormatted
        case "maxVolume": return metrics.autoMaxVolumeFormatted
        default: return "-"
        }
    }

    private var manualEntryTitle: String {
        "Record \(currentMetricName)"
    }

    private func prepareManualEntry() {
        manualWeightText = ""
        manualRepsText = ""
        manualValueText = ""
    }

    @ViewBuilder
    private var manualEntryAlertContent: some View {
        if trackedLift.metricType == "bestWeight" {
            TextField("Weight (lbs)", text: $manualWeightText)
                .keyboardType(.decimalPad)
            TextField("Reps", text: $manualRepsText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let w = Double(manualWeightText), let r = Int(manualRepsText) {
                    trackedLift.manualBestWeight = w
                    trackedLift.manualBestWeightReps = r
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        } else {
            TextField("Value (lbs)", text: $manualValueText)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let v = Double(manualValueText) {
                    switch trackedLift.metricType {
                    case "oneRepMax":
                        trackedLift.manualOneRepMax = v
                    case "maxVolume":
                        trackedLift.manualMaxVolume = v
                    default: break
                    }
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func clearManualValue() {
        switch trackedLift.metricType {
        case "bestWeight":
            trackedLift.manualBestWeight = nil
            trackedLift.manualBestWeightReps = nil
        case "oneRepMax":
            trackedLift.manualOneRepMax = nil
        case "maxVolume":
            trackedLift.manualMaxVolume = nil
        default: break
        }
        try? modelContext.save()
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "HISTORY")
                .padding(.horizontal, 20)

            let performances = computePerformances()

            if performances.isEmpty {
                Text("No data yet")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(performances.enumerated()), id: \.offset) { index, perf in
                        HStack(alignment: .top) {
                            Text(perf.dateString)
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                                .foregroundStyle(Color("marbleSecondary"))
                                .frame(width: 56, alignment: .leading)

                            Text(perf.setsDescription)
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                                .foregroundStyle(Color("marblePrimary"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if index < performances.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, 14)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private struct PerformanceEntry {
        let date: Date
        let sets: [(weight: Double, reps: Int)]

        var dateString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }

        var setsDescription: String {
            // Group identical sets: "3x225x8, 2x225x6"
            var grouped: [(count: Int, weight: Double, reps: Int)] = []
            for s in sets {
                if let lastIdx = grouped.indices.last,
                   grouped[lastIdx].weight == s.weight && grouped[lastIdx].reps == s.reps {
                    grouped[lastIdx].count += 1
                } else {
                    grouped.append((count: 1, weight: s.weight, reps: s.reps))
                }
            }
            return grouped.map { g in
                let w = g.weight == floor(g.weight) ? "\(Int(g.weight))" : String(format: "%.1f", g.weight)
                return "\(g.count)x\(w)x\(g.reps)"
            }.joined(separator: ", ")
        }
    }

    private func computePerformances() -> [PerformanceEntry] {
        guard let exercise else { return [] }
        var entries: [PerformanceEntry] = []

        for workout in workouts {
            for log in workout.exerciseLogs {
                guard let ex = log.exercise, ex.persistentModelID == exercise.persistentModelID else { continue }
                let completedSets = log.sets.filter { $0.isCompleted && $0.weight > 0 }
                guard !completedSets.isEmpty else { continue }
                let setData = completedSets.map { (weight: $0.weight, reps: $0.reps) }
                entries.append(PerformanceEntry(date: workout.date, sets: setData))
            }
        }

        return entries
    }
}

// MARK: - Metric Tile

private struct MetricTile: View {
    let title: String
    let value: String
    let isSelected: Bool
    let isManual: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 14).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 9).weight(.light))
                .foregroundStyle(Color("marbleSecondary"))
                .lineLimit(1)

            if isManual {
                Text("Manual")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 8).weight(.light))
                    .foregroundStyle(Color("marbleAccent"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color("marbleAccent") : Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseLiftDetailView(trackedLift: TrackedLift(exercise: Exercise(name: "Bench Press", muscleGroup: "Chest")))
    }
    .modelContainer(for: [Workout.self, Exercise.self, TrackedLift.self], inMemory: true)
}

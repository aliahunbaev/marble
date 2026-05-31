import SwiftUI
import SwiftData

/// Detail view a tracked lift's card opens into. Mirrors the structure of
/// BodyweightDetailView so all detail surfaces feel cohesive:
///   - Tonal gradient background (matches Track/Train/You)
///   - Header: exercise name in editorial body typography
///   - Metric tiles: 3 small glass cards for choosing which metric headlines
///     the lift card back on the Track tab
///   - Manual entry: editorial form for overriding the auto-computed value
///   - History: chronological list of workout performances, swipe-to-delete
///   - Remove: marbleDestructiveButton at the bottom
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
            VStack(alignment: .leading, spacing: 32) {
                // Header
                if let exercise {
                    Text(exercise.name)
                        .font(.marbleBody(28))
                        .foregroundStyle(Color("marblePrimary"))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                metricTilesSection
                    .padding(.horizontal, 20)

                manualEntrySection
                    .padding(.horizontal, 20)

                historySection

                Button {
                    let cloudID = trackedLift.cloudID
                    modelContext.delete(trackedLift)
                    try? modelContext.save()
                    CloudSyncService.shared.deleteTrackedLift(cloudID: cloudID)
                    dismiss()
                } label: {
                    Text("REMOVE FROM TRACKING")
                        .marbleDestructiveButton()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 140)
        }
        .marbleAtmosphereBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert(manualEntryTitle, isPresented: $showingManualEntry) {
            manualEntryAlertContent
        } message: {
            Text("Enter value manually")
        }
        .onDisappear {
            CloudSyncService.shared.uploadTrackedLift(trackedLift)
        }
    }

    // MARK: - Metric Tiles

    /// Three small selectable tiles. The selected one drives what shows on
    /// the lift card back on the Track tab. Glass treatment matches the
    /// rest of the app's chrome.
    private var metricTilesSection: some View {
        HStack(spacing: 10) {
            metricTile(
                title: "BEST WEIGHT",
                value: metrics.bestWeightFormatted,
                isSelected: trackedLift.metricType == "bestWeight",
                isManual: metrics.isManualBestWeight
            ) {
                trackedLift.metricType = "bestWeight"
                try? modelContext.save()
            }

            metricTile(
                title: "EST. 1RM",
                value: metrics.oneRepMaxFormatted,
                isSelected: trackedLift.metricType == "oneRepMax",
                isManual: metrics.isManualOneRepMax
            ) {
                trackedLift.metricType = "oneRepMax"
                try? modelContext.save()
            }

            metricTile(
                title: "MAX VOLUME",
                value: metrics.maxVolumeFormatted,
                isSelected: trackedLift.metricType == "maxVolume",
                isManual: metrics.isManualMaxVolume
            ) {
                trackedLift.metricType = "maxVolume"
                try? modelContext.save()
            }
        }
    }

    private func metricTile(
        title: String,
        value: String,
        isSelected: Bool,
        isManual: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.marbleBody(18))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Text(title)
                        .font(.marbleMono(9))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if isManual {
                        Text("·")
                            .font(.marbleMono(9))
                            .foregroundStyle(Color("marbleTertiary"))
                        Text("MANUAL")
                            .font(.marbleMono(9))
                            .tracking(1)
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .frame(height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .marbleLiquidGlassCard(cornerRadius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color("marblePrimary").opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual Entry

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "RECORD MANUALLY")

            VStack(spacing: 0) {
                manualEntryRow

                if hasManualValueForCurrentMetric {
                    Rectangle()
                        .fill(Color("marblePrimary").opacity(0.06))
                        .frame(height: 0.5)

                    HStack {
                        Text("From workouts")
                            .font(.marbleMono(11))
                            .foregroundStyle(Color("marbleSecondary"))
                        Spacer()
                        Text(autoValueForCurrentMetric)
                            .font(.marbleMono(13))
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .marbleLiquidGlassCard(cornerRadius: 12)
        }
    }

    private var manualEntryRow: some View {
        HStack {
            if hasManualValueForCurrentMetric {
                HStack(spacing: 8) {
                    Text(manualValueForCurrentMetric)
                        .font(.marbleBody(15))
                        .foregroundStyle(Color("marblePrimary"))
                    Text("MANUAL")
                        .font(.marbleMono(9))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color("marblePrimary").opacity(0.18), lineWidth: 0.5)
                        )
                }

                Spacer()

                Button {
                    clearManualValue()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .regular))
                        .marbleGlassCapsule(size: 30)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    prepareManualEntry()
                    showingManualEntry = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .regular))
                        Text("RECORD \(currentMetricName.uppercased())")
                            .font(.marbleMono(11))
                            .tracking(1)
                    }
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                return "\(ws) × \(r)"
            }
            return "—"
        case "oneRepMax":
            if let v = trackedLift.manualOneRepMax {
                return "\(Int(v)) lb"
            }
            return "—"
        case "maxVolume":
            if let v = trackedLift.manualMaxVolume {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.maximumFractionDigits = 0
                return "\(formatter.string(from: NSNumber(value: v)) ?? "0") lb"
            }
            return "—"
        default: return "—"
        }
    }

    private var autoValueForCurrentMetric: String {
        switch trackedLift.metricType {
        case "bestWeight": return metrics.autoBestWeightFormatted
        case "oneRepMax": return metrics.autoOneRepMaxFormatted
        case "maxVolume": return metrics.autoMaxVolumeFormatted
        default: return "—"
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
            TextField("Weight (lb)", text: $manualWeightText)
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
            TextField("Value (lb)", text: $manualValueText)
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
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "HISTORY")
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            let performances = computePerformances()

            if performances.isEmpty {
                VStack(spacing: 6) {
                    Text("No history yet.")
                        .font(.marbleBody(15))
                        .foregroundStyle(Color("marbleSecondary"))
                    Text("Log this lift in a workout.")
                        .font(.marbleMono(11))
                        .tracking(1)
                        .foregroundStyle(Color("marbleTertiary"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(performances.enumerated()), id: \.offset) { index, perf in
                        HStack(alignment: .top, spacing: 16) {
                            Text(perf.dateString)
                                .font(.marbleMono(13))
                                .foregroundStyle(Color("marbleSecondary"))
                                .frame(width: 68, alignment: .leading)

                            Text(perf.setsDescription)
                                .font(.marbleBody(15))
                                .foregroundStyle(Color("marblePrimary"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                        if index < performances.count - 1 {
                            Rectangle()
                                .fill(Color("marblePrimary").opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }

    private struct PerformanceEntry {
        let date: Date
        let sets: [(weight: Double, reps: Int)]

        var dateString: String {
            date.marbleRelative()
        }

        var setsDescription: String {
            // Group identical sets: "3 × 225 × 8, 2 × 225 × 6"
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
                return "\(g.count) × \(w) × \(g.reps)"
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

#Preview {
    NavigationStack {
        ExerciseLiftDetailView(trackedLift: TrackedLift(exercise: Exercise(name: "Bench Press", muscleGroup: "Chest")))
    }
    .modelContainer(for: [Workout.self, Exercise.self, TrackedLift.self], inMemory: true)
}

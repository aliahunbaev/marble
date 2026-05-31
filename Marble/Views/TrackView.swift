import SwiftUI
import SwiftData

/// Track tab — "portfolio of strength." Two sections:
///   1. THE MONTH — compact dot grid of training rhythm. Swipeable
///      horizontally to scroll through prior months. Each dot = one day,
///      filled = workout. Glowing dots in marblePrimary (mode-adaptive).
///   2. MY LIFTS — each tracked lift as an editorial row with sparkline.
///
/// Bodyweight lives on YOU tab (it's identity-adjacent, not training output).
/// Modularity was rejected on purpose. This is curation, not configuration.
struct TrackView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorSchemeForGradient
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \TrackedLift.displayOrder) private var trackedLifts: [TrackedLift]
    @Query(sort: \BodyweightEntry.date, order: .reverse) private var bodyweightEntries: [BodyweightEntry]
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    @State private var showingAddLift = false
    @State private var showingLogBodyweight = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Tonal-only vertical gradient — same treatment as YOU tab.
                // Without color variation behind them, the glass lift cards
                // have nothing to refract and read as flat outlines.
                Color("marbleBackground")
                    .ignoresSafeArea()

                LinearGradient(
                    colors: colorSchemeForGradient == .dark
                        ? [
                            Color(red: 0.13, green: 0.12, blue: 0.11),
                            Color("marbleBackground"),
                            Color(red: 0.10, green: 0.10, blue: 0.11)
                          ]
                        : [
                            Color(red: 0.97, green: 0.95, blue: 0.92),
                            Color("marbleBackground"),
                            Color(red: 0.94, green: 0.94, blue: 0.95)
                          ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        TheMonthHero(workouts: workouts)
                            .padding(.top, 16)

                        myLiftsSection
                            .padding(.horizontal, 20)

                        bodyweightCard
                            .padding(.horizontal, 20)

                        if let observation = topTrackObservation {
                            TrackObservationCard(observation: observation)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 140) // breathing room above the tab bar glass
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddLift) {
                AddTrackedLiftSheet(trackedLifts: trackedLifts)
            }
            .sheet(isPresented: $showingLogBodyweight) {
                LogBodyweightSheet()
            }
        }
    }

    // MARK: - Bodyweight Card

    /// Full-width glass card. Title left, current weight + unit hero, small
    /// sparkline showing trend across the last 90 days. Tap → log sheet.
    /// Bodyweight is a trend metric (trajectory matters more than any single
    /// value), unlike lifts which are PR metrics — hence the sparkline.
    private var bodyweightCard: some View {
        Button {
            showingLogBodyweight = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("BODYWEIGHT")
                    .font(.marbleMono(11))
                    .tracking(1.5)
                    .foregroundStyle(Color("marbleSecondary"))

                Spacer(minLength: 8)

                if let latest = bodyweightEntries.first {
                    let displayWeight = weightUnit == "kg" ? latest.weight / 2.20462 : latest.weight
                    let formattedWeight = displayWeight == floor(displayWeight)
                        ? "\(Int(displayWeight))"
                        : String(format: "%.1f", displayWeight)
                    let unit = weightUnit == "kg" ? "KG" : "LB"

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedWeight)
                            .font(.marbleBody(40))
                            .foregroundStyle(Color("marblePrimary"))
                        Text(unit)
                            .font(.marbleMono(13))
                            .tracking(1.5)
                            .foregroundStyle(Color("marbleSecondary"))
                        Spacer()
                        BodyweightSparkline(entries: bodyweightEntriesForChart)
                            .frame(width: 110, height: 36)
                    }
                } else {
                    // Empty — invite to log
                    Text("TAP TO LOG")
                        .font(.marbleMono(13))
                        .tracking(1.5)
                        .foregroundStyle(Color("marbleSecondary"))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .marbleLiquidGlassCard(cornerRadius: 16)
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Last 90 days of entries for the sparkline, oldest-first so the line
    /// reads left-to-right as old → new.
    private var bodyweightEntriesForChart: [BodyweightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return bodyweightEntries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    // MARK: - TrackObservation (auto-detected)

    /// Computes the most-notable movement this month vs last month and
    /// returns it as an TrackObservation. Returns nil if there's no movement
    /// worth noting (new user, flat data, no comparable history).
    ///
    /// Priority: largest positive % delta across tracked lifts (using each
    /// lift's configured metric type). Falls back to bodyweight delta if
    /// no positive lift movement exists.
    private var topTrackObservation: TrackObservation? {
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()
        guard let thisMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else { return nil }
        guard let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else { return nil }

        // Best positive % delta across tracked lifts
        var bestLiftDelta: (title: String, pct: Double)?
        for lift in trackedLifts {
            guard let exercise = lift.exercise else { continue }
            let thisMonthBest = bestMetric(for: exercise, lift: lift, in: thisMonthStart..<now)
            let lastMonthBest = bestMetric(for: exercise, lift: lift, in: lastMonthStart..<thisMonthStart)
            guard thisMonthBest > 0, lastMonthBest > 0 else { continue }
            let pct = ((thisMonthBest - lastMonthBest) / lastMonthBest) * 100
            guard pct >= 1 else { continue } // ignore noise under 1%
            if bestLiftDelta == nil || pct > bestLiftDelta!.pct {
                bestLiftDelta = (exercise.name.uppercased(), pct)
            }
        }

        if let lift = bestLiftDelta {
            return TrackObservation(
                title: lift.title,
                delta: "+\(Int(round(lift.pct)))%",
                period: "THIS MONTH"
            )
        }

        // Fallback: bodyweight % delta (sign preserved — show ± for body)
        let thisMonthBody = bodyweightEntries
            .filter { $0.date >= thisMonthStart && $0.date < now }
            .last?.weight
        let lastMonthBody = bodyweightEntries
            .filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
            .last?.weight
        if let now = thisMonthBody, let prev = lastMonthBody, prev > 0 {
            let pct = ((now - prev) / prev) * 100
            if abs(pct) >= 0.5 {
                let sign = pct > 0 ? "+" : ""
                return TrackObservation(
                    title: "BODYWEIGHT",
                    delta: "\(sign)\(String(format: "%.1f", pct))%",
                    period: "THIS MONTH"
                )
            }
        }

        return nil
    }

    /// Best metric value for a given lift within a date range, using the
    /// lift's configured metric type (bestWeight / oneRepMax / maxVolume).
    private func bestMetric(for exercise: Exercise, lift: TrackedLift, in range: Range<Date>) -> Double {
        let exerciseID = exercise.persistentModelID
        let sets: [(weight: Double, reps: Int)] = workouts
            .filter { range.contains($0.date) }
            .flatMap { workout -> [(weight: Double, reps: Int)] in
                workout.exerciseLogs
                    .filter { $0.exercise?.persistentModelID == exerciseID }
                    .flatMap { $0.sets.filter { $0.isCompleted && $0.weight > 0 } }
                    .map { (weight: $0.weight, reps: $0.reps) }
            }
        guard !sets.isEmpty else { return 0 }

        switch lift.metricType {
        case "oneRepMax":
            return sets.map { $0.weight * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0
        case "maxVolume":
            return sets.map { $0.weight * Double($0.reps) }.max() ?? 0
        default:
            return sets.map(\.weight).max() ?? 0
        }
    }

    // MARK: - My Lifts

    /// Editorial rows — each tracked lift gets a full-width row with its
    /// name on the left, current best metric on the right, and a subtle
    /// sparkline of recent history beneath. Tap to drill into the full chart.
    private var myLiftsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(title: "MY LIFTS")
                Spacer()
                Button {
                    showingAddLift = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                        .marbleGlassCapsule(size: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            if trackedLifts.isEmpty {
                Text("Tap + to track your lifts")
                    .font(.marbleMono(13))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                // 2-column grid of cards. Each card hero: the metric value.
                // Sparklines moved into the tap-in detail view — the card
                // is for scanning, the detail is for studying.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(trackedLifts) { lift in
                        if let exercise = lift.exercise {
                            NavigationLink(destination: ExerciseLiftDetailView(trackedLift: lift)) {
                                LiftCardView(lift: lift, exercise: exercise, workouts: workouts)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    let cloudID = lift.cloudID
                                    modelContext.delete(lift)
                                    try? modelContext.save()
                                    CloudSyncService.shared.deleteTrackedLift(cloudID: cloudID)
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

// MARK: - The Month (Hero)

/// Compact dot grid of training rhythm. 10 columns wide, rows scale with
/// month length (28 → 3 rows, 31 → 4 rows). Each dot = one day; filled
/// dots glow in marblePrimary (mode-adaptive). Binary on/off — no volume
/// tiers. Horizontal swipe pages through prior months.
private struct TheMonthHero: View {
    let workouts: [Workout]

    @State private var selectedMonthOffset: Int = 0
    private let monthsBack: Int = 24

    /// Map start-of-day → bool indicating a workout happened that day.
    /// Binary now (volume tiers were removed — added noise without info).
    private var workoutDays: Set<Date> {
        let calendar = Calendar(identifier: .iso8601)
        var days = Set<Date>()
        for workout in workouts {
            let hasCompletedSets = workout.exerciseLogs.contains { log in
                log.sets.contains(where: \.isCompleted)
            }
            if hasCompletedSets {
                days.insert(calendar.startOfDay(for: workout.date))
            }
        }
        return days
    }

    var body: some View {
        TabView(selection: $selectedMonthOffset) {
            ForEach((-monthsBack...0).reversed(), id: \.self) { offset in
                MonthDotPage(
                    monthOffset: offset,
                    workoutDays: workoutDays
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 200)
        .onAppear { selectedMonthOffset = 0 }
    }
}

/// One month rendered as a 10-column grid of tight filled squares. No
/// day-of-week constraint — cells are laid out as a "block of days,"
/// compact and abstract. Reads as a record being inscribed, not a
/// calendar. Squares (not dots-with-glow) — mode-symmetric, tactile.
private struct MonthDotPage: View {
    let monthOffset: Int  // 0 = current month, -1 = last month, etc.
    let workoutDays: Set<Date>

    private let columnsPerRow = 10
    private let cellSpacing: CGFloat = 6

    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private var monthAnchor: Date {
        let today = calendar.startOfDay(for: Date())
        let baseFirst = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        return calendar.date(byAdding: .month, value: monthOffset, to: baseFirst) ?? baseFirst
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthAnchor).uppercased()
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var workoutCount: Int {
        (1...daysInMonth).reduce(0) { acc, dayNumber in
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthAnchor) else { return acc }
            return acc + (workoutDays.contains(date) ? 1 : 0)
        }
    }

    /// Stat line under the grid: workouts this month + per-week cadence.
    /// For the current month, cadence is over ELAPSED weeks so it isn't
    /// artificially deflated early in the month.
    private var statLine: String {
        if workoutCount == 0 {
            return monthOffset == 0 ? "No workouts yet this month" : "No workouts"
        }

        let weeksElapsed: Double
        if monthOffset == 0 {
            let daysElapsed = (calendar.dateComponents([.day], from: monthAnchor, to: today).day ?? 0) + 1
            weeksElapsed = max(1, Double(daysElapsed)) / 7.0
        } else {
            weeksElapsed = Double(daysInMonth) / 7.0
        }
        let perWeek = Double(workoutCount) / weeksElapsed
        let avgStr = perWeek == floor(perWeek) ? "\(Int(perWeek))" : String(format: "%.1f", perWeek)
        let unit = workoutCount == 1 ? "workout" : "workouts"
        return "\(workoutCount) \(unit) · \(avgStr)/week"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Month label
            Text(monthLabel)
                .font(.marbleMono(11))
                .tracking(2)
                .foregroundStyle(Color("marbleSecondary"))
                .padding(.horizontal, 24)

            // Cell grid — flexible 10 columns that span the full available
            // width. Each cell is square (aspectRatio 1:1) and sized
            // automatically by the LazyVGrid layout.
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: cellSpacing), count: columnsPerRow),
                spacing: cellSpacing
            ) {
                ForEach(1...daysInMonth, id: \.self) { dayNumber in
                    let cellDate = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthAnchor) ?? monthAnchor
                    DayCell(
                        didWorkout: workoutDays.contains(cellDate),
                        isToday: calendar.isDate(cellDate, inSameDayAs: today),
                        isFuture: cellDate > today
                    )
                }
            }
            .padding(.horizontal, 24)

            // Stat line
            Text(statLine)
                .font(.marbleMono(11))
                .foregroundStyle(Color("marbleSecondary"))
                .padding(.horizontal, 24)
        }
    }
}

/// A single day cell in the grid. Three states:
///   - Workout day: filled square in marblePrimary
///   - Rest day (past): faint outlined square at very low opacity
///   - Future: faintest possible outline (preserves grid shape)
/// Today is hinted with a slightly stronger outline when it's a rest day,
/// or inset highlight when a workout day. Squares (not dots) — tactile,
/// mode-symmetric, no glow asymmetry between light and dark.
private struct DayCell: View {
    let didWorkout: Bool
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        let radius: CGFloat = 3

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    didWorkout
                        ? Color("marblePrimary")
                        : Color("marblePrimary").opacity(isFuture ? 0.06 : 0.10)
                )

            // Today: hairline ring on top — visible regardless of workout state.
            if isToday {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        didWorkout
                            ? Color("marbleBackground").opacity(0.5)
                            : Color("marblePrimary").opacity(0.5),
                        lineWidth: 0.75
                    )
                    .padding(1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Lift Card View

/// One tracked lift as a square-ish card in the 2-column grid. The metric
/// value is the hero — name above, value below, big. No sparkline on the
/// card — that's what the tap-in detail view is for. Each card scans in a
/// glance; the detail view is for studying. Cards are visually consistent:
/// same size, same structure, no per-lift size customization.
private struct LiftCardView: View {
    let lift: TrackedLift
    let exercise: Exercise
    let workouts: [Workout]

    var body: some View {
        let metrics = LiftMetrics.compute(for: exercise, workouts: workouts, lift: lift)

        VStack(alignment: .leading, spacing: 4) {
            // Exercise name
            Text(exercise.name)
                .font(.marbleBody(15))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            // Metric value — the hero
            Text(metricValue(metrics))
                .font(.marbleBody(32))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            // Metric label
            Text(metricLabel)
                .font(.marbleMono(10))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .marbleLiquidGlassCard(cornerRadius: 16)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metricLabel: String {
        switch lift.metricType {
        case "bestWeight": return "BEST WEIGHT"
        case "maxVolume": return "MAX VOLUME"
        case "oneRepMax": return "EST. 1RM"
        default: return "BEST WEIGHT"
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
}

// MARK: - TrackObservation

/// A single auto-detected movement worth reporting back to the user.
/// Stocks-style: title + delta + period. No goals, no setup, no streaks —
/// just "your training, observed."
struct TrackObservation {
    let title: String   // e.g. "BENCH PRESS"
    let delta: String   // e.g. "+12%"
    let period: String  // e.g. "THIS MONTH"
}

/// Full-width card showing one observation. Hidden entirely (not rendered)
/// when there's nothing worth saying — no empty-state apology, no
/// philosophical filler. Same glass treatment + height bracket as the
/// bodyweight card so the two read as siblings.
private struct TrackObservationCard: View {
    let observation: TrackObservation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("OBSERVATION")
                .font(.marbleMono(11))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            Spacer(minLength: 8)

            // Delta as hero. Stocks-style.
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(observation.delta)
                    .font(.marbleBody(40))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(observation.title)
                        .font(.marbleMono(11))
                        .tracking(1.5)
                        .foregroundStyle(Color("marblePrimary"))
                    Text(observation.period)
                        .font(.marbleMono(10))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .marbleLiquidGlassCard(cornerRadius: 16)
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Bodyweight Sparkline

/// Minimal line chart of bodyweight entries. No axes, no labels — just the
/// shape of the trend. Editorial restraint over data-dashboard density.
private struct BodyweightSparkline: View {
    let entries: [BodyweightEntry]

    var body: some View {
        GeometryReader { geo in
            if entries.count >= 2 {
                let weights = entries.map(\.weight)
                let minW = weights.min() ?? 0
                let maxW = weights.max() ?? 1
                let range = max(maxW - minW, 1)
                let stepX = geo.size.width / CGFloat(max(entries.count - 1, 1))

                let points: [CGPoint] = entries.enumerated().map { i, entry in
                    let x = CGFloat(i) * stepX
                    let normalized = (entry.weight - minW) / range
                    let y = geo.size.height * (1 - CGFloat(normalized))
                    return CGPoint(x: x, y: y)
                }

                ZStack {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color("marblePrimary").opacity(0.6), lineWidth: 1.2)

                    if let last = points.last {
                        Circle()
                            .fill(Color("marblePrimary"))
                            .frame(width: 4, height: 4)
                            .position(last)
                    }
                }
            } else if entries.count == 1 {
                // Single value — flat dashed line so the area isn't empty.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color("marblePrimary").opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
        }
    }
}

// MARK: - Log Bodyweight Sheet

/// Modal for logging a new bodyweight entry. Single number input,
/// decimal keyboard, today's date implicit. Lives in TrackView because
/// bodyweight is one of the things you track.
private struct LogBodyweightSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    @State private var weightText: String = ""
    @FocusState private var fieldFocused: Bool

    private var parsedWeight: Double? {
        Double(weightText.trimmingCharacters(in: .whitespaces))
    }

    private var unitLabel: String { weightUnit == "kg" ? "KG" : "LB" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text("LOG BODYWEIGHT")
                        .font(.marbleMono(11))
                        .tracking(2)
                        .foregroundStyle(Color("marbleSecondary"))

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $weightText)
                            .font(.marbleBody(56))
                            .foregroundStyle(Color("marblePrimary"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .focused($fieldFocused)
                            .fixedSize()
                        Text(unitLabel)
                            .font(.marbleMono(15))
                            .tracking(1.5)
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                }

                Spacer()

                Button {
                    save()
                } label: {
                    Text("SAVE")
                        .marbleGlassPrimaryCapsule()
                }
                .buttonStyle(.plain)
                .disabled(parsedWeight == nil || (parsedWeight ?? 0) <= 0)
                .opacity((parsedWeight ?? 0) > 0 ? 1 : 0.3)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
            }
            .onAppear { fieldFocused = true }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
        }
    }

    private func save() {
        guard let weight = parsedWeight, weight > 0 else { return }
        let weightInLbs = weightUnit == "kg" ? weight * 2.20462 : weight
        let entry = BodyweightEntry(weight: weightInLbs)
        modelContext.insert(entry)
        try? modelContext.save()
        CloudSyncService.shared.uploadBodyweightEntry(entry)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
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
                            .font(.marbleBody(14))
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
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        toggleTracked(exercise)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.name)
                                                    .font(.marbleBody(14))
                                                    .foregroundStyle(Color("marblePrimary"))
                                                Text(exercise.muscleGroup)
                                                    .font(.marbleMono(11))
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
                        .font(.marbleBody(14))
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
                        .font(.marbleMono(14))
                }
            }
        }
    }

    private func toggleTracked(_ exercise: Exercise) {
        if let existing = trackedLifts.first(where: { $0.exercise?.persistentModelID == exercise.persistentModelID }) {
            let cloudID = existing.cloudID
            modelContext.delete(existing)
            try? modelContext.save()
            CloudSyncService.shared.deleteTrackedLift(cloudID: cloudID)
        } else {
            let lift = TrackedLift(exercise: exercise, metricType: "bestWeight", displayOrder: trackedLifts.count)
            modelContext.insert(lift)
            try? modelContext.save()
            CloudSyncService.shared.uploadTrackedLift(lift)
        }
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
        guard bestWeight > 0 else { return "—" }
        let w = bestWeight == floor(bestWeight) ? "\(Int(bestWeight))" : String(format: "%.1f", bestWeight)
        return "\(w) × \(bestWeightReps)"
    }

    var oneRepMaxFormatted: String {
        guard oneRepMax > 0 else { return "—" }
        let prefix = isManualOneRepMax ? "" : "~"
        return "\(prefix)\(Int(oneRepMax)) lb"
    }

    var maxVolumeFormatted: String {
        guard maxVolume > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: maxVolume)) ?? "0"
        return "\(formatted) lb"
    }

    var autoBestWeight: Double
    var autoBestWeightReps: Int
    var autoOneRepMax: Double
    var autoMaxVolume: Double

    var autoBestWeightFormatted: String {
        guard autoBestWeight > 0 else { return "—" }
        let w = autoBestWeight == floor(autoBestWeight) ? "\(Int(autoBestWeight))" : String(format: "%.1f", autoBestWeight)
        return "\(w) × \(autoBestWeightReps)"
    }

    var autoOneRepMaxFormatted: String {
        guard autoOneRepMax > 0 else { return "—" }
        return "~\(Int(autoOneRepMax)) lb"
    }

    var autoMaxVolumeFormatted: String {
        guard autoMaxVolume > 0 else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: autoMaxVolume)) ?? "0"
        return "\(formatted) lb"
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

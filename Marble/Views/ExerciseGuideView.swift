import SwiftUI
import SwiftData

/// The popup an exercise's "?" button opens. Two tabs:
///   - **About**: demonstration illustration + plain-language numbered
///     instructions, sourced from `ExerciseGuides`.
///   - **History**: a progress bar chart (estimated 1RM per session, to
///     make progressive overload legible at a glance) above a reverse-
///     chronological log of every workout this exercise appeared in.
///
/// Presented as a sheet from `ExerciseLibraryView`. Reads workout history
/// straight from the store via `@Query`.
struct ExerciseGuideView: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"

    @State private var tab: Tab = .about

    private enum Tab: String, CaseIterable { case about = "About", history = "History" }

    private var guide: ExerciseGuide? { ExerciseGuides.guide(for: exercise.name) }

    /// Fixed light surface behind illustrations. Matches the light-mode
    /// `marbleBackground` so it disappears there, but keeps the figures
    /// legible in dark mode (their outlines are dark navy).
    private static let illustrationPlate = Color(red: 0xF4 / 255, green: 0xEE / 255, blue: 0xE4 / 255)

    var body: some View {
        VStack(spacing: 0) {
            header
            segmentedControl
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)

            ScrollView {
                Group {
                    switch tab {
                    case .about:   aboutTab
                    case .history: historyTab
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color("marbleBackground").ignoresSafeArea())
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(exercise.name)
                .font(.marbleBody(18))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 56)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(width: 32, height: 32)
                        .background(Color("marbleFieldBackground"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    // MARK: - Segmented control

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = item }
                } label: {
                    Text(item.rawValue)
                        .font(.marbleMono(13, weight: .medium))
                        .foregroundStyle(tab == item ? Color("marbleBackground") : Color("marbleSecondary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(tab == item ? Color("marblePrimary") : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color("marbleFieldBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - About tab

    @ViewBuilder
    private var aboutTab: some View {
        if let guide {
            VStack(alignment: .leading, spacing: 24) {
                if let imageName = guide.imageName {
                    // Line-art illustration on a fixed bone plate. The plate
                    // colour equals the light-mode background, so in light
                    // mode it's seamless (the figure looks like it sits
                    // straight on the page) but in dark mode it stays a light
                    // surface — without it the navy outlines would vanish
                    // against the near-black background.
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .padding(16)
                        .background(Self.illustrationPlate)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(guide.summary)
                        .font(.marbleBody(15))
                        .foregroundStyle(Color("marbleSecondary"))
                        .fixedSize(horizontal: false, vertical: true)

                    muscleLine(guide)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "INSTRUCTIONS")
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.marbleMono(15))
                                .foregroundStyle(Color("marbleSecondary"))
                                .frame(width: 22, alignment: .leading)
                            Text(step)
                                // Same typeface/size/weight as the summary
                                // line above, for one consistent voice.
                                .font(.marbleBody(15))
                                .foregroundStyle(Color("marblePrimary"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        } else {
            VStack(spacing: 6) {
                MarbleEmptyState(
                    headline: "No guide yet.",
                    subline: "This exercise doesn't have a written walkthrough."
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func muscleLine(_ guide: ExerciseGuide) -> some View {
        HStack(spacing: 8) {
            muscleTag(guide.primaryMuscles, emphasized: true)
            if !guide.secondaryMuscles.isEmpty {
                muscleTag(guide.secondaryMuscles, emphasized: false)
            }
        }
    }

    private func muscleTag(_ text: String, emphasized: Bool) -> some View {
        Text(text.uppercased())
            .font(.marbleMono(10, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(emphasized ? Color("marblePrimary") : Color("marbleSecondary"))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color("marbleFieldBackground"))
            .clipShape(Capsule())
    }

    // MARK: - History tab

    @ViewBuilder
    private var historyTab: some View {
        let sessions = computeSessions()
        if sessions.isEmpty {
            VStack(spacing: 6) {
                MarbleEmptyState(
                    headline: "No history yet.",
                    subline: "Log this lift in a workout and it'll show up here."
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                progressSection(sessions)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "HISTORY")
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    // Newest first for the log.
                    ForEach(Array(sessions.reversed().enumerated()), id: \.offset) { index, session in
                        sessionRow(session)
                        if index < sessions.count - 1 {
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

    /// Progressive-overload headline + per-session bar chart.
    private func progressSection(_ sessions: [Session]) -> some View {
        let first = sessions.first?.bestE1RM ?? 0
        let latest = sessions.last?.bestE1RM ?? 0
        let delta = latest - first

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(formatWeight(latest, withUnit: true))
                        .font(.marbleBody(26))
                        .foregroundStyle(Color("marblePrimary"))
                    Text("EST. 1RM")
                        .font(.marbleMono(9))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                }
                Spacer()
                if sessions.count >= 2 && abs(delta) >= 0.5 {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(formatWeight(abs(delta), withUnit: true))
                            .font(.marbleMono(12, weight: .medium))
                    }
                    .foregroundStyle(delta >= 0 ? Color("marblePrimary") : Color("marbleSecondary"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color("marbleFieldBackground"))
                    .clipShape(Capsule())
                }
            }

            ProgressBarChart(values: sessions.map(\.bestE1RM))
                .frame(height: 96)
        }
        .padding(16)
        .background(Color("marbleFieldBackground").opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sessionRow(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(session.workoutName)
                    .font(.marbleBody(17))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(session.date.marbleRelative())
                    .font(.marbleMono(11))
                    .foregroundStyle(Color("marbleSecondary"))
            }

            // Each distinct set group written out in full, e.g.
            // "3 sets · 185 lb × 8 reps".
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(setGroups(session.sets).enumerated()), id: \.offset) { _, group in
                    Text(setLine(group))
                        .font(.marbleBody(15))
                        .foregroundStyle(Color("marblePrimary"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - History data

    private struct Session {
        let date: Date
        let workoutName: String
        let sets: [(weight: Double, reps: Int)]
        /// Best estimated 1RM across the session's sets (Epley formula).
        var bestE1RM: Double {
            sets.map { $0.weight * (1.0 + Double($0.reps) / 30.0) }.max() ?? 0
        }
    }

    /// One entry per workout this exercise appeared in, oldest first
    /// (so the chart reads left-to-right through time).
    private func computeSessions() -> [Session] {
        var sessions: [Session] = []
        for workout in workouts {
            for log in workout.exerciseLogs {
                guard let ex = log.exercise,
                      ex.persistentModelID == exercise.persistentModelID else { continue }
                let completed = log.sets.filter { $0.isCompleted && $0.weight > 0 }
                guard !completed.isEmpty else { continue }
                sessions.append(Session(
                    date: workout.date,
                    workoutName: workout.name.isEmpty ? "Workout" : workout.name,
                    sets: completed.map { (weight: $0.weight, reps: $0.reps) }
                ))
            }
        }
        // `workouts` is newest-first; reverse to oldest-first.
        return sessions.reversed()
    }

    // MARK: - Formatting

    /// Stored weights are canonical lbs; convert to the user's unit for
    /// display.
    private func displayWeight(_ lbs: Double) -> Double {
        weightUnit == "kg" ? lbs / 2.20462 : lbs
    }

    private func formatWeight(_ lbs: Double, withUnit: Bool) -> String {
        let value = displayWeight(lbs)
        let number = value == floor(value) ? "\(Int(value))" : String(format: "%.1f", value)
        guard withUnit else { return number }
        return "\(number) \(weightUnit == "kg" ? "kg" : "lb")"
    }

    /// Groups identical adjacent sets so "185×8, 185×8, 185×8" collapses
    /// to a single "3 sets" line.
    private func setGroups(_ sets: [(weight: Double, reps: Int)]) -> [(count: Int, weight: Double, reps: Int)] {
        var grouped: [(count: Int, weight: Double, reps: Int)] = []
        for set in sets {
            if let last = grouped.indices.last,
               grouped[last].weight == set.weight, grouped[last].reps == set.reps {
                grouped[last].count += 1
            } else {
                grouped.append((count: 1, weight: set.weight, reps: set.reps))
            }
        }
        return grouped
    }

    /// One set group written out in full, e.g. "3 sets · 185 lb × 8 reps".
    private func setLine(_ group: (count: Int, weight: Double, reps: Int)) -> String {
        let unit = weightUnit == "kg" ? "kg" : "lb"
        let setWord = group.count == 1 ? "set" : "sets"
        let repWord = group.reps == 1 ? "rep" : "reps"
        let weight = formatWeight(group.weight, withUnit: false)
        return "\(group.count) \(setWord) · \(weight) \(unit) × \(group.reps) \(repWord)"
    }
}

// MARK: - Progress bar chart

/// Minimal vertical bar chart — one bar per session, height scaled to the
/// max value. The latest bar is full-strength ink; the rest are muted, so
/// the eye lands on "where you are now" while still reading the trend.
private struct ProgressBarChart: View {
    let values: [Double]

    /// Cap the number of bars so they stay legible on long histories.
    private var shown: [Double] {
        values.count > 24 ? Array(values.suffix(24)) : values
    }

    var body: some View {
        GeometryReader { geo in
            let maxValue = shown.max() ?? 1
            let minValue = shown.min() ?? 0
            // Anchor the floor a little below the smallest value so early
            // bars aren't invisible but progress is still visible.
            let floor = max(0, minValue - (maxValue - minValue) * 0.4)
            let range = max(maxValue - floor, 1)
            let count = max(shown.count, 1)
            let spacing: CGFloat = count > 16 ? 3 : 6
            let barWidth = max(3, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, value in
                    let fraction = (value - floor) / range
                    let height = max(3, geo.size.height * CGFloat(fraction))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color("marblePrimary").opacity(index == shown.count - 1 ? 1 : 0.28))
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}

import SwiftUI
import SwiftData

struct YouView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorSchemeForGradient

    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var allPhotos: [ProgressPhoto]

    @State private var showingSignIn = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Warm radial gradient at the top — same atmospheric treatment
                // as Train tab. Gives the editorial layout some softness.
                Color("marbleBackground")
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [
                        colorSchemeForGradient == .dark
                            ? Color("marbleTertiary").opacity(0.4)
                            : Color.white.opacity(0.5),
                        Color("marbleBackground").opacity(0)
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 700
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        profileHeader
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .padding(.bottom, 24)

                        if workouts.isEmpty {
                            emptyFeed
                        } else {
                            ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
                                    WorkoutEntry(
                                        workout: workout,
                                        photos: photosFor(workout)
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < workouts.count - 1 {
                                    entryDivider
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView()
                    .environmentObject(auth)
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 16) {
            AvatarCircle(name: avatarName, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                if auth.isAuthenticated, let profile = auth.userProfile {
                    Text(profile.name)
                        .font(.marbleBody(22))
                        .foregroundStyle(Color("marblePrimary"))
                    if let joinDate = joinDateString(profile.joinDate) {
                        Text(joinDate)
                            .font(.marbleMono(11))
                            .tracking(1)
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                } else {
                    Button {
                        showingSignIn = true
                    } label: {
                        Text("Sign in")
                            .font(.marbleBody(22))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                    .buttonStyle(.plain)
                    Text("Save your record")
                        .font(.marbleMono(11))
                        .tracking(1)
                        .foregroundStyle(Color("marbleSecondary"))
                }
            }
            Spacer()
        }
    }

    private var avatarName: String {
        auth.userProfile?.name ?? "—"
    }

    private func joinDateString(_ date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "SINCE " + formatter.string(from: date).uppercased()
    }

    // MARK: - Feed

    private var entryDivider: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 24)
    }

    private var emptyFeed: some View {
        VStack {
            Spacer(minLength: 80)
            Text("Begin.")
                .font(.marbleBody(28))
                .foregroundStyle(Color("marbleSecondary"))
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity)
    }

    private func photosFor(_ workout: Workout) -> [ProgressPhoto] {
        allPhotos.filter { $0.workoutCloudID == workout.cloudID }
    }
}

// MARK: - Avatar Circle

struct AvatarCircle: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "—" else { return "" }
        let words = trimmed.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.marbleSurfaceTint)
            if initials.isEmpty {
                Image(systemName: "person")
                    .font(.system(size: size * 0.4, weight: .light))
                    .foregroundStyle(Color("marbleSecondary"))
            } else {
                Text(initials)
                    .font(.marbleBody(size * 0.4))
                    .foregroundStyle(Color("marblePrimary"))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Workout Entry (editorial layout, no card)

/// Editorial workout entry — magazine-style composition instead of a card.
/// Each entry: date, name, Strava-style stats row, handwritten note,
/// typographic composition of exercises + weights, photo (if attached).
/// Hairline dividers between entries (provided by parent).
struct WorkoutEntry: View {
    let workout: Workout
    let photos: [ProgressPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Date masthead
            Text(dateString)
                .font(.marbleMono(11))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            // Workout name
            Text(workout.name)
                .font(.marbleBody(28))
                .foregroundStyle(Color("marblePrimary"))

            // Stats row — Strava-style with bold-ish numbers under quiet labels
            if !statItems.isEmpty {
                HStack(alignment: .top, spacing: 36) {
                    ForEach(statItems, id: \.label) { item in
                        statColumn(label: item.label, value: item.value)
                    }
                    Spacer(minLength: 0)
                }
            }

            // Note in handwritten font — feels like a journal entry
            if let note = workout.notes?.trimmingCharacters(in: .whitespaces),
               !note.isEmpty {
                Text(note)
                    .font(.marbleScript(20))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineSpacing(4)
                    .padding(.top, 4)
            }

            // Typographic composition of exercises + weights
            // The "map equivalent" — the work itself as visual content
            if !workout.exerciseLogs.isEmpty {
                exerciseComposition
                    .padding(.top, 8)
            }

            // Photo (if attached) — full-bleed below the composition
            if let hero = photos.first {
                photoView(hero)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Stats Row

    private struct StatItem { let label: String; let value: String }

    private var statItems: [StatItem] {
        var items: [StatItem] = []
        if totalSets > 0 {
            items.append(StatItem(label: "SETS", value: "\(totalSets)"))
        }
        if Int(workout.duration) / 60 >= 1 {
            items.append(StatItem(label: "TIME", value: formattedDuration))
        }
        if totalVolume > 0 {
            items.append(StatItem(label: "VOLUME", value: formattedVolume))
        }
        return items
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))
            Text(value)
                .font(.marbleBody(20))
                .foregroundStyle(Color("marblePrimary"))
        }
    }

    // MARK: - Exercise Composition

    private var exerciseComposition: some View {
        VStack(spacing: 10) {
            // Top hairline
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.15))
                .frame(width: 32, height: 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(workout.exerciseLogs) { log in
                    exerciseRow(log)
                }
            }

            // Bottom hairline
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.15))
                .frame(width: 32, height: 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func exerciseRow(_ log: ExerciseLog) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(log.exercise?.name ?? "—")
                .font(.marbleScript(19))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(setsString(log.sets))
                .font(.marbleMono(13))
                .tracking(0.5)
                .foregroundStyle(Color("marblePrimary").opacity(0.75))
        }
    }

    /// Compact set summary. "225 × 5, 5, 3" — same-weight reps collapsed,
    /// different weights separated by ' | '. Reads like a scorecard.
    private func setsString(_ sets: [WorkoutSet]) -> String {
        let completed = sets.filter(\.isCompleted)
        guard !completed.isEmpty else { return "—" }

        var groups: [(weight: Double, reps: [Int])] = []
        for set in completed {
            if let lastIdx = groups.indices.last, groups[lastIdx].weight == set.weight {
                groups[lastIdx].reps.append(set.reps)
            } else {
                groups.append((weight: set.weight, reps: [set.reps]))
            }
        }

        return groups.map { group in
            let weightStr = group.weight == floor(group.weight)
                ? "\(Int(group.weight))"
                : String(format: "%.1f", group.weight)
            let repsStr = group.reps.map(String.init).joined(separator: ", ")
            return "\(weightStr) × \(repsStr)"
        }.joined(separator: " | ")
    }

    // MARK: - Photo

    private func photoView(_ photo: ProgressPhoto) -> some View {
        GeometryReader { geo in
            Color.clear
                .frame(width: geo.size.width, height: geo.size.width * 1.25)
                .overlay {
                    if let img = PhotoStorageService.shared.image(for: photo) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color("marbleFieldBackground")
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    if photos.count > 1 {
                        Text("\(photos.count)")
                            .font(.marbleMono(11))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.4), in: Capsule())
                            .padding(12)
                    }
                }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    // MARK: - Computed values

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: workout.date).uppercased()
    }

    private var totalSets: Int {
        workout.exerciseLogs.reduce(0) {
            $0 + $1.sets.filter(\.isCompleted).count
        }
    }

    private var totalVolume: Double {
        workout.exerciseLogs.reduce(0) { sum, log in
            sum + log.sets.filter(\.isCompleted).reduce(0) { setSum, set in
                setSum + (set.weight * Double(set.reps))
            }
        }
    }

    private var formattedVolume: String {
        if totalVolume >= 1000 {
            let k = totalVolume / 1000
            return String(format: "%.1fK lb", k)
        }
        return "\(Int(totalVolume)) lb"
    }

    private var formattedDuration: String {
        let totalMinutes = Int(workout.duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    YouView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

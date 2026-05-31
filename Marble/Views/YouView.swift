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
                            ForEach(workouts) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
                                    WorkoutEntry(
                                        workout: workout,
                                        photos: photosFor(workout)
                                    )
                                }
                                .buttonStyle(.plain)
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

// MARK: - Workout Entry (Strava format, glass card, swipeable carousel)

/// Each workout is a glass card following Strava's structure:
///   date · name · stats · visual · note
///
/// The "visual" is a horizontal swipe carousel:
///   - Slide 1 is always the TYPOGRAPHIC COMPOSITION of the work itself
///     (exercise names + weight × reps in mono, bracketed by hairlines).
///     The Marble equivalent of Strava's map — the work IS the artifact.
///   - Subsequent slides are attached photos.
///
/// Tap card → opens full WorkoutDetailView.
struct WorkoutEntry: View {
    let workout: Workout
    let photos: [ProgressPhoto]

    private let cardCornerRadius: CGFloat = 18
    private let visualHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Date
            Text(dateString)
                .font(.marbleMono(11))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            // Workout name
            Text(workout.name)
                .font(.marbleBody(26))
                .foregroundStyle(Color("marblePrimary"))

            // Stats row — Strava-style
            if !statItems.isEmpty {
                HStack(alignment: .top, spacing: 32) {
                    ForEach(statItems, id: \.label) { item in
                        statColumn(label: item.label, value: item.value)
                    }
                    Spacer(minLength: 0)
                }
            }

            // Horizontal scroll — typographic visual first, then photos.
            // Same height, snap to items. Like Strava's map + photo scroll.
            horizontalVisuals
                .padding(.top, 4)

            // Note (regular body, no italic, no handwritten)
            if let note = workout.notes?.trimmingCharacters(in: .whitespaces),
               !note.isEmpty {
                Text(note)
                    .font(.marbleBody(15))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .stroke(Color("marblePrimary").opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }

    // MARK: - Stats Row (Strava-style)

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

    // MARK: - Horizontal visuals (Strava-style)

    /// Horizontal scroll, same height across all items, snap to view.
    /// Typo visual first at full card width (like Strava's map), then photos
    /// at portrait width slide in from the right. No page dots — natural
    /// horizontal scroll affordance.
    private var horizontalVisuals: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                typoVisual
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width - 40 // account for card's 20pt padding on each side
                    }
                ForEach(photos) { photo in
                    photoTile(photo)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: visualHeight)
    }

    /// The work itself, composed as typography. Larger mono throughout.
    /// Each exercise: small mono caps name + larger mono set line under it.
    /// Hairlines bracket the composition top and bottom.
    private var typoVisual: some View {
        ZStack {
            Color.marbleSurfaceTint

            VStack(spacing: 14) {
                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.22))
                    .frame(width: 24, height: 0.5)

                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    ForEach(workout.exerciseLogs.prefix(5)) { log in
                        exerciseBlock(log)
                    }
                }

                Spacer(minLength: 0)

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.22))
                    .frame(width: 24, height: 0.5)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
        }
        .frame(height: visualHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func exerciseBlock(_ log: ExerciseLog) -> some View {
        VStack(spacing: 3) {
            Text((log.exercise?.name ?? "—").uppercased())
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))
            Text(setsLine(log))
                .font(.marbleMono(16))
                .foregroundStyle(Color("marblePrimary"))
                .lineLimit(1)
        }
    }

    /// Compact set summary on a single line. Same-weight reps collapsed.
    /// "225 × 8, 8, 8" or "225 × 8, 8 | 235 × 3".
    private func setsLine(_ log: ExerciseLog) -> String {
        let completed = log.sets.filter(\.isCompleted)
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
            let w = group.weight == floor(group.weight)
                ? "\(Int(group.weight))"
                : String(format: "%.1f", group.weight)
            return "\(w) × \(group.reps.map(String.init).joined(separator: ", "))"
        }.joined(separator: " | ")
    }

    /// Photo at same height as the typo visual, portrait-aspect width.
    /// Slides into the horizontal scroll alongside the typo visual.
    private func photoTile(_ photo: ProgressPhoto) -> some View {
        let width = visualHeight * 0.8 // 4:5 portrait aspect
        return Group {
            if let img = PhotoStorageService.shared.image(for: photo) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color("marbleFieldBackground")
            }
        }
        .frame(width: width, height: visualHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            return String(format: "%.1fK lb", totalVolume / 1000)
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

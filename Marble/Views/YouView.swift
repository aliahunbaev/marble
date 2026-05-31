import SwiftUI
import SwiftData

struct YouView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var allPhotos: [ProgressPhoto]

    @State private var showingSignIn = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    profileHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 24)

                    if visibleWorkouts.isEmpty {
                        emptyFeed
                    } else {
                        VStack(spacing: 16) {
                            ForEach(visibleWorkouts) { workout in
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
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 40)
            }
            .marbleAtmosphereBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .medium))
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

    /// Only workouts with at least one completed set. Filters out abandoned
    /// or test entries that would otherwise look broken in the feed.
    private var visibleWorkouts: [Workout] {
        workouts.filter { workout in
            workout.exerciseLogs.contains { log in
                log.sets.contains(where: \.isCompleted)
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text composition above (per user pref)
            VStack(alignment: .leading, spacing: 14) {
                Text(dateString)
                    .font(.marbleMono(11))
                    .tracking(1.5)
                    .foregroundStyle(Color("marbleSecondary"))

                Text(workout.name)
                    .font(.marbleBody(26))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineLimit(2)

                // Always 3 columns with placeholders for missing values —
                // consistent visual structure across every entry
                HStack(alignment: .top, spacing: 28) {
                    statColumn(label: "SETS", value: setsValue)
                    statColumn(label: "TIME", value: timeValue)
                    statColumn(label: "VOLUME", value: volumeValue)
                    Spacer(minLength: 0)
                }

                if let note = workout.notes?.trimmingCharacters(in: .whitespaces),
                   !note.isEmpty {
                    Text(note)
                        .font(.marbleBody(15))
                        .foregroundStyle(Color("marblePrimary"))
                        .lineSpacing(3)
                        .padding(.top, 4)
                }
            }
            .padding(20)

            // Photo below (per user pref) — flush with card bottom
            if let hero = photos.first {
                photoHero(hero)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .modifier(LiquidGlassCardModifier(cornerRadius: cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
    }


    // MARK: - Photo Hero (edge-to-edge magazine spread)

    @ViewBuilder
    private func photoHero(_ photo: ProgressPhoto) -> some View {
        GeometryReader { geo in
            Group {
                if let img = PhotoStorageService.shared.image(for: photo) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color("marbleFieldBackground")
                }
            }
            .frame(width: geo.size.width, height: geo.size.width * 1.25)
            .clipped()
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

    // MARK: - Stat value helpers (0 for empty, never dashes)

    private var setsValue: String {
        "\(totalSets)"
    }

    private var timeValue: String {
        if Int(workout.duration) / 60 >= 1 {
            return formattedDuration
        }
        return "0m"
    }

    private var volumeValue: String {
        totalVolume > 0 ? formattedVolume : "0 lb"
    }

    // MARK: - Stats Row (Strava-style, always 3 columns)

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

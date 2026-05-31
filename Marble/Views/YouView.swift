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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                .padding(.top, 2)
            }

            // Carousel — typographic composition first, then photos
            carousel
                .padding(.top, 2)

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

    // MARK: - Carousel (typographic + photos)

    private var carousel: some View {
        TabView {
            typographicSlide
                .tag(-1)
            ForEach(Array(photos.enumerated()), id: \.element.id) { idx, photo in
                photoSlide(photo)
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.isEmpty ? .never : .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// The work itself, composed as typography. This is the "map equivalent."
    /// Centered composition with hairlines bracketing — exercise names in
    /// quiet mono caps, set lines in larger mono. Reads like a museum object
    /// label or printed receipt.
    private var typographicSlide: some View {
        ZStack {
            // Subtle tinted background
            Color.marbleSurfaceTint

            VStack(spacing: 18) {
                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.2))
                    .frame(width: 18, height: 0.5)

                Spacer(minLength: 0)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 18) {
                        ForEach(workout.exerciseLogs) { log in
                            exerciseBlock(log)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                }
                .allowsHitTesting(false) // let the carousel swipe through

                Spacer(minLength: 0)

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.2))
                    .frame(width: 18, height: 0.5)
            }
            .padding(.vertical, 20)
        }
    }

    private func exerciseBlock(_ log: ExerciseLog) -> some View {
        VStack(spacing: 4) {
            Text((log.exercise?.name ?? "—").uppercased())
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            let completed = log.sets.filter(\.isCompleted)
            ForEach(completed) { set in
                Text(setLine(set))
                    .font(.marbleMono(13))
                    .foregroundStyle(Color("marblePrimary"))
            }
        }
    }

    private func setLine(_ set: WorkoutSet) -> String {
        let w = set.weight == floor(set.weight)
            ? "\(Int(set.weight))"
            : String(format: "%.1f", set.weight)
        return "\(w) × \(set.reps)"
    }

    private func photoSlide(_ photo: ProgressPhoto) -> some View {
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

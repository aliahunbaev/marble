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

// MARK: - Workout Entry (poster tile, tap to expand)

/// Each workout is a small tile — like a poster or movie still. Tap to open
/// the full detail view. Two visual variants:
///   - With photo: photo fills the tile, text overlay at bottom with a
///     subtle gradient scrim for readability
///   - Without photo: typographic composition — workout name as the hero
///     on a quiet tinted surface, date + stats around it
/// Both variants share a 4:5 portrait aspect so the feed has consistent
/// rhythm. Note (if attached) appears below the tile as a caption.
struct WorkoutEntry: View {
    let workout: Workout
    let photos: [ProgressPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tile

            if let note = workout.notes?.trimmingCharacters(in: .whitespaces),
               !note.isEmpty {
                Text(note)
                    .font(.marbleBody(15))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }

    // MARK: - Tile

    @ViewBuilder
    private var tile: some View {
        if let hero = photos.first {
            photoTile(hero)
        } else {
            typographicTile
        }
    }

    /// Photo tile — photo is the visual, text overlay at bottom.
    private func photoTile(_ photo: ProgressPhoto) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Photo
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

                // Gradient scrim — transparent → dark, bottom half only
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.width * 1.25)
                .allowsHitTesting(false)

                // Text overlay
                tileText(textColor: .white, dimColor: .white.opacity(0.75))
                    .padding(20)
            }
            .frame(width: geo.size.width, height: geo.size.width * 1.25)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if photos.count > 1 {
                    Text("\(photos.count)")
                        .font(.marbleMono(10))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(12)
                }
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    /// Typographic tile — when no photo, the workout name becomes the visual.
    /// Composed like a museum object label or magazine chapter title.
    private var typographicTile: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Subtle tinted background — gives the tile presence without
                // the chrome of a full card
                Color.marbleSurfaceTint

                // Subtle inner warm radial — adds atmospheric depth so the
                // tile doesn't read as flat
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.25),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.9
                )
                .allowsHitTesting(false)

                // Big workout name — hero of the tile
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    Text(workout.name)
                        .font(.marbleBody(min(geo.size.width * 0.16, 48)))
                        .foregroundStyle(Color("marblePrimary"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Date top-left, stats bottom-left — anchors the composition
                VStack(alignment: .leading) {
                    Text(dateString)
                        .font(.marbleMono(10))
                        .tracking(1.5)
                        .foregroundStyle(Color("marbleSecondary"))
                    Spacer()
                    Rectangle()
                        .fill(Color("marblePrimary").opacity(0.2))
                        .frame(width: 24, height: 0.5)
                        .padding(.bottom, 8)
                    if !statsString.isEmpty {
                        Text(statsString)
                            .font(.marbleMono(10))
                            .tracking(1)
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                }
                .padding(20)
            }
            .frame(width: geo.size.width, height: geo.size.width * 1.25)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("marblePrimary").opacity(0.06), lineWidth: 0.5)
            )
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
    }

    /// Shared text composition for photo tile overlay
    private func tileText(textColor: Color, dimColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateString)
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(dimColor)

            Text(workout.name)
                .font(.marbleBody(26))
                .foregroundStyle(textColor)
                .lineLimit(1)

            if !statsString.isEmpty {
                Text(statsString)
                    .font(.marbleMono(10))
                    .tracking(1)
                    .foregroundStyle(dimColor)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Computed strings

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: workout.date).uppercased()
    }

    private var statsString: String {
        var parts: [String] = []
        if totalSets > 0 {
            parts.append("\(totalSets) SETS")
        }
        if Int(workout.duration) / 60 >= 1 {
            parts.append(formattedDuration)
        }
        if totalVolume > 0 {
            parts.append(formattedVolume)
        }
        return parts.joined(separator: " · ")
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
            return String(format: "%.1fK LB", totalVolume / 1000)
        }
        return "\(Int(totalVolume)) LB"
    }

    private var formattedDuration: String {
        let totalMinutes = Int(workout.duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)H \(minutes)M"
        }
        return "\(minutes)M"
    }
}

#Preview {
    YouView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

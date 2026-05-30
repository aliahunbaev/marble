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
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 28)

                    if workouts.isEmpty {
                        emptyFeed
                    } else {
                        feedDivider
                        ForEach(workouts) { workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                WorkoutFeedCard(
                                    workout: workout,
                                    photos: photosFor(workout)
                                )
                            }
                            .buttonStyle(.plain)
                            feedDivider
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
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

    private var feedDivider: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.06))
            .frame(height: 0.5)
            .padding(.horizontal, 20)
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

/// Editorial avatar — initials in a serif circle on a quiet tinted background.
/// Future: replace with user-uploaded photo when that feature ships.
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

// MARK: - Workout Feed Card

/// Composed card for the You-tab workout feed. Date · name · stats · note ·
/// photos. Tap opens the full WorkoutDetailView. The card is the same
/// artifact that would be shareable later (when share-as-image ships).
struct WorkoutFeedCard: View {
    let workout: Workout
    let photos: [ProgressPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Date
            Text(dateString)
                .font(.marbleMono(11))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))

            // Workout name
            Text(workout.name)
                .font(.marbleBody(22))
                .foregroundStyle(Color("marblePrimary"))

            // Stats
            Text(statsString)
                .font(.marbleMono(11))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))

            // Note (if exists) — italic journal voice
            if let note = workout.notes?.trimmingCharacters(in: .whitespaces),
               !note.isEmpty {
                Text(note)
                    .font(.marbleBody(15).italic())
                    .foregroundStyle(Color("marblePrimary"))
                    .lineSpacing(2)
                    .padding(.top, 2)
            }

            // Photos (if exist) — edge to edge of card width
            if !photos.isEmpty {
                photoStrip
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .contentShape(Rectangle())
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: workout.date).uppercased()
    }

    private var statsString: String {
        var parts: [String] = []
        if workout.duration > 0 {
            parts.append(formattedDuration)
        }
        let totalSets = workout.exerciseLogs.reduce(0) {
            $0 + $1.sets.filter(\.isCompleted).count
        }
        if totalSets > 0 {
            parts.append("\(totalSets) SETS")
        }
        if !workout.exerciseLogs.isEmpty {
            parts.append("\(workout.exerciseLogs.count) EXERCISES")
        }
        return parts.joined(separator: " · ")
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

    @ViewBuilder
    private var photoStrip: some View {
        if photos.count == 1, let photo = photos.first {
            singlePhoto(photo)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(photos) { photo in
                        thumbnail(photo)
                    }
                }
            }
        }
    }

    private func singlePhoto(_ photo: ProgressPhoto) -> some View {
        Color.clear
            .frame(height: 260)
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func thumbnail(_ photo: ProgressPhoto) -> some View {
        Color.clear
            .frame(width: 200, height: 260)
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
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    YouView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

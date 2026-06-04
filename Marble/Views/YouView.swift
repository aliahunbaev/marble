import SwiftUI
import SwiftData
import PhotosUI

struct YouView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var allPhotos: [ProgressPhoto]

    @State private var showingSignIn = false
    @State private var showingSettings = false
    @State private var activeTab: YouTab = .record
    @State private var editingName = false
    @State private var editedName: String = ""
    @FocusState private var nameFieldFocused: Bool

    // Avatar state. `avatarImage` is the rendered photo;
    // `showingAvatarPicker` drives the UIImagePickerController sheet
    // (with allowsEditing → built-in square crop UI).
    @State private var avatarImage: UIImage? = nil
    @State private var showingAvatarPicker = false

    enum YouTab: String, CaseIterable {
        case record = "RECORD"
        case gallery = "GALLERY"

        var iconName: String {
            switch self {
            case .record: return "list.bullet"
            case .gallery: return "square.grid.3x3"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    profileHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    tabSwitcher
                        .padding(.bottom, 24)

                    if activeTab == .record {
                        recordContent
                    } else {
                        GalleryTabContent(photos: allPhotos)
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
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet { image in
                    showingAvatarPicker = false
                    if let image {
                        handleCroppedAvatar(image)
                    }
                }
                .ignoresSafeArea()
            }
            .onAppear { loadAvatarOnAppear() }
        }
    }

    // MARK: - Tab switcher

    /// Full-width two-tab control. Each tab is half the screen wide for
    /// a generous touch target (~44pt tall). Icon + tiny mono label,
    /// with an underline indicator under the active tab. Instagram-ish
    /// shape but with Marble's editorial restraint (mono labels, no
    /// color, just opacity).
    private var tabSwitcher: some View {
        ZStack(alignment: .bottom) {
            // Full-width hairline track that the active underline sits on
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.08))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(YouTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
        }
    }

    private func tabButton(_ tab: YouTab) -> some View {
        let isActive = activeTab == tab
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                activeTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 18, weight: .regular))
                Text(tab.rawValue)
                    .font(.marbleMono(10, weight: .medium))
                    .tracking(1.5)
            }
            .foregroundStyle(
                isActive ? Color("marblePrimary") : Color("marbleSecondary")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? Color("marblePrimary") : Color.clear)
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Record (workout feed) content

    @ViewBuilder
    private var recordContent: some View {
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

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 16) {
            // Tap the avatar → presents the system image picker with
            // `allowsEditing = true`, which surfaces iOS's built-in
            // square crop UI. Whatever the user crops to becomes the
            // avatar — the square result clips cleanly into the
            // circle. Only enabled when signed in.
            Button {
                if auth.isAuthenticated {
                    showingAvatarPicker = true
                }
            } label: {
                AvatarCircle(name: avatarName, size: 64, image: avatarImage)
            }
            .buttonStyle(.plain)
            .disabled(!auth.isAuthenticated)

            VStack(alignment: .leading, spacing: 4) {
                if auth.isAuthenticated, let profile = auth.userProfile {
                    editableName(currentName: profile.name)
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

    /// Inline editable name. Tap the text → flips to a TextField that
    /// commits on submit (return key) or blur. Saves to UserProfile +
    /// pushes the update through AuthenticationService.
    @ViewBuilder
    private func editableName(currentName: String) -> some View {
        if editingName {
            TextField("", text: $editedName)
                .font(.marbleBody(22))
                .foregroundStyle(Color("marblePrimary"))
                .focused($nameFieldFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commitName() }
                .onChange(of: nameFieldFocused) { _, focused in
                    // Blur → commit. Same UX as Apple Contacts.
                    if !focused { commitName() }
                }
        } else {
            Button {
                editedName = currentName
                editingName = true
                DispatchQueue.main.async {
                    nameFieldFocused = true
                }
            } label: {
                Text(currentName)
                    .font(.marbleBody(22))
                    .foregroundStyle(Color("marblePrimary"))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func commitName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        editingName = false
        nameFieldFocused = false
        guard !trimmed.isEmpty,
              trimmed != auth.userProfile?.name else { return }
        Task { await auth.updateName(trimmed) }
    }

    private var avatarName: String {
        auth.userProfile?.name ?? "—"
    }

    /// AvatarPickerSheet returns the user's cropped UIImage directly
    /// (the underlying UIImagePickerController hands back the
    /// .editedImage from its built-in square crop UI). We just
    /// persist + refresh the in-view rendering.
    private func handleCroppedAvatar(_ image: UIImage) {
        let ok = PhotoStorageService.shared.saveAvatar(image)
        if ok {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            avatarImage = PhotoStorageService.shared.avatarImage()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    /// On appear, pull the avatar off disk so signed-in users see their
    /// photo immediately. Also kicks a cloud restore for fresh devices.
    private func loadAvatarOnAppear() {
        avatarImage = PhotoStorageService.shared.avatarImage()
        if auth.isAuthenticated && avatarImage == nil {
            Task {
                await PhotoStorageService.shared.restoreAvatarFromCloud()
                await MainActor.run {
                    avatarImage = PhotoStorageService.shared.avatarImage()
                }
            }
        }
    }

    private func joinDateString(_ date: Date) -> String? {
        "SINCE \(date.marbleMonthYear())"
    }

    // MARK: - Feed

    private var entryDivider: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 24)
    }

    private var emptyFeed: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 60)
            Text("Begin.")
                .font(.marbleBody(28))
                .foregroundStyle(Color("marbleSecondary"))
            Text("Your finished workouts collect here — date, lifts, notes, a photo if you took one.")
                .font(.marbleMono(11))
                .tracking(1)
                .foregroundStyle(Color("marbleTertiary"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)
            Spacer(minLength: 60)
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
    /// Optional override image. When non-nil, renders as the avatar;
    /// when nil, falls back to initials (or a person icon when name
    /// is empty). Lets profile-aware screens pass the loaded user
    /// avatar without changing AvatarCircle callers elsewhere.
    var image: UIImage? = nil

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
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if initials.isEmpty {
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

    /// Em-dash for empty/missing values rather than zeroes — "0 lb" reads
    /// like data, "—" reads like absence. Consistent with editorial type
    /// conventions: a missing field is shown explicitly, not faked.
    private var setsValue: String {
        totalSets > 0 ? "\(totalSets)" : "—"
    }

    private var timeValue: String {
        Int(workout.duration) / 60 >= 1 ? formattedDuration : "—"
    }

    private var volumeValue: String {
        totalVolume > 0 ? formattedVolume : "—"
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
        workout.date.marbleFullDate()
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

// MARK: - Avatar picker (UIImagePickerController with built-in crop)

/// Wraps `UIImagePickerController` with `allowsEditing = true`, which
/// surfaces iOS's built-in square crop UI. The cropped result comes
/// back via `.editedImage`. Used for the profile avatar so users can
/// frame their face inside the circle instead of being stuck with
/// whatever the photo's original framing was.
///
/// `UIImagePickerController` is the simplest path to a free, native
/// crop interaction — PHPickerViewController (the modern picker) has
/// no built-in cropping, so for this specific use case the older API
/// is the pragmatic choice.
struct AvatarPickerSheet: UIViewControllerRepresentable {
    let onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AvatarPickerSheet

        init(_ parent: AvatarPickerSheet) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Prefer the cropped result; fall back to the original
            // if for some reason editing wasn't completed.
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.onPicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onPicked(nil)
        }
    }
}

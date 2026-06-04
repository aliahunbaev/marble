import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ClosingRitualView: View {
    let workout: Workout
    /// Optional escape hatch — back to the active workout. When provided,
    /// renders a chevron in the top-left of the ritualView. The caller
    /// is responsible for undoing the just-saved workout and resuming
    /// the timer state. Not called from the recordedView (that flow is
    /// already irreversibly "done").
    var onBack: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String = ""
    /// In-place editable workout title. Seeded from `workout.name` on
    /// appear, committed back on save (or earlier on commit if the
    /// user explicitly submits).
    @State private var workoutNameDraft: String = ""
    /// Captured photos, in display order. Each entry is the rendered
    /// UIImage + the persisted ProgressPhoto record. Tracking as a
    /// paired array means we can remove individual photos by index
    /// without losing the photo↔record mapping.
    @State private var capturedItems: [CapturedPhotoItem] = []
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var showingAddPhotoChoice = false
    @State private var isRecorded: Bool = false
    @FocusState private var noteFocused: Bool
    @FocusState private var titleFocused: Bool

    var body: some View {
        Group {
            if isRecorded {
                recordedView
            } else {
                ritualView
            }
        }
        .marbleAtmosphereBackground()
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                if let image { handleImage(image) }
                showingCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handleImage(image)
                }
                libraryItem = nil
            }
        }
        .confirmationDialog("Add a photo", isPresented: $showingAddPhotoChoice, titleVisibility: .hidden) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingLibrary = true }
            Button("Cancel", role: .cancel) { }
        }
        .onTapGesture {
            noteFocused = false
            titleFocused = false
        }
        .onAppear {
            // Seed the editable title from the workout's current name
            // exactly once, so an in-flight edit isn't blown away on
            // re-render. Default to "Workout" if the workout's name
            // is missing or blank.
            if workoutNameDraft.isEmpty {
                let current = workout.name.trimmingCharacters(in: .whitespaces)
                workoutNameDraft = current.isEmpty ? "Workout" : current
            }
        }
    }

    // MARK: - Ritual (photo + note)

    private var ritualView: some View {
        ZStack(alignment: .top) {
            // Main scrollable canvas — fills the full screen so SAVE
            // can float over it. Long notes scroll behind the glass
            // SAVE button; the iOS 26 glass effect handles the visual
            // transition automatically (no need for an explicit fade).
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    titleHeader

                    photoZone

                    noteZone
                        .padding(.horizontal, 20)
                }
                // Safe zone below the floating SAVE button (52pt button
                // + 32pt bottom + breathing room).
                .padding(.bottom, 140)
                .padding(.top, 64)
            }

            // Back chevron — escape hatch to the active workout.
            if let onBack {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .medium))
                            .marbleGlassCapsule(size: 44)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 8)
            }

            // Floating SAVE — sits at the bottom, full-width within
            // 20pt horizontal insets. Inline-styled so the label
            // actually stretches to fill width (the marbleGlassPill
            // helper sizes to its content and the outer .frame
            // wouldn't propagate through the modifier chain).
            VStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    save(skipping: false)
                } label: {
                    Text("SAVE")
                        .font(.marbleMono(13, weight: .regular))
                        .tracking(1)
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .modifier(InlineGlassPillBackground())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    /// Header for the closing ritual — inline-editable workout title
    /// over a quiet date + duration line. Tap the title to rename;
    /// the new name lands on `workout.name` when SAVE is hit (or
    /// earlier if the user explicitly submits / blurs the field).
    private var titleHeader: some View {
        VStack(spacing: 8) {
            TextField("Workout", text: $workoutNameDraft)
                .font(.marbleBody(22))
                .foregroundStyle(Color("marblePrimary"))
                .multilineTextAlignment(.center)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { titleFocused = false }

            HStack(spacing: 8) {
                Text(formattedDate)
                    .font(.marbleMono(11))
                    .tracking(1.5)
                    .foregroundStyle(Color("marbleSecondary"))
                Text("·")
                    .font(.marbleMono(11))
                    .foregroundStyle(Color("marbleTertiary"))
                Text(formattedDuration)
                    .font(.marbleMono(11))
                    .tracking(1.5)
                    .foregroundStyle(Color("marbleSecondary"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Recorded (final closing screen)

    @State private var recordedOpacity: Double = 0

    private var recordedView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("MARBLE")
                    .font(.marbleBody(16))
                    .tracking(6)
                    .foregroundStyle(Color("marblePrimary"))

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.2))
                    .frame(width: 24, height: 0.5)

                Text("Recorded.")
                    .font(.marbleBody(32))
                    .foregroundStyle(Color("marblePrimary"))

                Text(formattedDate)
                    .font(.marbleMono(11))
                    .tracking(2)
                    .foregroundStyle(Color("marbleSecondary"))
            }
            .opacity(recordedOpacity)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Text("DONE")
                    .marbleSecondaryButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .opacity(recordedOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                recordedOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: - Photo Zone

    /// Empty: two big capture options (PHOTO / LIBRARY).
    /// Otherwise: horizontal strip of captured photos + an "add more"
    /// tile that re-opens the camera/library choice via a confirmation
    /// dialog. Users can keep adding photos one by one.
    @ViewBuilder
    private var photoZone: some View {
        if capturedItems.isEmpty {
            HStack(spacing: 10) {
                captureOption(icon: "camera", label: "PHOTO") {
                    showingCamera = true
                }
                captureOption(icon: "photo.on.rectangle", label: "LIBRARY") {
                    showingLibrary = true
                }
            }
            .padding(.horizontal, 20)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(capturedItems.enumerated()), id: \.element.id) { index, item in
                        capturedThumb(item: item, index: index)
                    }
                    addMoreTile
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func captureOption(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .ultraLight))
                Text(label)
                    .font(.marbleMono(10))
                    .tracking(1.5)
            }
            .foregroundStyle(Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// 4:5 portrait thumb of a captured photo with a small X to remove.
    private func capturedThumb(item: CapturedPhotoItem, index: Int) -> some View {
        let thumbWidth: CGFloat = 140
        let thumbHeight: CGFloat = thumbWidth * 5 / 4
        return Image(uiImage: item.image)
            .resizable()
            .scaledToFill()
            .frame(width: thumbWidth, height: thumbHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    removePhoto(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(8)
            }
    }

    /// "+" tile at the end of the captured strip. Opens the
    /// Camera/Library confirmation dialog so users can keep adding.
    private var addMoreTile: some View {
        let thumbWidth: CGFloat = 140
        let thumbHeight: CGFloat = thumbWidth * 5 / 4
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingAddPhotoChoice = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color("marbleSecondary"))
                .frame(width: thumbWidth, height: thumbHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Zone

    /// Editorial note pad. Subtle marble-tinted card surface so the
    /// writing area reads as an intentional surface to write on,
    /// rather than text floating on the page. Larger placeholder,
    /// more breathing room than the previous bare-TextEditor +
    /// hairline pattern.
    private var noteZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTE")
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty {
                    Text("A line about today.")
                        .font(.marbleBody(17))
                        .foregroundStyle(Color("marblePrimary").opacity(0.3))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteText)
                    .font(.marbleBody(17))
                    .foregroundStyle(Color("marblePrimary"))
                    .focused($noteFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color("marblePrimary").opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Photo handling

    private func handleImage(_ image: UIImage) {
        // Persist via the photo storage service (writes local + queues
        // the cloud upload). Then append the rendered + record pair to
        // the in-view strip so the user sees their addition immediately.
        guard let photo = PhotoStorageService.shared.savePhoto(
            image,
            workoutCloudID: workout.cloudID,
            context: modelContext
        ) else { return }
        capturedItems.append(CapturedPhotoItem(image: image, photo: photo))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func removePhoto(at index: Int) {
        guard capturedItems.indices.contains(index) else { return }
        let item = capturedItems.remove(at: index)
        PhotoStorageService.shared.delete(item.photo, context: modelContext)
    }

    // MARK: - Save

    private func save(skipping: Bool) {
        let trimmedNote = noteText.trimmingCharacters(in: .whitespaces)
        let trimmedName = workoutNameDraft.trimmingCharacters(in: .whitespaces)

        // Note: only commit when not skipping (Skip button is gone but
        // the parameter is preserved in case it returns).
        if !skipping || !trimmedNote.isEmpty {
            workout.notes = trimmedNote.isEmpty ? nil : trimmedNote
        }
        // Title: always commit if the user actually typed something
        // different from the current name. Empty draft falls back to
        // the existing workout name (don't clobber with blank).
        if !trimmedName.isEmpty, trimmedName != workout.name {
            workout.name = trimmedName
        }
        try? modelContext.save()
        CloudSyncService.shared.uploadWorkout(workout)

        noteFocused = false
        titleFocused = false
        withAnimation(.easeInOut(duration: 0.5)) {
            isRecorded = true
        }
    }

    private var formattedDate: String {
        workout.date.marbleFullDate()
    }

    // MARK: - Helpers

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

// MARK: - Inline glass pill background

/// Reusable glass-pill background that respects `frame(maxWidth:)`
/// — unlike the `marbleGlassPill` helper, which sizes to its content
/// and doesn't propagate the stretch through the modifier chain when
/// the caller wants a full-width button. Applied here to the SAVE
/// button so it stretches edge-to-edge of its parent insets instead
/// of shrinking to "SAVE" text width.
private struct InlineGlassPillBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Captured photo wrapper

/// Pairs the rendered UIImage with the persisted ProgressPhoto so we
/// can remove individual photos by index while still being able to
/// delete the underlying record correctly.
private struct CapturedPhotoItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let photo: ProgressPhoto
}

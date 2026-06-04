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
    /// The "pump pic" — the camera-taken photo that *is* the closing
    /// ritual's artifact. Zero or one. Distinct from library imports
    /// because it's the ritualistic creation moment: you took it now,
    /// in the room, after the work. Lives in its own hero slot above
    /// the supplementary library carousel.
    @State private var pumpPicItem: CapturedPhotoItem?
    /// Supplementary photos imported from the library. Zero or many.
    /// Context / commentary — not the ritual artifact.
    @State private var libraryPhotos: [CapturedPhotoItem] = []
    @State private var showingCamera = false
    @State private var showingLibrary = false
    /// PhotosPicker accepts multi-select when bound to a `[PhotosPickerItem]`
    /// with a maxSelectionCount > 1. We keep it as an array and process
    /// each picked item into the library strip on .onChange.
    @State private var libraryPickerSelection: [PhotosPickerItem] = []
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
                if let image { handleCameraImage(image) }
                showingCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showingLibrary,
            selection: $libraryPickerSelection,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: libraryPickerSelection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handleLibraryImage(image)
                    }
                }
                libraryPickerSelection = []
            }
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

                    pumpPicHero

                    libraryCarousel

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
                .padding(.bottom, 16)
            }
        }
    }

    /// Inline-editable workout title at 32pt body — same scale and
    /// alignment as the title in ActiveWorkout / TemplateEditor so
    /// the three "what is this workout / template" surfaces feel
    /// like the same canvas. Date + duration intentionally dropped:
    /// the date is implicit (just-finished workouts are always today)
    /// and the duration is non-essential at the closing moment —
    /// both live on the workout detail view for later reference.
    private var titleHeader: some View {
        TextField("Workout", text: $workoutNameDraft)
            .font(.marbleBody(32))
            .foregroundStyle(Color("marblePrimary"))
            .focused($titleFocused)
            .submitLabel(.done)
            .onSubmit { titleFocused = false }
            .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Hero pump pic slot height. Larger than the library strip so
    /// the moment carries visual weight.
    private static let pumpPicHeight: CGFloat = 280
    /// Library strip height — smaller, supplementary.
    private static let libraryStripHeight: CGFloat = 140

    // MARK: - Pump pic hero

    /// Full-width hero slot for the camera photo. Empty state =
    /// inviting "TAKE A PUMP PIC" call to action. Filled state =
    /// the photo itself with a small X to retake. Distinct from the
    /// library strip below because the pump pic *is* the closing
    /// ritual's artifact — the moment you created in the room.
    @ViewBuilder
    private var pumpPicHero: some View {
        if let item = pumpPicItem {
            pumpPicFilled(item: item)
                .padding(.horizontal, 20)
        } else {
            pumpPicEmpty
                .padding(.horizontal, 20)
        }
    }

    private var pumpPicEmpty: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingCamera = true
        } label: {
            VStack(spacing: 14) {
                Image(systemName: "camera")
                    .font(.system(size: 28, weight: .ultraLight))
                Text("TAKE A PUMP PIC")
                    .font(.marbleMono(11, weight: .medium))
                    .tracking(2)
                Text("Mark the lift.")
                    .font(.marbleBody(13))
                    .foregroundStyle(Color("marbleTertiary"))
            }
            .foregroundStyle(Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .frame(height: Self.pumpPicHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color("marblePrimary").opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func pumpPicFilled(item: CapturedPhotoItem) -> some View {
        Image(uiImage: item.image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: Self.pumpPicHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    removePumpPic()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(10)
            }
    }

    // MARK: - Library carousel

    /// Horizontal scroll of library photos + "+" tile. Always
    /// rendered — even when empty, the small mono "LIBRARY" label
    /// + a single "+" tile invites supplementary photos. Library
    /// photos preserve their natural aspect ratio at a fixed
    /// 140pt height (smaller than the pump pic hero — they're
    /// supplementary, not the ritual artifact).
    private var libraryCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LIBRARY")
                .font(.marbleMono(10))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(libraryPhotos.enumerated()), id: \.element.id) { index, item in
                        libraryThumb(item: item, index: index)
                    }
                    libraryAddTile
                }
                .padding(.horizontal, 20)
            }
            .frame(height: Self.libraryStripHeight)
        }
    }

    private func libraryThumb(item: CapturedPhotoItem, index: Int) -> some View {
        let height = Self.libraryStripHeight
        let aspect: CGFloat = {
            let w = item.image.size.width
            let h = item.image.size.height
            guard w > 0, h > 0 else { return 4.0 / 5.0 }
            return w / h
        }()
        let width = height * aspect

        return Image(uiImage: item.image)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .topTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    removeLibraryPhoto(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(6)
            }
    }

    private var libraryAddTile: some View {
        let height = Self.libraryStripHeight
        let width = height * 4 / 5
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingLibrary = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color("marbleSecondary"))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
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

    /// Camera-captured photo lands in the hero slot (the pump pic).
    /// If one's already there, the new one replaces it — the slot is
    /// singular by design. The replaced photo is deleted from storage
    /// so we don't leak orphan records.
    private func handleCameraImage(_ image: UIImage) {
        if let existing = pumpPicItem {
            PhotoStorageService.shared.delete(existing.photo, context: modelContext)
        }
        guard let photo = PhotoStorageService.shared.savePhoto(
            image,
            workoutCloudID: workout.cloudID,
            context: modelContext
        ) else { return }
        pumpPicItem = CapturedPhotoItem(image: image, photo: photo)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Library-imported photo joins the library carousel. Many allowed.
    private func handleLibraryImage(_ image: UIImage) {
        guard let photo = PhotoStorageService.shared.savePhoto(
            image,
            workoutCloudID: workout.cloudID,
            context: modelContext
        ) else { return }
        libraryPhotos.append(CapturedPhotoItem(image: image, photo: photo))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func removePumpPic() {
        guard let item = pumpPicItem else { return }
        PhotoStorageService.shared.delete(item.photo, context: modelContext)
        pumpPicItem = nil
    }

    private func removeLibraryPhoto(at index: Int) {
        guard libraryPhotos.indices.contains(index) else { return }
        let item = libraryPhotos.remove(at: index)
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

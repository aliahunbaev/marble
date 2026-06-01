import SwiftUI
import SwiftData

struct GallerySection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @Query private var workouts: [Workout]

    @State private var showingCapture = false
    @State private var selectedPhoto: ProgressPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "GALLERY")
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingCapture = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .light))
                        Text("CAPTURE")
                            .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                            .tracking(1)
                    }
                    .foregroundStyle(Color("marbleSecondary"))
                }
            }

            if photos.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(photos) { photo in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedPhoto = photo
                        } label: {
                            PhotoThumbnail(photo: photo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCapture) {
            PhotoCaptureSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoViewerView(
                photo: photo,
                workout: workoutFor(photo: photo),
                onDelete: { delete(photo) }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Mark the work.")
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 18).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
            Text("Capture a moment after each session. A quiet record of what you make.")
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 13).weight(.light))
                .foregroundStyle(Color("marbleSecondary"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
        )
    }

    private func workoutFor(photo: ProgressPhoto) -> Workout? {
        guard let id = photo.workoutCloudID else { return nil }
        return workouts.first { $0.cloudID == id }
    }

    private func delete(_ photo: ProgressPhoto) {
        PhotoStorageService.shared.delete(photo, context: modelContext)
        selectedPhoto = nil
    }
}

// MARK: - Thumbnail

struct PhotoThumbnail: View {
    let photo: ProgressPhoto
    /// width/height — defaults to 1.0 (square). Pass 4.0/5.0 for portrait
    /// gallery thumbs that match the natural progress-photo aspect ratio.
    var aspectRatio: CGFloat = 1.0
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color("marbleFieldBackground")
                }
            }
            .frame(width: geo.size.width, height: geo.size.width / aspectRatio)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if photo.uploadPending {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(6)
                        .shadow(radius: 1)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .task {
            image = PhotoStorageService.shared.image(for: photo)
        }
    }
}

// MARK: - Full-screen Viewer

struct PhotoViewerView: View {
    let photo: ProgressPhoto
    let workout: Workout?
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?
    @State private var showingDeleteConfirmation = false
    @State private var dragOffset: CGFloat = 0
    @State private var chromeVisible: Bool = true

    private var neutralBackground: Color {
        colorScheme == .dark ? .black : Color("marbleBackground")
    }

    var body: some View {
        ZStack {
            neutralBackground.ignoresSafeArea()

            // Photo (always present, natural aspect)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: dragOffset)
            } else {
                ProgressView()
                    .tint(Color("marbleSecondary"))
            }

            // Chrome layer
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                    }
                    .marbleGlassCapsule(size: 44)

                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .light))
                    }
                    .marbleGlassCapsule(size: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 6) {
                    PhotoDateChip(date: photo.date)

                    if let workout {
                        Text(workout.name.uppercased())
                            .font(.marbleMono(10))
                            .tracking(1.5)
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                }
                .padding(.bottom, 32)
            }
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                chromeVisible.toggle()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .task {
            image = PhotoStorageService.shared.image(for: photo)
        }
        .alert("Delete photo?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

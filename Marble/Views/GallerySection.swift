import SwiftUI
import SwiftData

// MARK: - Thumbnail
//
// Two-component file: PhotoThumbnail (used by GalleryTab's grid) +
// PhotoViewerView (used by WorkoutDetailView for in-context photo
// review). The outer GallerySection view that originally lived here
// was orphaned after the YOU tab moved to RECORD/GALLERY subtabs.
// Removed in the post-launch cleanup pass.

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

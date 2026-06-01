import SwiftUI
import SwiftData

/// The GALLERY tab content on YOU — chronological grid of progress photos
/// with a Compare entry pill that lets the user pick two photos for a
/// side-by-side viewer. Independent of the workout feed (which lives in
/// the RECORD tab); this surface treats photos as the artifact, not as
/// context-for-workouts.
struct GalleryTabContent: View {
    let photos: [ProgressPhoto]

    @State private var browsingFromIndex: Int?
    @State private var comparisonPair: ComparisonStart?
    @State private var isCompareMode = false
    @State private var firstPickIndex: Int?

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if photos.isEmpty {
                emptyState
            } else {
                headerBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        photoCell(photo: photo, index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .fullScreenCover(item: $browsingFromIndex.toFullScreenCoverItem) { wrapper in
            MultiPhotoBrowserView(
                photos: photos,
                initialIndex: wrapper.value
            )
        }
        .fullScreenCover(item: $comparisonPair) { pair in
            PhotoComparisonView(
                photos: photos,
                initialTopIndex: pair.first,
                initialBottomIndex: pair.second
            )
        }
    }

    // MARK: - Header / Compare entry

    /// Small bar above the grid. Shows label + Compare pill, or compare-mode
    /// instructional text + Cancel when in compare mode.
    private var headerBar: some View {
        HStack {
            Text(isCompareMode ? "PICK TWO TO COMPARE" : "\(photos.count) PHOTOS")
                .font(.marbleMono(11))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompareMode.toggle()
                    firstPickIndex = nil
                }
            } label: {
                Text(isCompareMode ? "CANCEL" : "COMPARE")
                    .font(.marbleMono(11, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color("marblePrimary"))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Cells

    @ViewBuilder
    private func photoCell(photo: ProgressPhoto, index: Int) -> some View {
        let isFirstPick = (firstPickIndex == index)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            handleTap(index: index)
        } label: {
            PhotoThumbnail(photo: photo)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isFirstPick ? Color("marblePrimary") : Color.clear,
                            lineWidth: 2
                        )
                )
                .opacity(isCompareMode && !isFirstPick ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func handleTap(index: Int) {
        if isCompareMode {
            if let first = firstPickIndex {
                if first == index {
                    // Tap same photo again → deselect
                    firstPickIndex = nil
                } else {
                    // Second photo picked → open comparison
                    comparisonPair = ComparisonStart(first: first, second: index)
                    firstPickIndex = nil
                    isCompareMode = false
                }
            } else {
                firstPickIndex = index
            }
        } else {
            browsingFromIndex = index
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No photos yet.")
                .font(.marbleBody(15))
                .foregroundStyle(Color("marbleSecondary"))
            Text("Capture one after a workout.")
                .font(.marbleMono(11))
                .tracking(1)
                .foregroundStyle(Color("marbleTertiary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Comparison start tuple

/// Lightweight Identifiable wrapper so fullScreenCover(item:) can be
/// driven by a tuple of indices. The pair itself is the identity — re-
/// entering compare with the same two photos counts as a "new" sheet.
struct ComparisonStart: Identifiable, Equatable {
    let first: Int
    let second: Int
    var id: String { "\(first)-\(second)" }
}

// MARK: - Optional Int helper for fullScreenCover(item:)

private struct IndexWrapper: Identifiable {
    let value: Int
    var id: Int { value }
}

private extension Binding where Value == Int? {
    /// Convenience to expose an `Int?` as a `Binding<IndexWrapper?>` so
    /// fullScreenCover(item:) can drive a single-photo browser.
    var toFullScreenCoverItem: Binding<IndexWrapper?> {
        Binding<IndexWrapper?>(
            get: { wrappedValue.map(IndexWrapper.init) },
            set: { newValue in wrappedValue = newValue?.value }
        )
    }
}

// MARK: - Multi-photo browser

/// Full-screen photo browser that supports horizontal swipe between
/// photos. Uses TabView(.page) which gives native iOS swipe + page
/// indicator behavior for free.
struct MultiPhotoBrowserView: View {
    let photos: [ProgressPhoto]
    let initialIndex: Int

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    BrowserPhotoView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)

            // Top bar — close
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                // Bottom: date stamp
                if photos.indices.contains(currentIndex) {
                    Text(photos[currentIndex].date.marbleRelative())
                        .font(.marbleMono(12))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 32)
                }
            }
        }
        .onAppear { currentIndex = initialIndex }
        // Drag down to dismiss — same gesture as PhotoViewerView so the
        // dismissal pattern is consistent across photo viewers.
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0
                        && abs(value.translation.width) < abs(value.translation.height) {
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
    }
}

/// One photo at full-screen-ish size with the standard scaledToFit
/// treatment. Extracted so MultiPhotoBrowserView and the comparison
/// halves can share the same image-loading affordances.
struct BrowserPhotoView: View {
    let photo: ProgressPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            image = PhotoStorageService.shared.image(for: photo)
        }
    }
}

// MARK: - Side-by-side comparison

/// Two photos stacked vertically, each with its own horizontal swipe.
/// Swiping the top half changes the top photo without affecting the
/// bottom, and vice versa — the user finds "before" on one half and
/// "after" on the other by scrubbing independently.
struct PhotoComparisonView: View {
    let photos: [ProgressPhoto]
    let initialTopIndex: Int
    let initialBottomIndex: Int

    @State private var topIndex: Int = 0
    @State private var bottomIndex: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                comparisonHalf(index: $topIndex)

                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)

                comparisonHalf(index: $bottomIndex)
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4), in: Circle())
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .onAppear {
            topIndex = initialTopIndex
            bottomIndex = initialBottomIndex
        }
    }

    @ViewBuilder
    private func comparisonHalf(index: Binding<Int>) -> some View {
        ZStack(alignment: .bottom) {
            TabView(selection: index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { i, photo in
                    BrowserPhotoView(photo: photo)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Date label for the currently-shown photo on this half
            if photos.indices.contains(index.wrappedValue) {
                Text(photos[index.wrappedValue].date.marbleRelative())
                    .font(.marbleMono(11))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

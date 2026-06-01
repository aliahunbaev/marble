import SwiftUI
import SwiftData

/// The GALLERY tab content on YOU — 2-column grid of portrait progress
/// photos. Tap any photo → opens the browser. Inside the browser, a
/// "Compare" pill returns to the grid in pick-second mode, where the
/// next tap opens the side-by-side comparison view. Decoupled from
/// the workout feed; photos here are the artifact, not workout context.
struct GalleryTabContent: View {
    let photos: [ProgressPhoto]

    @State private var browsingFromIndex: Int?
    @State private var comparisonPair: ComparisonStart?
    /// When non-nil, the user is picking the second photo for a
    /// comparison. The Int is the index of the first-picked photo.
    @State private var pickingSecondFor: Int?

    /// Namespace for the iOS 18+ zoom transition. The thumbnail in the
    /// grid is the source; the photo at `initialIndex` inside the browser
    /// is the destination — SwiftUI animates the expand-from-cell.
    @Namespace private var photoZoom

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if photos.isEmpty {
                emptyState
            } else {
                if let firstIndex = pickingSecondFor,
                   photos.indices.contains(firstIndex) {
                    pickSecondBanner(firstIndex: firstIndex)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                LazyVGrid(columns: columns, spacing: 6) {
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
                initialIndex: wrapper.value,
                onCompareRequested: { index in
                    // Browser dismissed itself via dismiss(); we pick up the
                    // first-comparison index and enter pick-second mode on
                    // the next runloop tick so the cover transition finishes.
                    DispatchQueue.main.async {
                        pickingSecondFor = index
                    }
                }
            )
            .modifier(ZoomNavigationModifier(
                sourceID: photos[wrapper.value].id,
                namespace: photoZoom
            ))
        }
        .fullScreenCover(item: $comparisonPair) { pair in
            PhotoComparisonView(
                photos: photos,
                initialTopIndex: pair.first,
                initialBottomIndex: pair.second
            )
        }
    }

    // MARK: - Pick-second banner

    /// Shown above the grid when the user has hit "Compare" from inside
    /// the photo browser. Reminds them which photo they picked first and
    /// gives a Cancel affordance.
    private func pickSecondBanner(firstIndex: Int) -> some View {
        let firstPhoto = photos[firstIndex]
        return HStack(spacing: 12) {
            PhotoThumbnail(photo: firstPhoto, aspectRatio: 4.0 / 5.0)
                .frame(width: 36, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text("Comparing with \(firstPhoto.date.marbleRelative())")
                .font(.marbleBody(14))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    pickingSecondFor = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color("marbleCard"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Cells

    @ViewBuilder
    private func photoCell(photo: ProgressPhoto, index: Int) -> some View {
        let isFirstPick = (pickingSecondFor == index)
        let isPicking = (pickingSecondFor != nil)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            handleTap(index: index)
        } label: {
            PhotoThumbnail(photo: photo, aspectRatio: 4.0 / 5.0)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isFirstPick ? Color("marblePrimary") : Color.clear,
                            lineWidth: 2
                        )
                )
                // Dim non-pickable cells when in pick-second mode so the
                // "I'm picking a second photo" state reads clearly.
                .opacity(isPicking && !isFirstPick ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .modifier(ZoomSourceModifier(id: photo.id, namespace: photoZoom))
    }

    private func handleTap(index: Int) {
        if let first = pickingSecondFor {
            if first == index {
                // Tapped first-pick again → deselect
                withAnimation(.easeInOut(duration: 0.2)) {
                    pickingSecondFor = nil
                }
            } else {
                // Second pick → open comparison
                comparisonPair = ComparisonStart(first: first, second: index)
                pickingSecondFor = nil
            }
        } else {
            // Normal tap → browser
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

// MARK: - Date chip (chrome)

/// Small glass-pill date label for photo viewers. Sized smaller than the
/// standard marbleGlassPill (which is for tappable controls) — this is a
/// label, not a button, so it sits at 24pt height with tighter padding.
/// Uses the same glass language so it reads as part of the chrome layer.
struct PhotoDateChip: View {
    let date: Date

    var body: some View {
        Text(date.marbleRelative())
            .font(.marbleMono(10))
            .tracking(1)
            .foregroundStyle(Color("marblePrimary"))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .modifier(GlassChipBackground())
    }
}

/// Background-only glass treatment for the date chip. Same iOS 26
/// availability gating as MarbleGlassCapsule but in a capsule shape
/// and without the chrome-button frame.
private struct GlassChipBackground: ViewModifier {
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

// MARK: - iOS 18+ zoom transition modifiers

/// Wraps the iOS 18 `matchedTransitionSource` API behind an availability
/// check. On iOS < 18 the modifier is a no-op — the photo opens with the
/// default fullScreenCover slide-up animation instead of the zoom.
private struct ZoomSourceModifier: ViewModifier {
    let id: PersistentIdentifier
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

/// Wraps the iOS 18 `.navigationTransition(.zoom(...))` modifier behind
/// an availability check. Same fallback semantics as the source modifier.
private struct ZoomNavigationModifier: ViewModifier {
    let sourceID: PersistentIdentifier
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
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
/// photos. Uses TabView(.page) for native iOS swipe behavior.
///
/// Compare entry lives here, not on the grid. Tapping the Compare pill
/// dismisses the browser and tells the caller which index to pick second
/// against — the user lands back on the grid in pick-second mode.
struct MultiPhotoBrowserView: View {
    let photos: [ProgressPhoto]
    let initialIndex: Int
    /// Called with the currently-shown photo's index when the user taps
    /// the Compare pill. The browser dismisses itself; the caller then
    /// enters its own pick-second flow.
    var onCompareRequested: ((Int) -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    /// Chrome (top bar + date stamp) shows by default and toggles off on
    /// tap. Apple-Photos-ish pattern — gives the user an uninterrupted
    /// view of the image when they want it.
    @State private var chromeVisible: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Pure neutral so the photo is the loudest thing on screen. Black
    /// in dark mode, marble bone in light mode — no atmosphere gradient.
    private var neutralBackground: Color {
        colorScheme == .dark ? .black : Color("marbleBackground")
    }

    var body: some View {
        ZStack {
            neutralBackground.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    BrowserPhotoView(photo: photo)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dragOffset)
            // Tap toggles chrome. .contentShape ensures the tap area is
            // the whole TabView, not just the photo's fitted rect.
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    chromeVisible.toggle()
                }
            }

            // Chrome layer
            VStack {
                HStack(alignment: .center, spacing: 10) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                    }
                    .marbleGlassCapsule(size: 44)

                    Spacer()

                    if photos.count >= 2 {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let idx = currentIndex
                            dismiss()
                            onCompareRequested?(idx)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "rectangle.split.1x2")
                                    .font(.system(size: 12, weight: .light))
                                Text("COMPARE")
                            }
                        }
                        .marbleGlassPill(horizontalPadding: 18, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if photos.indices.contains(currentIndex) {
                    PhotoDateChip(date: photos[currentIndex].date)
                        .padding(.bottom, 32)
                }
            }
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
        }
        .onAppear { currentIndex = initialIndex }
        // Drag down to dismiss
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

/// One photo at full-screen-ish size. Shared between browser and the
/// comparison halves.
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
                    .tint(Color("marbleSecondary"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            image = PhotoStorageService.shared.image(for: photo)
        }
    }
}

// MARK: - Side-by-side comparison

/// Two photos stacked vertically, each with independent horizontal
/// swipe. The user finds "before" on one half and "after" on the other
/// by scrubbing each side independently.
struct PhotoComparisonView: View {
    let photos: [ProgressPhoto]
    let initialTopIndex: Int
    let initialBottomIndex: Int

    @State private var topIndex: Int = 0
    @State private var bottomIndex: Int = 0
    @State private var chromeVisible: Bool = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var neutralBackground: Color {
        colorScheme == .dark ? .black : Color("marbleBackground")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            neutralBackground.ignoresSafeArea()

            // Two halves, scaledToFill + clipped — each takes exactly
            // half the available height for full-bleed comparison. A
            // small bg gap between halves (6pt) reads as "two moments"
            // without a hairline divider's "two panels" feeling.
            VStack(spacing: 6) {
                comparisonHalf(index: $topIndex, alignment: .bottomLeading)
                comparisonHalf(index: $bottomIndex, alignment: .topLeading)
            }

            // Chrome — just the close button, top-left to match the other
            // photo viewers. Date stamps overlay each half. Toggles with
            // the rest of the chrome.
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .light))
            }
            .marbleGlassCapsule(size: 44)
            .padding(.top, 8)
            .padding(.leading, 16)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(chromeVisible)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                chromeVisible.toggle()
            }
        }
        .onAppear {
            topIndex = initialTopIndex
            bottomIndex = initialBottomIndex
        }
    }

    /// One half of the comparison — full bleed, scaledToFill + clipped
    /// so the photo fills the half-screen rect without aspect bands.
    /// Date chip is positioned near the *gap*: top half's chip is
    /// bottom-left, bottom half's chip is top-left. Both sit on the
    /// same left margin near the center seam — the reader's natural
    /// scan line as they look across the two photos.
    @ViewBuilder
    private func comparisonHalf(index: Binding<Int>, alignment: Alignment) -> some View {
        let isTopHalf = (alignment == .bottomLeading)
        ZStack(alignment: alignment) {
            TabView(selection: index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { i, photo in
                    ComparisonHalfPhotoView(photo: photo)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if photos.indices.contains(index.wrappedValue) {
                PhotoDateChip(date: photos[index.wrappedValue].date)
                    .padding(isTopHalf ? .bottom : .top, 10)
                    .padding(.leading, 16)
                    .opacity(chromeVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// One half-screen comparison photo. Unlike BrowserPhotoView which uses
/// scaledToFit (preserves natural aspect, shows bg bands), this fills
/// the entire half-screen rect via scaledToFill + clipped — no empty
/// space, no inconsistent aspect bands across mixed-aspect photos.
struct ComparisonHalfPhotoView: View {
    let photo: ProgressPhoto
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.clear
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task {
            image = PhotoStorageService.shared.image(for: photo)
        }
    }
}

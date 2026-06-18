import SwiftUI
import UIKit

/// Single-column sibling of `ReorderableMetricsGrid`. Same architecture
/// — UICollectionView wrapped in `UIViewRepresentable`, SwiftUI cells
/// hosted via `UIHostingConfiguration`, native long-press → lift →
/// drag → reflow → snap reorder via the built-in interactive movement
/// API. One column instead of two. No system drag chrome.
///
/// Used by:
///   - Train templates list
///   - ActiveWorkout / TemplateEditor exercise reorder mode
///
/// API: caller passes `[Item]` where Item has a stable identifier
/// (we extract it via `itemID`), receives the new order via
/// `onReorder` on drop. Taps go through `onTap`.
struct ReorderableList<Item, Cell: View>: View {
    let items: [Item]
    let itemID: (Item) -> String
    let onReorder: ([Item]) -> Void
    let onTap: ((Item) -> Void)?
    /// Fires the moment the long-press recognizer activates (i.e.
    /// the cell is about to lift). Use to set any "we're dragging
    /// now" state in the parent so cells can re-render compact.
    var onDragStart: (() -> Void)? = nil
    /// Fires when the long-press recognizer ends — either successful
    /// drop or cancellation. Use to clear the drag state and let cells
    /// re-render expanded.
    var onDragEnd: (() -> Void)? = nil
    /// External state that should trigger cell content to re-render.
    /// `@ObservedObject` inside UIHostingConfiguration cells does NOT
    /// reliably propagate updates from objects owned outside the cell —
    /// UCV configures the cell once and doesn't observe further. When
    /// this value changes, the bridge calls `snapshot.reconfigureItems`
    /// which re-executes the cell registration closure with fresh
    /// content. Use for any external state that the cell content
    /// closure reads (e.g. a `reorderState.isReordering` flag).
    var reconfigureKey: AnyHashable? = nil
    @ViewBuilder let cellContent: (Item) -> Cell

    // The collection view's contentSize, observed via KVO. 0 means
    // "not measured yet."
    @State private var measuredHeight: CGFloat = 0

    /// Height enough to realize the first row so the self-sizing cascade
    /// can start. Used ONLY before the first real measurement — once the
    /// KVO reports a real contentSize we use that exactly. Without a
    /// non-zero bootstrap, an empty→non-empty list (e.g. a brand-new
    /// template gaining its first exercise) stays at height 0: a
    /// 0-height collection view realizes no cells, so contentSize never
    /// grows and the list is invisible forever.
    private let bootstrapHeight: CGFloat = 320

    var body: some View {
        CollectionBridge(
            items: items,
            itemID: itemID,
            onReorder: onReorder,
            onTap: onTap,
            onDragStart: onDragStart,
            onDragEnd: onDragEnd,
            reconfigureKey: reconfigureKey,
            onHeightChange: { newHeight in
                // Defer the @State write off the current runloop turn:
                // the contentSize KVO can fire while UIKit is laying out
                // inside a SwiftUI update, and mutating @State there
                // trips AttributeGraph's "setting value during update"
                // precondition (a crash). Async hops us out of it.
                DispatchQueue.main.async {
                    if abs(newHeight - measuredHeight) > 0.5 {
                        measuredHeight = newHeight
                    }
                }
            },
            cellContent: cellContent
        )
        .frame(height: items.isEmpty ? 0 : (measuredHeight > 0 ? measuredHeight : bootstrapHeight))
    }
}

// MARK: - Private UIKit bridge

private struct CollectionBridge<Item, Cell: View>: UIViewRepresentable {
    let items: [Item]
    let itemID: (Item) -> String
    let onReorder: ([Item]) -> Void
    let onTap: ((Item) -> Void)?
    let onDragStart: (() -> Void)?
    let onDragEnd: (() -> Void)?
    let reconfigureKey: AnyHashable?
    let onHeightChange: (CGFloat) -> Void
    @ViewBuilder let cellContent: (Item) -> Cell

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = Self.makeLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.allowsSelection = true
        collectionView.alwaysBounceVertical = false
        // Don't clip cards' shadows or hover lift at the collection
        // view's frame — matches ReorderableMetricsGrid's setup.
        collectionView.clipsToBounds = false
        collectionView.layer.masksToBounds = false

        let cellRegistration = UICollectionView.CellRegistration<ListHostingCell, String> { [coordinator = context.coordinator] cell, _, id in
            guard let item = coordinator.currentItems.first(where: { coordinator.parent.itemID($0) == id }) else {
                cell.host(AnyView(Color.clear))
                return
            }
            // Route through coordinator.parent.cellContent, NOT
            // self.cellContent — `self` is the CollectionBridge struct
            // captured by value at makeUIView time; it never sees
            // updates to the closure. `coordinator.parent` is updated
            // in updateUIView to the latest bridge instance, so its
            // cellContent reflects the latest captured state (e.g.
            // reorderState.isReordering).
            cell.host(AnyView(coordinator.parent.cellContent(item)))
        }

        let dataSource = UICollectionViewDiffableDataSource<Int, String>(
            collectionView: collectionView
        ) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: id
            )
        }

        dataSource.reorderingHandlers.canReorderItem = { _ in true }
        dataSource.reorderingHandlers.didReorder = { [weak coordinator = context.coordinator] transaction in
            coordinator?.handleDidReorder(newIDs: transaction.finalSnapshot.itemIdentifiers)
        }

        context.coordinator.dataSource = dataSource
        context.coordinator.collectionView = collectionView
        collectionView.dataSource = dataSource
        collectionView.delegate = context.coordinator

        context.coordinator.startObservingContentSize()

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.22
        collectionView.addGestureRecognizer(longPress)

        context.coordinator.apply(items: items, animated: false)

        return collectionView
    }

    /// Self-size to the collection view's content. Forcing a layout at
    /// the proposed width computes the real content height even when the
    /// list was previously empty (proposed height 0) — which is what
    /// breaks the empty→non-empty deadlock the old measuredHeight frame
    /// suffered. Returning nil width lets the list fill its container.
    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(items: items, animated: true)
        // Force cell content reconfiguration when the external key
        // changes — `@ObservedObject` inside UIHostingConfiguration
        // doesn't reliably trigger UCV cell updates on its own, so
        // we drive the refresh explicitly via the diffable snapshot.
        if context.coordinator.lastReconfigureKey != reconfigureKey {
            context.coordinator.lastReconfigureKey = reconfigureKey
            context.coordinator.reconfigureAllCells()
        }
    }

    static func dismantleUIView(_ uiView: UICollectionView, coordinator: Coordinator) {
        coordinator.stopObservingContentSize()
    }

    /// `UICollectionLayoutListConfiguration` — Apple's modern API for
    /// self-sizing list cells. Custom compositional layouts with
    /// `.estimated()` heights fight self-sizing when cells are much
    /// taller than the estimate (exercise cells render 400-600pt vs
    /// any reasonable estimate of 180pt), causing cell content to
    /// overflow into the next row visually. List config handles the
    /// height measurement correctly across the full range.
    private static func makeLayout() -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        config.headerMode = .none
        config.footerMode = .none
        return UICollectionViewCompositionalLayout.list(using: config)
    }
}

// MARK: - Coordinator

extension CollectionBridge {
    final class Coordinator: NSObject, UICollectionViewDelegate {
        var parent: CollectionBridge
        weak var collectionView: UICollectionView?
        var dataSource: UICollectionViewDiffableDataSource<Int, String>?
        var currentItems: [Item] = []
        /// Tracks the last reconfigureKey value so the bridge can
        /// detect when external state has changed and trigger a
        /// reconfigureItems pass.
        var lastReconfigureKey: AnyHashable?
        /// Outer ScrollView whose contentInset.top we expanded at
        /// drag-start to anchor the dragged cell. Restored on drag-end.
        weak var anchoredScrollView: UIScrollView?
        var anchoredTopInsetDelta: CGFloat = 0
        /// Outer ScrollView captured at drag-start regardless of
        /// whether we anchored — used to drive edge-zone auto-scroll
        /// while the user is dragging an exercise toward the top or
        /// bottom of the visible area.
        weak var dragScrollView: UIScrollView?
        private var dragDisplayLink: CADisplayLink?
        private var dragScrollVelocity: CGFloat = 0
        private var lastTouchInWindow: CGPoint = .zero
        private var contentSizeObservation: NSKeyValueObservation?

        init(parent: CollectionBridge) {
            self.parent = parent
        }

        func apply(items: [Item], animated: Bool) {
            currentItems = items
            var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            snapshot.appendSections([0])
            snapshot.appendItems(items.map(parent.itemID), toSection: 0)
            dataSource?.apply(snapshot, animatingDifferences: animated)
        }

        /// Re-executes the cell registration closure for every visible
        /// cell. Use to refresh cell content when external state
        /// changes (since UCV cells are configured once and don't
        /// observe outside state changes on their own).
        func reconfigureAllCells() {
            guard var snapshot = dataSource?.snapshot() else { return }
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
            // Apply WITHOUT the default diff animation — UIKit's built-in
            // diffable animation is a spring that overshoots, which read
            // as a bounce when a set was added/removed. The cell's height
            // change is instead driven by the SwiftUI animation wrapping
            // the data mutation (the List's measured-height frame), which
            // we keep critically damped → smooth, no bounce.
            dataSource?.apply(snapshot, animatingDifferences: false)
        }

        func handleDidReorder(newIDs: [String]) {
            let reordered = newIDs.compactMap { id in
                currentItems.first(where: { parent.itemID($0) == id })
            }
            currentItems = reordered
            parent.onReorder(reordered)
        }

        func startObservingContentSize() {
            guard let collectionView else { return }
            contentSizeObservation = collectionView.observe(\.contentSize, options: [.new]) { [weak self] _, change in
                guard let height = change.newValue?.height else { return }
                self?.parent.onHeightChange(height)
            }
        }

        func stopObservingContentSize() {
            contentSizeObservation?.invalidate()
            contentSizeObservation = nil
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView else { return }
            let location = gesture.location(in: collectionView)
            switch gesture.state {
            case .began:
                guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

                // Two kinds of consumer:
                //   * Collapsing lists (ActiveWorkout / TemplateEditor
                //     exercise cells) shrink each cell to its title
                //     while dragging. They signal this by providing an
                //     onDragStart closure. For them we restrict the
                //     drag grab to the top 60pt (so taps on sets/fields
                //     lower down keep their own gestures) and run the
                //     collapse-aware anchor + polling below.
                //   * Simple lists (Train templates, Track metrics)
                //     don't collapse — onDragStart is nil. The WHOLE
                //     row must initiate reorder, and movement can begin
                //     immediately with no polling/anchor. Applying the
                //     60pt restriction here was a regression that broke
                //     reorder on those lists.
                let collapses = parent.onDragStart != nil

                if collapses, let cell = collectionView.cellForItem(at: indexPath) {
                    let cellLocation = collectionView.convert(location, to: cell)
                    guard cellLocation.y <= 60 else { return }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                // Walk up to find the enclosing SwiftUI ScrollView's
                // UIScrollView — used for the collapse anchor and for
                // edge-zone auto-scroll (which both kinds of list get).
                let outerScrollView: UIScrollView? = {
                    var v: UIView? = collectionView.superview
                    while let next = v {
                        if let s = next as? UIScrollView, s !== collectionView {
                            return s
                        }
                        v = next.superview
                    }
                    return nil
                }()
                self.dragScrollView = outerScrollView

                parent.onDragStart?()

                guard collapses else {
                    // Simple list: cell size is stable, begin on the
                    // whole row right away.
                    collectionView.beginInteractiveMovementForItem(at: indexPath)
                    return
                }

                // Collapsing list: the cell shrinks from full height
                // (title + sets + +SET, up to 400-600pt) to just the
                // title (~60pt) when reorderState.isReordering flips.
                // That chain — SwiftUI state change → body recompute →
                // UIHostingConfiguration intrinsicContentSize change →
                // UCV invalidateLayout → cellForItem bounds update —
                // spans multiple runloop hops. beginInteractiveMovement
                // snapshots the cell at its size RIGHT NOW; called too
                // early it captures the tall version and centers it on
                // the finger, making the cell jump. Poll cellForItem's
                // bounds until it shrinks, then anchor + begin. Capped
                // at 10 ticks so we always begin eventually.
                let preCellMinY: CGFloat = collectionView
                    .cellForItem(at: indexPath)?
                    .convert(CGPoint.zero, to: outerScrollView).y ?? 0
                let preContentOffset = outerScrollView?.contentOffset.y ?? 0
                let targetIndexPath = indexPath
                let cv = collectionView
                func beginWhenCompact(attempt: Int) {
                    let height = cv.cellForItem(at: targetIndexPath)?.bounds.height ?? 0
                    if height < 80 || attempt >= 10 {
                        // Cells have collapsed. Anchor the dragged
                        // cell to its original on-screen Y by
                        // expanding the outer ScrollView's
                        // contentInset.top by however far the cell
                        // has moved up in content-space, then
                        // setting the offset to keep the cell where
                        // the finger pressed. Restored on drag-end.
                        if let scroll = outerScrollView,
                           let cell = cv.cellForItem(at: targetIndexPath) {
                            let newCellMinY = cell.convert(CGPoint.zero, to: scroll).y
                            let delta = preCellMinY - newCellMinY
                            let targetOffset = preContentOffset - delta
                            if delta > 0 {
                                var inset = scroll.contentInset
                                inset.top += delta
                                scroll.contentInset = inset
                                self.anchoredScrollView = scroll
                                self.anchoredTopInsetDelta = delta
                                scroll.setContentOffset(
                                    CGPoint(x: scroll.contentOffset.x, y: targetOffset),
                                    animated: false
                                )
                            }
                        }
                        cv.beginInteractiveMovementForItem(at: targetIndexPath)
                    } else {
                        DispatchQueue.main.async { beginWhenCompact(attempt: attempt + 1) }
                    }
                }
                DispatchQueue.main.async {
                    beginWhenCompact(attempt: 0)
                }
            case .changed:
                collectionView.updateInteractiveMovementTargetPosition(location)
                // Drive edge-zone auto-scroll. If the finger is
                // within `edgeZone` points of the top or bottom of
                // the outer scroll view's visible area, kick off a
                // CADisplayLink that scrolls in that direction
                // continuously (faster the closer to the edge) and
                // re-targets UCV each frame so the drop position
                // tracks the finger. Outside the edge zones, stop.
                if let scroll = dragScrollView, let host = scroll.superview {
                    let touchInHost = gesture.location(in: host)
                    lastTouchInWindow = gesture.location(in: nil)
                    // Quadratic ramp keyed off normalized depth into
                    // the edge zone, so just inside the zone you get
                    // a near-zero crawl and only the very edge maxes
                    // out the speed. Slower max overall — the
                    // previous 18 px/frame (~1080 px/s) felt
                    // teleport-y on a short list.
                    let edgeZone: CGFloat = 110
                    let maxVelocity: CGFloat = 7
                    let topEdge = scroll.frame.minY + edgeZone
                    let botEdge = scroll.frame.maxY - edgeZone
                    var velocity: CGFloat = 0
                    if touchInHost.y < topEdge {
                        let ratio = min(1, (topEdge - touchInHost.y) / edgeZone)
                        velocity = -(ratio * ratio) * maxVelocity
                    } else if touchInHost.y > botEdge {
                        let ratio = min(1, (touchInHost.y - botEdge) / edgeZone)
                        velocity = (ratio * ratio) * maxVelocity
                    }
                    dragScrollVelocity = velocity
                    if abs(velocity) > 0.05 {
                        startAutoScroll()
                    } else {
                        stopAutoScroll()
                    }
                }
            case .ended:
                stopAutoScroll()
                dragScrollView = nil
                collectionView.endInteractiveMovement()
                restoreAnchorInset()
                parent.onDragEnd?()
            default:
                stopAutoScroll()
                dragScrollView = nil
                collectionView.cancelInteractiveMovement()
                restoreAnchorInset()
                parent.onDragEnd?()
            }
        }

        /// CADisplayLink callback driving edge-zone auto-scroll. Each
        /// frame, advance the outer scroll view by `dragScrollVelocity`
        /// (clamped to its valid range) and re-target the UCV
        /// interactive movement at the finger's current window-space
        /// position, so the drop position tracks the finger as the
        /// page slides under it.
        @objc private func autoScrollTick() {
            guard let scroll = dragScrollView, dragScrollVelocity != 0 else {
                stopAutoScroll()
                return
            }
            let newY = scroll.contentOffset.y + dragScrollVelocity
            let minY = -scroll.contentInset.top
            let maxY = max(minY,
                scroll.contentSize.height
                - scroll.bounds.height
                + scroll.contentInset.bottom)
            let clampedY = max(minY, min(newY, maxY))
            if clampedY == scroll.contentOffset.y { return }
            scroll.contentOffset.y = clampedY
            guard let cv = collectionView else { return }
            let inUCV = cv.convert(lastTouchInWindow, from: nil)
            cv.updateInteractiveMovementTargetPosition(inUCV)
        }

        private func startAutoScroll() {
            guard dragDisplayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(autoScrollTick))
            link.add(to: .main, forMode: .common)
            dragDisplayLink = link
        }

        private func stopAutoScroll() {
            dragDisplayLink?.invalidate()
            dragDisplayLink = nil
            dragScrollVelocity = 0
        }

        /// Undo the contentInset.top expansion applied at drag-start.
        /// Animated so the scroll position changes in lockstep with
        /// the cells' spring expansion — doing it instantly leaves a
        /// frame where the inset has snapped back but the cells
        /// haven't, which feels like the page "got stuck" at the
        /// anchored position.
        private func restoreAnchorInset() {
            guard let scroll = anchoredScrollView, anchoredTopInsetDelta > 0 else { return }
            let delta = anchoredTopInsetDelta
            let originalInsetTop = scroll.contentInset.top - delta
            let targetOffsetY = scroll.contentOffset.y + delta
            anchoredScrollView = nil
            anchoredTopInsetDelta = 0
            var inset = scroll.contentInset
            inset.top = originalInsetTop
            scroll.contentInset = inset
            scroll.contentOffset = CGPoint(
                x: scroll.contentOffset.x,
                y: targetOffsetY
            )
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard currentItems.indices.contains(indexPath.item) else { return }
            parent.onTap?(currentItems[indexPath.item])
        }
    }
}

// MARK: - Hosting cell

/// Cell that hosts SwiftUI content via UIHostingConfiguration. Same
/// flatten-every-layer pattern as ReorderableMetricsGrid's ListHostingCell
/// so shadows extend cleanly and no UIKit default background bleeds
/// through.
private final class ListHostingCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureClearAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureClearAppearance()
    }

    private func configureClearAppearance() {
        clipsToBounds = false
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        contentView.layer.masksToBounds = false
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        backgroundView = nil
        selectedBackgroundView = nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    func host(_ view: AnyView) {
        backgroundConfiguration = UIBackgroundConfiguration.clear()
        contentConfiguration = UIHostingConfiguration {
            view
        }
        .margins(.all, 0)
        .background(Color.clear)
    }
}

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

    @State private var measuredHeight: CGFloat = 60

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
                if abs(newHeight - measuredHeight) > 0.5 {
                    measuredHeight = newHeight
                }
            },
            cellContent: cellContent
        )
        .frame(height: measuredHeight)
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
        longPress.minimumPressDuration = 0.35
        collectionView.addGestureRecognizer(longPress)

        context.coordinator.apply(items: items, animated: false)

        return collectionView
    }

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
            // Animate the diff so cell height changes (a set added /
            // removed grows or shrinks the exercise cell) flow into
            // the surrounding layout instead of snapping.
            dataSource?.apply(snapshot, animatingDifferences: true)
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
                // Restrict reorder to the cell's header region (top
                // 60pt). Long-presses on sets, fields, buttons further
                // down should be handled by their own gestures (swipe-
                // to-delete on set rows, etc.) without triggering
                // exercise reorder. This is the pattern Strong uses —
                // only the title area initiates reorder.
                if let cell = collectionView.cellForItem(at: indexPath) {
                    let cellLocation = collectionView.convert(location, to: cell)
                    guard cellLocation.y <= 60 else { return }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                // Walk up the view hierarchy to find the enclosing
                // SwiftUI ScrollView's UIScrollView. The collection
                // view itself IS a UIScrollView, so skip it. We use
                // the outer one to anchor the dragged cell at its
                // original on-screen position when the surrounding
                // cells collapse — without this, all the page
                // content reflows to the top, making it feel like
                // the page "snaps up" to start the drag.
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

                // Capture the dragged cell's content-space Y BEFORE
                // the collapse so we can compute how far it moves
                // and counter-scroll to compensate.
                let preCellMinY: CGFloat = collectionView
                    .cellForItem(at: indexPath)?
                    .convert(CGPoint.zero, to: outerScrollView).y ?? 0
                let preContentOffset = outerScrollView?.contentOffset.y ?? 0

                parent.onDragStart?()
                // The cell collapses from full-height (title + sets +
                // +SET button — can be 400-600pt) down to just the
                // title (~60pt) when reorderState.isReordering flips.
                // That chain — SwiftUI state change → cell body
                // recompute → UIHostingConfiguration intrinsicContentSize
                // change → UCV invalidateLayout → cellForItem bounds
                // update — spans multiple runloop hops. UCV's
                // beginInteractiveMovementForItem snapshots the cell
                // at whatever size it has RIGHT NOW; if we call it
                // before the chain settles, UCV captures the tall
                // version and centers its midpoint on the finger,
                // making the cell appear way above the touch and
                // snap back. Poll cellForItem's bounds until it has
                // actually shrunk, then begin movement. Capped at 10
                // ticks (~one frame each) so we always begin even if
                // the cell never compacts (e.g. an exercise with one
                // set whose total height is already small).
                let targetIndexPath = indexPath
                let cv = collectionView
                func beginWhenCompact(attempt: Int) {
                    let height = cv.cellForItem(at: targetIndexPath)?.bounds.height ?? 0
                    if height < 80 || attempt >= 10 {
                        // Cells have collapsed. The dragged cell has
                        // moved to a new content-space Y because the
                        // cells above it (if any) are now title-only.
                        // Adjust the outer scroll offset by the same
                        // delta so the dragged cell visually stays
                        // where the finger pressed it. This makes the
                        // page appear to compress AROUND the drag
                        // point instead of all flowing toward the top.
                        if let scroll = outerScrollView,
                           let cell = cv.cellForItem(at: targetIndexPath) {
                            let newCellMinY = cell.convert(CGPoint.zero, to: scroll).y
                            let delta = preCellMinY - newCellMinY
                            let targetOffset = preContentOffset - delta
                            // Clamp to the scroll view's legal range
                            // — if the dragged cell was near the top
                            // and there's no content above to "give",
                            // we'll just bottom out at offset 0 and
                            // the cell will sit higher than touched.
                            // That's the best we can do at the top
                            // boundary.
                            let topInset = scroll.adjustedContentInset.top
                            let bottomInset = scroll.adjustedContentInset.bottom
                            let maxOffset = max(-topInset,
                                scroll.contentSize.height
                                - scroll.bounds.height
                                + bottomInset)
                            let clamped = max(-topInset, min(targetOffset, maxOffset))
                            scroll.setContentOffset(
                                CGPoint(x: scroll.contentOffset.x, y: clamped),
                                animated: false
                            )
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
            case .ended:
                collectionView.endInteractiveMovement()
                parent.onDragEnd?()
            default:
                collectionView.cancelInteractiveMovement()
                parent.onDragEnd?()
            }
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

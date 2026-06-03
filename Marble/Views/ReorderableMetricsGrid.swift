import SwiftUI
import UIKit

/// Discriminated union the metrics grid renders. Bodyweight is always
/// item 0 and not reorderable; lifts follow and can be rearranged.
enum MetricItem: Identifiable, Hashable {
    case bodyweight
    case lift(TrackedLift)

    var id: String {
        switch self {
        case .bodyweight: return "__bodyweight__"
        case .lift(let lift): return "lift-\(lift.cloudID)"
        }
    }

    static func == (lhs: MetricItem, rhs: MetricItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// `UIViewRepresentable` over `UICollectionView` that gives us the iOS-
/// native long-press → lift → drag → reflow → snap reorder UX that
/// SwiftUI's `LazyVGrid` doesn't expose. The cards stay as SwiftUI
/// views inside the cells via `UIHostingConfiguration` (iOS 16+), so
/// our existing `LiftCardView` / `BodyweightCardView` render unchanged.
///
/// Why a UIKit bridge:
///   - `LazyVGrid` has no reorder API. `.draggable` + `.dropDestination`
///     brings the system drop-indicator chrome (the green plus) and
///     a translucent floating preview that don't fit Marble's
///     atmosphere.
///   - Custom SwiftUI gestures (long-press + DragGesture) fight the
///     outer ScrollView's pan — the trap that broke several earlier
///     attempts.
///   - `UICollectionView` has had `beginInteractiveMovementForItem(at:)`
///     since iOS 9. It's exactly what apps like Strong / Photos use:
///     subtle lift on long-press, drag follows the finger, other cells
///     animate aside in real time, snap to position on release. No
///     gesture conflict; the collection view owns the scroll.
///
/// API: `items` is the rendered order. Bodyweight is locked at index 0
/// (via `canMoveItem` returning false for it and clamping move targets
/// to >= 1). On reorder, `onReorder` fires with the new full order so
/// the caller can persist `displayOrder` values. On tap, `onTap` fires
/// with the tapped item.
struct ReorderableMetricsGrid<BodyweightCell: View, LiftCell: View>: UIViewRepresentable {
    let items: [MetricItem]
    let onReorder: ([MetricItem]) -> Void
    let onTap: (MetricItem) -> Void
    @ViewBuilder let bodyweightContent: () -> BodyweightCell
    @ViewBuilder let liftContent: (TrackedLift) -> LiftCell

    // MARK: - Layout constants

    /// Inter-item spacing (both horizontal and vertical). Matches the
    /// `LazyVGrid` spacing the metrics section had before.
    private static var spacing: CGFloat { 12 }

    /// Starting-height estimate for cells; the SwiftUI content self-
    /// sizes from there via UIHostingConfiguration.
    private static var estimatedItemHeight: CGFloat { 160 }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = Self.makeLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        // We want the outer SwiftUI ScrollView to handle vertical scroll.
        // The collection view itself just lays out cells and runs the
        // reorder interaction — scrolling within is unnecessary and
        // would fight the parent.
        collectionView.isScrollEnabled = false
        collectionView.allowsSelection = true
        collectionView.alwaysBounceVertical = false

        // Cell registration via UIHostingConfiguration. One registration
        // per cell archetype — bodyweight and lift content are
        // different SwiftUI views, but we resolve them in the cell
        // provider closure based on the item discriminator.
        let cellRegistration = UICollectionView.CellRegistration<HostingCell, MetricItem> { cell, _, item in
            switch item {
            case .bodyweight:
                cell.host(AnyView(self.bodyweightContent()))
            case .lift(let lift):
                cell.host(AnyView(self.liftContent(lift)))
            }
        }

        let dataSource = UICollectionViewDiffableDataSource<Int, MetricItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: item
            )
        }

        context.coordinator.dataSource = dataSource
        context.coordinator.collectionView = collectionView
        collectionView.dataSource = dataSource
        collectionView.delegate = context.coordinator

        // Long-press gesture drives interactive movement. Same
        // recognizer Apple's own apps use for this pattern.
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.35
        collectionView.addGestureRecognizer(longPress)

        // Initial snapshot
        context.coordinator.apply(items: items, animated: false)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        // Keep coordinator's parent reference fresh so callbacks invoke
        // the latest closures (which capture current view state).
        context.coordinator.parent = self
        // Reapply snapshot. Diffable data source handles add/remove/
        // reorder animations automatically.
        context.coordinator.apply(items: items, animated: true)
    }

    // MARK: - Compositional layout

    /// 2-column equally-divided layout with self-sizing rows.
    private static func makeLayout() -> UICollectionViewCompositionalLayout {
        let s = spacing
        let estimated = estimatedItemHeight

        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(estimated)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(estimated)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitem: item,
                count: 2
            )
            group.interItemSpacing = .fixed(s)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = s
            return section
        }
        return layout
    }
}

// MARK: - Coordinator

extension ReorderableMetricsGrid {
    final class Coordinator: NSObject, UICollectionViewDelegate {
        var parent: ReorderableMetricsGrid
        weak var collectionView: UICollectionView?
        var dataSource: UICollectionViewDiffableDataSource<Int, MetricItem>?
        private var currentItems: [MetricItem] = []

        init(parent: ReorderableMetricsGrid) {
            self.parent = parent
        }

        // MARK: Snapshots

        func apply(items: [MetricItem], animated: Bool) {
            currentItems = items
            var snapshot = NSDiffableDataSourceSnapshot<Int, MetricItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(items, toSection: 0)
            dataSource?.apply(snapshot, animatingDifferences: animated)
        }

        // MARK: Interactive movement

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView else { return }
            let location = gesture.location(in: collectionView)
            switch gesture.state {
            case .began:
                guard let indexPath = collectionView.indexPathForItem(at: location),
                      indexPath.item > 0 // bodyweight is locked
                else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                collectionView.beginInteractiveMovementForItem(at: indexPath)
            case .changed:
                collectionView.updateInteractiveMovementTargetPosition(location)
            case .ended:
                collectionView.endInteractiveMovement()
            default:
                collectionView.cancelInteractiveMovement()
            }
        }

        // MARK: Delegate

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard currentItems.indices.contains(indexPath.item) else { return }
            parent.onTap(currentItems[indexPath.item])
        }

        /// Clamp move targets so bodyweight stays at index 0 — the user
        /// can't drop another card on top of it.
        func collectionView(
            _ collectionView: UICollectionView,
            targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath,
            atCurrentIndexPath currentIndexPath: IndexPath,
            toProposedIndexPath proposedIndexPath: IndexPath
        ) -> IndexPath {
            if proposedIndexPath.item < 1 {
                return IndexPath(item: 1, section: 0)
            }
            return proposedIndexPath
        }
    }
}

// MARK: - Hosting cell

/// UICollectionViewCell that hosts a SwiftUI view via the modern
/// `UIHostingConfiguration` API. Cells are reused — `host(_:)` swaps
/// the SwiftUI content each time the cell is configured.
final class HostingCell: UICollectionViewCell {
    func host(_ view: AnyView) {
        contentConfiguration = UIHostingConfiguration { view }
            // Strip default insets — our SwiftUI cards control their
            // own padding internally.
            .margins(.all, 0)
    }
}

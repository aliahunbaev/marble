import SwiftUI
import UIKit

/// Public SwiftUI grid that wraps a `UICollectionView` for the iOS-
/// native long-press → lift → drag → reflow → snap reorder UX. The
/// public face is pure SwiftUI; the UIKit bridge is private below.
///
/// Specialized for the metrics tab: takes `[TrackedLift]`, reorders
/// freely (bodyweight has been moved out of the grid into its own
/// hero treatment above). Cells host arbitrary SwiftUI content via
/// `UIHostingConfiguration` (iOS 16+).
struct ReorderableMetricsGrid<Cell: View>: View {
    let lifts: [TrackedLift]
    let onReorder: ([TrackedLift]) -> Void
    let onTap: (TrackedLift) -> Void
    @ViewBuilder let cellContent: (TrackedLift) -> Cell

    var body: some View {
        CollectionBridge(
            lifts: lifts,
            onReorder: onReorder,
            onTap: onTap,
            cellContent: cellContent
        )
        .frame(height: gridHeight)
    }

    /// Height is derived directly from the lift count rather than a
    /// runtime contentSize measurement. The old KVO-measured height
    /// hadn't settled for the FIRST change after launch, so a
    /// newly-tracked lift only appeared on relaunch. Each card is a
    /// fixed 140pt in a 2-column grid with 12pt row spacing, so the
    /// height is exact and updates synchronously with the data.
    private var gridHeight: CGFloat {
        let count = lifts.count
        guard count > 0 else { return 0 }
        let rows = (count + 1) / 2          // ceil(count / 2)
        let cardHeight: CGFloat = 140
        let rowSpacing: CGFloat = 12
        return CGFloat(rows) * cardHeight + CGFloat(rows - 1) * rowSpacing
    }
}

// MARK: - Private UIKit bridge

private struct CollectionBridge<Cell: View>: UIViewRepresentable {
    let lifts: [TrackedLift]
    let onReorder: ([TrackedLift]) -> Void
    let onTap: (TrackedLift) -> Void
    @ViewBuilder let cellContent: (TrackedLift) -> Cell

    private static var spacing: CGFloat { 12 }
    private static var estimatedItemHeight: CGFloat { 170 }

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
        // Don't clip cards' shadows at the collection view's rect.
        // Cells already have `clipsToBounds = false` so shadows extend
        // past the cell — but the collection view's own bounds clip
        // them again at its frame edges, creating a visible "box"
        // outline where the shadow cuts off. Flatten clipping at every
        // level so shadows blend naturally into the page.
        collectionView.clipsToBounds = false
        collectionView.layer.masksToBounds = false

        // Cell registration. Stable lookup by cloudID — passed in via
        // the snapshot below. The data-source closure resolves the
        // lift from cloudID, then the cell hosts the SwiftUI content.
        let cellRegistration = UICollectionView.CellRegistration<HostingCell, String> { [coordinator = context.coordinator] cell, _, cloudID in
            guard let lift = coordinator.currentLifts.first(where: { $0.cloudID == cloudID }) else {
                cell.host(AnyView(Color.clear))
                return
            }
            cell.host(AnyView(self.cellContent(lift)))
        }

        let dataSource = UICollectionViewDiffableDataSource<Int, String>(
            collectionView: collectionView
        ) { collectionView, indexPath, cloudID in
            collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration,
                for: indexPath,
                item: cloudID
            )
        }

        // Reorder hooks. Diffable data sources DON'T fall back to the
        // classic `canMoveItemAt` / `moveItemAt` delegate methods —
        // interactive movement only works when these handlers are set.
        dataSource.reorderingHandlers.canReorderItem = { _ in true }
        dataSource.reorderingHandlers.didReorder = { [weak coordinator = context.coordinator] transaction in
            coordinator?.handleDidReorder(newCloudIDs: transaction.finalSnapshot.itemIdentifiers)
        }

        context.coordinator.dataSource = dataSource
        context.coordinator.collectionView = collectionView
        collectionView.dataSource = dataSource
        collectionView.delegate = context.coordinator

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.35
        collectionView.addGestureRecognizer(longPress)

        context.coordinator.apply(lifts: lifts, animated: false)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(lifts: lifts, animated: true)
    }

    static func dismantleUIView(_ uiView: UICollectionView, coordinator: Coordinator) {
    }

    private static func makeLayout() -> UICollectionViewCompositionalLayout {
        let s = spacing
        let estimated = estimatedItemHeight

        return UICollectionViewCompositionalLayout { _, _ in
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
    }
}

// MARK: - Coordinator

extension CollectionBridge {
    final class Coordinator: NSObject, UICollectionViewDelegate {
        var parent: CollectionBridge
        weak var collectionView: UICollectionView?
        var dataSource: UICollectionViewDiffableDataSource<Int, String>?
        var currentLifts: [TrackedLift] = []

        init(parent: CollectionBridge) {
            self.parent = parent
        }

        func apply(lifts: [TrackedLift], animated: Bool) {
            currentLifts = lifts
            var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            snapshot.appendSections([0])
            snapshot.appendItems(lifts.map(\.cloudID), toSection: 0)
            dataSource?.apply(snapshot, animatingDifferences: animated)
        }

        func handleDidReorder(newCloudIDs: [String]) {
            let reordered = newCloudIDs.compactMap { id in
                currentLifts.first(where: { $0.cloudID == id })
            }
            currentLifts = reordered
            parent.onReorder(reordered)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let collectionView else { return }
            let location = gesture.location(in: collectionView)
            switch gesture.state {
            case .began:
                guard let indexPath = collectionView.indexPathForItem(at: location) else { return }
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

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            guard currentLifts.indices.contains(indexPath.item) else { return }
            parent.onTap(currentLifts[indexPath.item])
        }
    }
}

// MARK: - Hosting cell

/// UICollectionViewCell that hosts a SwiftUI view via the modern
/// `UIHostingConfiguration` API.
///
/// `clipsToBounds = false` on both the cell and its content view so
/// SwiftUI `.shadow(...)` rendering can extend past the cell rect.
/// `backgroundConfiguration` is cleared so iOS doesn't paint a
/// default tinted fill behind the SwiftUI content.
final class HostingCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureClearAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureClearAppearance()
    }

    private func configureClearAppearance() {
        // Disable clipping at every level so SwiftUI shadows can extend
        // past the cell rect.
        clipsToBounds = false
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        contentView.layer.masksToBounds = false

        // Force transparent at every level. Modern UICollectionViewCells
        // get a default `backgroundConfiguration` and a contentView with
        // an inherited systemBackground — both of which paint a faint
        // off-white rectangle behind the SwiftUI card that reads as a
        // tint stripe through the cell gaps. Clearing every surface
        // forces only the SwiftUI card's own background to show.
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        backgroundView = nil
        selectedBackgroundView = nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reuse cycle can re-apply defaults; re-flatten on each cycle.
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

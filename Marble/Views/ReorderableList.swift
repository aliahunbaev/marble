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
            cell.host(AnyView(self.cellContent(item)))
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
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                // Tell SwiftUI the drag is starting so cells can
                // re-render compact BEFORE the interactive movement
                // snapshots the cell content.
                parent.onDragStart?()
                collectionView.beginInteractiveMovementForItem(at: indexPath)
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

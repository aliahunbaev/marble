import SwiftUI
import UIKit

/// A SwiftUI `ScrollView` replacement backed by a real `UIScrollView`.
///
/// Why this exists: the `ReorderableList` bridge modifies the
/// enclosing scroll view's `contentInset.top` and `contentOffset`
/// at drag-start to anchor the dragged exercise cell at the touch
/// point while the surrounding cells compress to title-only. iOS 26's
/// SwiftUI `ScrollView` aggressively reverts those writes within one
/// runloop tick (confirmed in logs — `contentInset.top` set to 305
/// reverted to 0 within ~1ms), so the anchor never visually held.
/// A UIKit-backed scroll view honours our writes; the bridge's
/// view-hierarchy walk still finds it as the enclosing `UIScrollView`
/// naturally.
///
/// What we preserve from SwiftUI's `ScrollView`:
///   - vertical scrolling
///   - interactive keyboard dismissal
///   - automatic safe-area inset adjustment (status bar / nav bar)
///   - content sizing driven by the intrinsic size of the hosted
///     SwiftUI tree
struct BackedScrollView<Content: View>: UIViewControllerRepresentable {
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> BackedScrollViewController<Content> {
        BackedScrollViewController(content: content())
    }

    func updateUIViewController(_ vc: BackedScrollViewController<Content>, context: Context) {
        vc.update(content: content())
    }
}

final class BackedScrollViewController<Content: View>: UIViewController {
    let scrollView = UIScrollView()
    let hostingController: UIHostingController<Content>

    init(content: Content) {
        self.hostingController = UIHostingController(rootView: content)
        super.init(nibName: nil, bundle: nil)
        // Tell the hosting controller to compute its own intrinsic
        // content size from the SwiftUI tree. Without this, the
        // hosted view returns a zero intrinsicContentSize, which
        // makes the scroll view's contentLayoutGuide collapse and
        // gives us no scrollable range.
        hostingController.sizingOptions = [.intrinsicContentSize]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.keyboardDismissMode = .interactive
        // Bouncing on the top edge lets brief contentInset writes
        // settle without snapping. With bounces off, UIScrollView
        // can clamp writes that exceed the natural range — same
        // class of problem we just escaped from on SwiftUI.
        scrollView.alwaysBounceVertical = true

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        scrollView.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        // Pin the hosted view inside the scroll view's content
        // layout guide (NOT the scroll view itself). The content
        // layout guide represents the actual scrollable content
        // area, so its size is driven by the hosted view's intrinsic
        // height — that's what gives us a proper tall scroll. Pinning
        // to scrollView.topAnchor / bottomAnchor directly clamps the
        // content to the frame size, which is why the workout only
        // showed a slice. The width is pinned to the frame layout
        // guide so the SwiftUI tree lays out at the visible width
        // and there's no horizontal scroll.
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    func update(content: Content) {
        hostingController.rootView = content
    }
}

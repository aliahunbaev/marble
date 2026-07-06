import WidgetKit
import SwiftUI

/// Marble's widget bundle. Only the rest-timer Live Activity for now —
/// the Xcode-generated placeholder home-screen widget and control were
/// removed (nothing designed for those surfaces yet).
@main
struct MarbleWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MarbleWidgetsLiveActivity()
    }
}

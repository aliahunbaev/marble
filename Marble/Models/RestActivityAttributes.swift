import ActivityKit
import Foundation

/// The rest timer's Live Activity contract — shared between the app
/// (which starts / updates / ends the activity from RestTimerState)
/// and the MarbleWidgets extension (which renders it in the Dynamic
/// Island and on the lock screen). This file is a member of BOTH
/// targets; ActivityKit matches the two sides by this type.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the rest ends. The widget renders the live countdown
        /// from this with Text(timerInterval:) — the system draws each
        /// second itself, so the app never needs to push tick updates,
        /// only adjustments (±10s) and the end.
        var endDate: Date
    }

    /// When the rest started — fixed for the activity's lifetime.
    var startDate: Date
}

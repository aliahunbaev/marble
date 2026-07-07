import Foundation
import UserNotifications

/// Schedules the "rest complete" local notification so the bell rings
/// even when the app is backgrounded or closed.
///
/// The in-app path (RestTimerState's 1-second tick → BoxingBell) only
/// runs while the app is foregrounded — iOS suspends the Timer the
/// moment the app leaves the foreground, so the round-end bell used to
/// go silent unless the app was open. The timer's end is deterministic
/// the moment it starts (wall-clock endDate), so we schedule a local
/// notification for that exact moment up front, and cancel/reschedule
/// as the timer is adjusted, skipped, or completes in-app.
///
/// Every schedule gets a UNIQUE identifier. Reusing one fixed id looked
/// tidy but hit an iOS behavior: adding a request whose id matches a
/// notification still sitting in Notification Center is treated as a
/// silent in-place update — banner refreshes, sound never plays. That
/// made the bell fire once (fresh id) and then go mute for every rest
/// after, until a reboot cleared Notification Center. Unique ids +
/// sweeping our previous ones (by prefix) keeps every rest a fresh,
/// audible notification.
///
/// Foreground dedupe lives in AppDelegate: willPresent returns [] so
/// when the app is open only the in-app bell + haptics fire — the
/// notification never double-sounds.
enum RestTimerNotifier {
    /// All our identifiers share this prefix so old ones can be swept
    /// even across app relaunches (where in-memory state is gone).
    private static let identifierPrefix = "marble.restTimer.done."

    /// Ask for notification permission the first time a rest timer
    /// starts (contextual — the user just did the thing the permission
    /// serves). No-op on subsequent calls once determined.
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Schedule (or reschedule) the round-end notification for `endDate`.
    static func schedule(endDate: Date) {
        let center = UNUserNotificationCenter.current()
        sweepOurs(center) {
            let remaining = endDate.timeIntervalSinceNow
            guard remaining > 1 else { return }

            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Back to work."
            // The same two-strike bell the app plays in the foreground.
            content.sound = UNNotificationSound(named: UNNotificationSoundName("marble-bell.aiff"))
            // Timers are Apple's canonical time-sensitive case: without
            // this the sound gets muted when the phone is locked or media
            // is playing (the exact moments a rest timer matters).
            // Requires the matching entitlement in Marble.entitlements.
            content.interruptionLevel = .timeSensitive

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + UUID().uuidString,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Cancel any pending round-end notification (skip / uncheck /
    /// in-app completion) and clear delivered ones.
    static func cancel() {
        sweepOurs(UNUserNotificationCenter.current()) {}
    }

    /// Remove every pending and delivered notification of ours (matched
    /// by prefix), then run `completion`. Prefix matching — rather than
    /// a remembered id — survives app relaunches, where a delivered
    /// notification from the previous run would otherwise linger and
    /// trigger the silent-update behavior on the next schedule.
    private static func sweepOurs(_ center: UNUserNotificationCenter, completion: @escaping () -> Void) {
        center.getPendingNotificationRequests { pending in
            let pendingIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            if !pendingIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
            }
            center.getDeliveredNotifications { delivered in
                let deliveredIDs = delivered.map(\.request.identifier).filter { $0.hasPrefix(identifierPrefix) }
                if !deliveredIDs.isEmpty {
                    center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
                }
                completion()
            }
        }
    }
}

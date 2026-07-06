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
/// Foreground dedupe lives in AppDelegate: willPresent returns [] so
/// when the app is open only the in-app bell + haptics fire — the
/// notification never double-sounds.
enum RestTimerNotifier {
    /// Single fixed identifier — a new schedule() replaces any previous
    /// pending request, so rapid set completions never stack requests.
    private static let identifier = "marble.restTimer.done"

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
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Back to work."
        // The same two-strike bell the app plays in the foreground.
        content.sound = UNNotificationSound(named: UNNotificationSoundName("boxing-bell.caf"))

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// Cancel the pending round-end notification (skip / uncheck /
    /// in-app completion) and clear any just-delivered one.
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

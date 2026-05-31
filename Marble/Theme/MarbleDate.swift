import Foundation

/// Centralized date formatting for Marble. Three opinionated helpers cover
/// every date string in the app — replaces the scattered `DateFormatter()`
/// instances that drifted into slightly different formats per-surface.
///
/// All output is uppercased to match Marble's editorial typography
/// convention (mono labels, dates as inscriptions). Each helper returns
/// strings ready to drop into `.font(.marbleMono(...))`.
extension Date {

    /// Relative day string for history lists and feeds.
    ///   - "TODAY"          (same calendar day)
    ///   - "YESTERDAY"      (previous day)
    ///   - "5D AGO"         (under a week)
    ///   - "MAY 12"         (current year, older than a week)
    ///   - "MAY 12, 2024"   (prior years)
    func marbleRelative() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "TODAY" }
        if calendar.isDateInYesterday(self) { return "YESTERDAY" }

        let days = calendar.dateComponents([.day], from: self, to: Date()).day ?? 0
        if days < 7 && days > 0 { return "\(days)D AGO" }

        let formatter = DateFormatter()
        let thisYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: self)
        formatter.dateFormat = dateYear == thisYear ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: self).uppercased()
    }

    /// Day-of-week + date inscription. Used for hero date stamps on
    /// content surfaces (Train tab quote, workout feed entries, workout
    /// detail header).
    ///   - "MONDAY · MAY 12"
    func marbleFullDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: self).uppercased()
    }

    /// Month + year label. Used for The Month grid header on Track and
    /// the "since" join date on YOU profile.
    ///   - "MAY 2026"
    func marbleMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self).uppercased()
    }
}

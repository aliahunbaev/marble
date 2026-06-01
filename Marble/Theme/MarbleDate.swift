import Foundation

/// Centralized date formatting for Marble. Three opinionated helpers cover
/// every date string in the app — replaces the scattered `DateFormatter()`
/// instances that drifted into slightly different formats per-surface.
///
/// All output is uppercased to match Marble's editorial typography
/// convention (mono labels, dates as inscriptions). Each helper returns
/// strings ready to drop into `.font(.marbleMono(...))`.
extension Date {

    /// Absolute date string for history lists, feeds, and photo metadata.
    ///   - "MAY 12"         (current year)
    ///   - "MAY 12, 2024"   (prior years)
    ///
    /// The name is kept for backwards compatibility with call sites but
    /// the relative forms (TODAY / YESTERDAY / Nd AGO) were removed —
    /// shifting dates feel jittery in a journal-style app where the
    /// same row says one thing today and another tomorrow. Absolute is
    /// quieter and more editorial.
    func marbleRelative() -> String {
        let calendar = Calendar.current
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

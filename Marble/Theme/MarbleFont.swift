import SwiftUI

/// Centralized Marble typography. One source of truth for all font references.
///
/// ## Weight philosophy
///
/// Marble uses **only Light and Regular** weights. No Medium, no Bold.
///
/// **Light is the default for body type.** Editorial books (Penguin Classics,
/// Phaidon monographs) lean light for titles and body alike — they use size,
/// space, and ink color to create hierarchy, not weight. Bold reads as sport-
/// bro / hustle-culture and breaks the editorial register Marble was built to
/// occupy. Regular is reserved for utility surfaces (button labels, current
/// data values) where the type doubles as an action affordance.
///
/// Use **Light** for: titles, headings, body type, quotes, column headers,
/// previous values, section labels, set numbers — basically everything that
/// belongs to the reading surface.
///
/// Use **Regular** for: utility button labels (FINISH, +SET, etc.), current
/// values typed by the user mid-workout. Anything that needs to read as
/// "active" or "tappable."
///
/// ## Reference hierarchy
///
///     | Element                        | Size | Weight  |
///     | ------------------------------ | ---- | ------- |
///     | Workout / Template title       | 32pt | Light   |
///     | Quote (Train tab)              | 22pt | Light   |
///     | Template name (Train list)     | 24pt | Light   |
///     | Exercise name (in workout)     | 17pt | Light   |
///     | Set value (typed number)       | 15pt | Regular |
///     | LAST / previous value          | 15pt | Light   |
///     | Set number                     | 13pt | Light   |
///     | Column headers (SET/LAST/etc.) | 13pt | Light   |
///     | Utility buttons                | 13pt | Regular |
///     | Section labels (PROGRAMS)      | 11pt | Light   |
///
/// ## Usage
///
///     .font(.marbleBody(17, weight: .regular))
///     .font(.marbleMono(13))           // weight defaults to .light
///     .font(.marbleScript(18))
extension Font {
    /// ABC Favorit Variable — the workhorse editorial sans. Use for body,
    /// headlines, UI labels.
    static func marbleBody(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom(MarbleFontName.body, size: size).weight(weight)
    }

    /// ABC Favorit Mono Variable — data, numbers, mono labels in caps.
    static func marbleMono(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom(MarbleFontName.mono, size: size).weight(weight)
    }

    /// Nothing You Could Do — handwritten script. Use sparingly for journal
    /// moments only.
    static func marbleScript(_ size: CGFloat) -> Font {
        .custom(MarbleFontName.script, size: size)
    }
}

/// PostScript names — what `Font.custom` actually resolves against. If a font
/// silently falls back to system, the most likely cause is a mismatched name
/// here. The actual font *file* name is different from the PostScript name.
enum MarbleFontName {
    static let body = "ABC Favorit Variable Unlicensed Trial"
    static let mono = "ABC Favorit Mono Variable Unlicensed Trial"
    static let script = "Nothing You Could Do"
}

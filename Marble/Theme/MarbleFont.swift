import SwiftUI

/// Centralized Marble typography. One source of truth for all font references.
///
/// ## Weight philosophy
///
/// Marble uses **only Light and Regular** weights. No Medium, no Bold.
///
/// Editorial books (Penguin Classics, Phaidon monographs) don't use heavy bold
/// for chapter titles — they use size + space + slight weight shifts to create
/// hierarchy. Bold reads as sport-bro / hustle-culture and breaks the editorial
/// register Marble has been built to occupy.
///
/// Use **Light** for whispered context: column headers, LAST/previous values,
/// section labels (PROGRAMS), set numbers, secondary text.
///
/// Use **Regular** for things that need presence: workout titles, exercise
/// names, current values typed by the user, action button labels, quote text
/// when it should land with weight.
///
/// (Single exception worth considering: future PR callouts could use Medium
/// for a single line. Don't go further than that without good reason.)
///
/// ## Reference hierarchy
///
///     | Element                        | Size | Weight  |
///     | ------------------------------ | ---- | ------- |
///     | Workout title                  | 32pt | Regular |
///     | Quote (Train tab)              | 22pt | Light   |
///     | Exercise name                  | 17pt | Regular |
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

import SwiftUI

/// Centralized Marble typography. One source of truth for all font references.
///
/// Usage:
///   .font(.marbleBody(20))
///   .font(.marbleMono(11, weight: .medium))
///   .font(.marbleScript(18))
///
/// Why this exists: previously the codebase used three different name strings
/// for what are really two fonts. Some used the file name (`ABCFavoritVariable-Trial`)
/// which doesn't match the PostScript name, causing silent fallback to the
/// system font. This namespace fixes that and centralizes future changes.
extension Font {
    /// ABC Favorit Variable — the workhorse editorial sans. Use for body, headlines, UI labels.
    static func marbleBody(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom(MarbleFontName.body, size: size).weight(weight)
    }

    /// ABC Favorit Mono Variable — data, numbers, mono labels in caps.
    static func marbleMono(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .custom(MarbleFontName.mono, size: size).weight(weight)
    }

    /// Nothing You Could Do — handwritten script, used sparingly for journal moments.
    static func marbleScript(_ size: CGFloat) -> Font {
        .custom(MarbleFontName.script, size: size)
    }
}

/// PostScript names — these are what `Font.custom` actually resolves against.
/// If a font silently falls back to system, the most likely cause is a mismatched name here.
enum MarbleFontName {
    static let body = "ABC Favorit Variable Unlicensed Trial"
    static let mono = "ABC Favorit Mono Variable Unlicensed Trial"
    static let script = "Nothing You Could Do"
}

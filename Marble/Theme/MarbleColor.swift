import SwiftUI

/// Centralized Marble color tokens.
///
/// Most surface colors live in the asset catalog as Color("marblePrimary") etc.
/// — they need light/dark variants and are referenced semantically. The tokens
/// here are Swift constants because they don't vary across appearance modes:
/// they're the warm-ink and destructive tones used regardless of theme.
extension Color {
    /// Warm near-black. Replaces pure black for primary actions.
    /// Reads as high contrast against bone, but doesn't visually "vibrate"
    /// the way pure #000 does on a warm background. Like a museum vitrine label.
    /// Use for: FINISH background, active rest timer capsule, SAVE background.
    static let marbleInk = Color(red: 0.105, green: 0.094, blue: 0.085)

    /// Museum-friendly destructive red. Replaces iOS systemRed (which reads "default").
    /// Use as foreground; pair with marbleDestructiveTint as background.
    static let marbleDestructive = Color(red: 0.62, green: 0.18, blue: 0.16)

    /// 8% opacity companion for destructive backgrounds.
    static let marbleDestructiveTint = Color(red: 0.62, green: 0.18, blue: 0.16)
        .opacity(0.08)

    /// The "input/secondary surface" tint, centralized.
    /// Used by input fields and now also by secondary action buttons so they
    /// share a single tonal language.
    static var marbleSurfaceTint: Color { Color("marblePrimary").opacity(0.06) }
}

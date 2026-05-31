import SwiftUI

/// Marble's glass-treatment vocabulary. One file, three archetypes — every
/// glass surface in the app routes through one of these so the visual language
/// stays cohesive. All three gate the iOS 26 .glassEffect() API behind
/// availability and fall back to .ultraThinMaterial on iOS 17–25 so users on
/// older versions still get a translucent surface, just without the refraction.
///
/// Archetypes:
///   1. LiquidGlassCardModifier — for browse/scan container surfaces
///      (YOU feed cards, template list rows). Rounded rectangle, content-shaped.
///   2. MarbleGlassCapsule — for chrome controls (gear, three-dots, +, ✕,
///      dismiss buttons). Plain glass capsule, no tint, holds an icon.
///   3. MarbleGlassPrimaryCapsule — for high-weight commits (FINISH, SAVE,
///      Start Workout). Tinted glass capsule, marbleInk foreground on bone
///      background. Keeps commitment weight while gaining the glass language.

// MARK: - Card container

/// Applies iOS 26's Liquid Glass treatment to a card-shaped container —
/// real refraction, bright edge highlights. The "written on glass" look used
/// for the YOU workout feed and the templates list.
struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color("marblePrimary").opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Chrome capsule (untinted)

/// A circular/capsule-shaped glass control for chrome elements — settings
/// gear, three-dots, +, close X, etc. The content (typically an icon or
/// short text) is laid out inside; this modifier adds the glass background,
/// shape, and a faint shadow for floatedness.
struct MarbleGlassCapsule: ViewModifier {
    var size: CGFloat = 36

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .foregroundStyle(Color("marblePrimary"))
                .frame(width: size, height: size)
                .glassEffect(.regular, in: Circle())
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 1)
        } else {
            content
                .foregroundStyle(Color("marblePrimary"))
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
                )
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 1)
        }
    }
}

// MARK: - Tinted primary capsule

/// A pill-shaped glass control tinted with marbleInk — for primary commit
/// actions (FINISH, SAVE, Start Workout). The tint gives commitment weight
/// while the glass base keeps the surface in the same visual language as the
/// rest of the Liquid Glass chrome.
struct MarbleGlassPrimaryCapsule: ViewModifier {
    var horizontalPadding: CGFloat = 20
    var height: CGFloat = 44

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .font(.marbleMono(13, weight: .regular))
                .tracking(1)
                .foregroundStyle(Color("marbleBackground"))
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .glassEffect(.regular.tint(Color("marblePrimary")), in: Capsule())
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        } else {
            content
                .font(.marbleMono(13, weight: .regular))
                .tracking(1)
                .foregroundStyle(Color("marbleBackground"))
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .background {
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(Color("marblePrimary"))
                    }
                }
                .overlay(
                    Capsule()
                        .stroke(Color("marblePrimary").opacity(0.15), lineWidth: 0.5)
                )
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Atmosphere background

/// The single source of truth for Marble's "content atmosphere" — a subtle
/// tonal vertical gradient (warm-cream top → bone middle → cool-bone bottom
/// on light; warm-charcoal → bone → cool-charcoal on dark). Used on every
/// content surface: the three primary tabs (Track/Train/You) and every
/// detail view (Workout/Lift/Bodyweight/ClosingRitual). Utility surfaces
/// (Settings) and work surfaces (ActiveWorkout, TemplateEditor) intentionally
/// stay plain — gradient signals "content to look at," plain signals "work
/// to do" or "configuration."
private struct MarbleAtmosphereBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        ZStack {
            Color("marbleBackground")
                .ignoresSafeArea()

            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0.13, green: 0.12, blue: 0.11),
                        Color("marbleBackground"),
                        Color(red: 0.10, green: 0.10, blue: 0.11)
                      ]
                    : [
                        Color(red: 0.97, green: 0.95, blue: 0.92),
                        Color("marbleBackground"),
                        Color(red: 0.94, green: 0.94, blue: 0.95)
                      ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            content
        }
    }
}

// MARK: - View extensions

extension View {
    /// Wraps a content surface in Marble's standard atmosphere — the tonal
    /// vertical gradient used on Track/Train/You and all content detail
    /// views. Defined once, applied via this modifier everywhere, so tweaks
    /// land in one place. Do NOT use on utility or work surfaces — those
    /// should stay plain to signal their different role.
    func marbleAtmosphereBackground() -> some View {
        modifier(MarbleAtmosphereBackground())
    }

    /// Wraps a card-shaped container in Liquid Glass (iOS 26) or its
    /// material fallback. Pair with .clipShape on the wrapped VStack if
    /// the content extends to the card edges.
    func marbleLiquidGlassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Wraps a chrome icon/control (gear, +, X, three-dots) in a circular
    /// glass surface. Default size is 36pt.
    func marbleGlassCapsule(size: CGFloat = 36) -> some View {
        modifier(MarbleGlassCapsule(size: size))
    }

    /// Wraps text in a tinted glass capsule for primary commit actions
    /// (FINISH, SAVE, Start Workout). Replaces the inline ZStack/Capsule
    /// pattern that was duplicated across ActiveWorkoutView, TemplateEditorView,
    /// and TrainView.
    func marbleGlassPrimaryCapsule(horizontalPadding: CGFloat = 20, height: CGFloat = 44) -> some View {
        modifier(MarbleGlassPrimaryCapsule(horizontalPadding: horizontalPadding, height: height))
    }
}

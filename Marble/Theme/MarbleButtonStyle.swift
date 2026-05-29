import SwiftUI

/// Three utility button archetypes. Apply as view modifiers on the inner Label
/// of a Button so the parent Button handles tap state.
///
/// Usage:
///     Button { ... } label: {
///         Text("FINISH")
///     }
///     .buttonStyle(.plain)
///     .modifier(MarblePrimaryButton())
///
/// Or via the View extensions below:
///     Button("FINISH") { ... }.marblePrimaryButton()

// MARK: - Primary (commit / finish)

/// Solid warm-ink background, bone foreground. The single most important
/// button on a screen. Used for: FINISH, SAVE, DONE.
/// Typography: 12pt mono with 1.2 tracking, uppercase by convention.
struct MarblePrimaryButton: ViewModifier {
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 9
    var fullWidth: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.marbleMono(12, weight: .regular))
            .tracking(1.2)
            .foregroundStyle(Color("marbleBackground"))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.marbleInk)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}

// MARK: - Secondary (additive / adjustable)

/// Tinted surface, ink foreground. Visually indistinguishable from input fields
/// by treatment — same fill, same corner radius. Used for: + SET, + EXERCISE,
/// rest presets, ±10s, rest timer toolbar (inactive).
struct MarbleSecondaryButton: ViewModifier {
    var fullWidth: Bool = true
    var compact: Bool = false
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .font(.marbleMono(compact ? 13 : 15))
            .foregroundStyle(Color("marblePrimary"))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.marbleSurfaceTint)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}

// MARK: - Destructive (discard / skip / delete)

/// Oxblood foreground on faint oxblood tint. Used for: DISCARD WORKOUT, SKIP,
/// future destructive confirmations.
/// Typography: 13pt mono with 1 tracking, uppercase by convention.
struct MarbleDestructiveButton: ViewModifier {
    var fullWidth: Bool = true
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .font(.marbleMono(13))
            .tracking(1)
            .foregroundStyle(Color.marbleDestructive)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.marbleDestructiveTint)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}

// MARK: - View extensions for ergonomic call sites

extension View {
    /// Primary action button — solid warm-ink. One per screen.
    func marblePrimaryButton(horizontalPadding: CGFloat = 16,
                             verticalPadding: CGFloat = 9,
                             fullWidth: Bool = false) -> some View {
        modifier(MarblePrimaryButton(
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            fullWidth: fullWidth
        ))
    }

    /// Secondary additive button — tinted surface matching input fields.
    func marbleSecondaryButton(fullWidth: Bool = true,
                               compact: Bool = false,
                               horizontalPadding: CGFloat = 14,
                               verticalPadding: CGFloat = 12) -> some View {
        modifier(MarbleSecondaryButton(
            fullWidth: fullWidth,
            compact: compact,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }

    /// Destructive button — oxblood on tinted oxblood.
    func marbleDestructiveButton(fullWidth: Bool = true,
                                 horizontalPadding: CGFloat = 14,
                                 verticalPadding: CGFloat = 12) -> some View {
        modifier(MarbleDestructiveButton(
            fullWidth: fullWidth,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        ))
    }
}

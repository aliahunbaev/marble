import SwiftUI

/// Three utility button archetypes. One typography spec across all three —
/// only color treatment differs by role.
///
/// Universal spec:
///     - Font: 13pt mono, regular weight, tracking 1
///     - Padding: 14pt horizontal, 10pt vertical
///     - Corner radius: 6pt (matches input fields)
///
/// Variants:
///     - Primary   — warm-ink fill on bone foreground (FINISH, SAVE, DONE)
///     - Secondary — tinted surface, ink foreground (+ SET, + EXERCISE, presets, ±10s)
///     - Destructive — oxblood fill at 8% with oxblood foreground (DISCARD, SKIP)
///
/// Floating glass variants live in MarbleFloatingButton.swift for the iOS 26
/// liquid-glass FINISH and rest timer at the top of the workout view.

// MARK: - Universal spec

private struct UtilitySpec {
    static let font: Font = .marbleMono(13, weight: .regular)
    static let tracking: CGFloat = 1
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 6
}

// MARK: - Primary

struct MarblePrimaryButton: ViewModifier {
    var fullWidth: Bool = false

    func body(content: Content) -> some View {
        content
            .font(UtilitySpec.font)
            .tracking(UtilitySpec.tracking)
            .foregroundStyle(Color("marbleBackground"))
            .padding(.horizontal, UtilitySpec.horizontalPadding)
            .padding(.vertical, UtilitySpec.verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.marbleInk)
            .clipShape(RoundedRectangle(cornerRadius: UtilitySpec.cornerRadius))
            .contentShape(Rectangle())
    }
}

// MARK: - Secondary

struct MarbleSecondaryButton: ViewModifier {
    var fullWidth: Bool = true

    func body(content: Content) -> some View {
        content
            .font(UtilitySpec.font)
            .tracking(UtilitySpec.tracking)
            .foregroundStyle(Color("marblePrimary"))
            .padding(.horizontal, UtilitySpec.horizontalPadding)
            .padding(.vertical, UtilitySpec.verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.marbleSurfaceTint)
            .clipShape(RoundedRectangle(cornerRadius: UtilitySpec.cornerRadius))
            .contentShape(Rectangle())
    }
}

// MARK: - Destructive

struct MarbleDestructiveButton: ViewModifier {
    var fullWidth: Bool = true

    func body(content: Content) -> some View {
        content
            .font(UtilitySpec.font)
            .tracking(UtilitySpec.tracking)
            .foregroundStyle(Color.marbleDestructive)
            .padding(.horizontal, UtilitySpec.horizontalPadding)
            .padding(.vertical, UtilitySpec.verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Color.marbleDestructiveTint)
            .clipShape(RoundedRectangle(cornerRadius: UtilitySpec.cornerRadius))
            .contentShape(Rectangle())
    }
}

// MARK: - View extensions

extension View {
    /// Primary action — solid warm-ink. One per screen (FINISH, SAVE).
    func marblePrimaryButton(fullWidth: Bool = false) -> some View {
        modifier(MarblePrimaryButton(fullWidth: fullWidth))
    }

    /// Secondary additive — tinted surface (+ SET, + EXERCISE, presets, ±10s).
    func marbleSecondaryButton(fullWidth: Bool = true) -> some View {
        modifier(MarbleSecondaryButton(fullWidth: fullWidth))
    }

    /// Destructive — oxblood (DISCARD, SKIP).
    func marbleDestructiveButton(fullWidth: Bool = true) -> some View {
        modifier(MarbleDestructiveButton(fullWidth: fullWidth))
    }
}

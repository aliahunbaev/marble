import SwiftUI

// MARK: - Branded confirmation dialog

/// Replaces system `.alert` / `.confirmationDialog` with a card that
/// fits the marble design language: editorial typography, glass
/// surface, restrained dim backdrop. The system equivalents render
/// via UIAlertController and are not customizable beyond a tint;
/// migrating every prompt onto this overlay gives the app one
/// coherent voice at every decision point.
///
/// Usage:
/// ```
/// .marbleDialog(
///     "Delete this workout?",
///     message: "This cannot be undone.",
///     isPresented: $showing,
///     buttons: [
///         .destructive("Delete") { delete() },
///         .cancel(),
///     ]
/// )
/// ```
struct MarbleDialogButton: Identifiable {
    enum Style { case standard, destructive, cancel }

    let id = UUID()
    let label: String
    let style: Style
    let action: () -> Void

    static func standard(_ label: String, action: @escaping () -> Void) -> MarbleDialogButton {
        MarbleDialogButton(label: label, style: .standard, action: action)
    }

    static func destructive(_ label: String, action: @escaping () -> Void) -> MarbleDialogButton {
        MarbleDialogButton(label: label, style: .destructive, action: action)
    }

    static func cancel(_ label: String = "Cancel", action: @escaping () -> Void = {}) -> MarbleDialogButton {
        MarbleDialogButton(label: label, style: .cancel, action: action)
    }
}

private struct MarbleDialogModifier: ViewModifier {
    let title: String
    let message: String?
    @Binding var isPresented: Bool
    let buttons: [MarbleDialogButton]

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                ZStack {
                    // Dim backdrop. Tapping it triggers the cancel
                    // button if one is provided (matching iOS's
                    // confirmationDialog convention), otherwise just
                    // dismisses.
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            if let cancel = buttons.first(where: { $0.style == .cancel }) {
                                fire(cancel)
                            } else {
                                isPresented = false
                            }
                        }

                    card
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isPresented)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(title)
                    .font(.marbleBody(20))
                    .foregroundStyle(Color("marblePrimary"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    Text(message)
                        .font(.marbleBody(14))
                        .foregroundStyle(Color("marbleSecondary"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Rectangle()
                .fill(Color("marblePrimary").opacity(0.08))
                .frame(height: 0.5)

            VStack(spacing: 0) {
                ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                    Button {
                        fire(button)
                    } label: {
                        Text(button.label)
                            .font(.marbleBody(16))
                            .foregroundStyle(foregroundColor(for: button.style))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < buttons.count - 1 {
                        Rectangle()
                            .fill(Color("marblePrimary").opacity(0.06))
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .frame(maxWidth: 340)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color("marbleBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 8)
        }
    }

    private func foregroundColor(for style: MarbleDialogButton.Style) -> Color {
        switch style {
        case .destructive: return .red
        case .standard:    return Color("marblePrimary")
        case .cancel:      return Color("marbleSecondary")
        }
    }

    private func fire(_ button: MarbleDialogButton) {
        // Dismiss first, then run the action on the next runloop so
        // the dismissal animation gets to start without being held
        // up by the action's work (e.g. a subsequent sheet present).
        isPresented = false
        DispatchQueue.main.async {
            button.action()
        }
    }
}

extension View {
    /// Branded replacement for `.alert` / `.confirmationDialog`.
    /// Pass an array of buttons (`.standard`, `.destructive`, or
    /// `.cancel`) — they render top-to-bottom in the card.
    func marbleDialog(
        _ title: String,
        message: String? = nil,
        isPresented: Binding<Bool>,
        buttons: [MarbleDialogButton]
    ) -> some View {
        modifier(MarbleDialogModifier(
            title: title,
            message: message,
            isPresented: isPresented,
            buttons: buttons
        ))
    }
}

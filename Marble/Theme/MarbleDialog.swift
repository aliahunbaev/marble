import SwiftUI
import UIKit

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
        // Present via fullScreenCover, not .overlay. An overlay is
        // clipped to the bounds of the view it's attached to — when a
        // dialog is triggered from inside a sheet (e.g. the template
        // detail sheet or Settings), that made the dim + card center
        // within the sheet instead of the whole screen. A full-screen
        // cover with a cleared background always covers the entire
        // window, so the card is screen-centered everywhere.
        content.fullScreenCover(isPresented: $isPresented) {
            MarbleDialogContent(
                title: title,
                message: message,
                buttons: buttons,
                isPresented: $isPresented
            )
            .presentationBackground(.clear)
        }
    }
}

/// Full-screen dialog body. Drawn over a cleared cover background so
/// only our dim + card show, centered on the whole window. Animates
/// its own fade + scale in and out (the cover itself carries no
/// visible chrome).
private struct MarbleDialogContent: View {
    let title: String
    let message: String?
    let buttons: [MarbleDialogButton]
    @Binding var isPresented: Bool
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    if let cancel = buttons.first(where: { $0.style == .cancel }) {
                        close(then: cancel.action)
                    } else {
                        close(then: {})
                    }
                }
            card
                .padding(.horizontal, 32)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { shown = true }
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
                        close(then: button.action)
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

    /// Animate the card out, THEN dismiss the cover and run the action.
    /// Running the action after dismissal keeps a follow-on present
    /// (sheet/cover) from racing this dismissal.
    private func close(then action: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 0.18)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            DispatchQueue.main.async { action() }
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

    /// Input-bearing sibling of `marbleDialog` — replaces system
    /// alerts that contain TextFields. Fields render between the
    /// title and the buttons, in the same editorial card.
    func marbleInputDialog(
        _ title: String,
        message: String? = nil,
        isPresented: Binding<Bool>,
        fields: [MarbleDialogField],
        confirmLabel: String,
        confirmEnabled: Bool = true,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(MarbleInputDialogModifier(
            title: title,
            message: message,
            isPresented: isPresented,
            fields: fields,
            confirmLabel: confirmLabel,
            confirmEnabled: confirmEnabled,
            onConfirm: onConfirm,
            onCancel: onCancel
        ))
    }
}

// MARK: - Input dialog

/// One text field inside a `marbleInputDialog` card.
struct MarbleDialogField: Identifiable {
    let id = UUID()
    let placeholder: String
    let text: Binding<String>
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
}

private struct MarbleInputDialogModifier: ViewModifier {
    let title: String
    let message: String?
    @Binding var isPresented: Bool
    let fields: [MarbleDialogField]
    let confirmLabel: String
    let confirmEnabled: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        // Full-screen cover (not .overlay) so the card centers on the
        // whole window even when triggered from inside a sheet. See
        // MarbleDialogContent for the rationale.
        content.fullScreenCover(isPresented: $isPresented) {
            MarbleInputDialogContent(
                title: title,
                message: message,
                fields: fields,
                confirmLabel: confirmLabel,
                confirmEnabled: confirmEnabled,
                onConfirm: onConfirm,
                onCancel: onCancel,
                isPresented: $isPresented
            )
            .presentationBackground(.clear)
        }
    }
}

private struct MarbleInputDialogContent: View {
    let title: String
    let message: String?
    let fields: [MarbleDialogField]
    let confirmLabel: String
    let confirmEnabled: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Binding var isPresented: Bool

    @FocusState private var focusedFieldID: UUID?
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { close(then: onCancel) }
            card
                .padding(.horizontal, 32)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { shown = true }
            // Focus the first field once the card has landed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedFieldID = fields.first?.id
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
            .padding(.bottom, 20)

            // Fields — underlined editorial inputs, matching the
            // onboarding name screen's treatment rather than boxed
            // system fields.
            VStack(spacing: 18) {
                ForEach(fields) { field in
                    VStack(spacing: 8) {
                        TextField(field.placeholder, text: field.text)
                            .font(.marbleBody(18))
                            .foregroundStyle(Color("marblePrimary"))
                            .multilineTextAlignment(.center)
                            .keyboardType(field.keyboard)
                            .textInputAutocapitalization(field.autocapitalization)
                            .autocorrectionDisabled()
                            .focused($focusedFieldID, equals: field.id)
                        Rectangle()
                            .fill(Color("marblePrimary").opacity(0.15))
                            .frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 24)

            Rectangle()
                .fill(Color("marblePrimary").opacity(0.08))
                .frame(height: 0.5)

            VStack(spacing: 0) {
                Button {
                    close(then: onConfirm)
                } label: {
                    Text(confirmLabel)
                        .font(.marbleBody(16))
                        .foregroundStyle(Color("marblePrimary").opacity(confirmEnabled ? 1 : 0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!confirmEnabled)

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.06))
                    .frame(height: 0.5)

                Button {
                    close(then: onCancel)
                } label: {
                    Text("Cancel")
                        .font(.marbleBody(16))
                        .foregroundStyle(Color("marbleSecondary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

    private func close(then action: @escaping () -> Void) {
        focusedFieldID = nil
        withAnimation(.easeOut(duration: 0.18)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            DispatchQueue.main.async { action() }
        }
    }
}

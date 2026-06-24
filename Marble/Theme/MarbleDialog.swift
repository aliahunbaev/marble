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

/// One dialog action, rendered as a clean full-width text row (no
/// fill) — the structure of a refined alert in Marble's type. Color
/// carries the role; allcaps mono matches every other action button.
/// High contrast in both light and dark because there's no fill to
/// wash out. Rows are separated by hairlines in the container.
///   - destructive → oxblood-red text
///   - standard    → primary (ink) text
///   - cancel      → muted secondary text
struct MarbleDialogPill: View {
    let label: String
    let style: MarbleDialogButton.Style

    var body: some View {
        Text(label.uppercased())
            .font(.marbleMono(13, weight: .regular))
            .tracking(1.5)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
    }

    private var textColor: Color {
        switch style {
        case .destructive: return Color.marbleDestructive
        case .standard:    return Color("marblePrimary")
        case .cancel:      return Color("marbleSecondary")
        }
    }
}

/// Hairline divider between dialog rows.
private struct MarbleDialogDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color("marblePrimary").opacity(0.08))
            .frame(height: 0.5)
    }
}

/// Hosts dialog content in a dedicated overlay UIWindow above the whole
/// app — the same approach the system alert uses. This gives full-screen
/// coverage from ANY context (root view, inside a sheet, inside the
/// workout cover) and a pure fade-in-place with no slide, which
/// fullScreenCover couldn't deliver consistently.
@MainActor
final class MarbleDialogWindow {
    static let shared = MarbleDialogWindow()

    final class Model: ObservableObject {
        @Published var content: AnyView?
    }

    private let model = Model()
    private var window: UIWindow?

    /// Present dialog content. `makeKey` brings the window to key status
    /// so text fields (input dialog) can receive keyboard input.
    func present<V: View>(makeKey: Bool = false, @ViewBuilder _ view: () -> V) {
        ensureWindow()
        model.content = AnyView(view())
        if makeKey {
            window?.makeKeyAndVisible()
        } else {
            window?.isHidden = false
        }
    }

    func dismiss() {
        // The card has already faded itself out (its `shown` state) by
        // the time this runs, so clearing + hiding is invisible.
        model.content = nil
        window?.isHidden = true
    }

    private func ensureWindow() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let host = UIHostingController(rootView: HostView(model: model))
        host.view.backgroundColor = .clear
        let w = UIWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.rootViewController = host
        window = w
    }

    private struct HostView: View {
        @ObservedObject var model: Model
        var body: some View {
            ZStack {
                if let content = model.content {
                    content
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}

private struct MarbleDialogModifier: ViewModifier {
    let title: String
    let message: String?
    @Binding var isPresented: Bool
    let buttons: [MarbleDialogButton]

    func body(content: Content) -> some View {
        // Present through the overlay window (see MarbleDialogWindow):
        // covers the whole screen from any context and fades in place
        // with no slide-up.
        content.onChange(of: isPresented) { _, now in
            if now {
                MarbleDialogWindow.shared.present {
                    MarbleDialogContent(
                        title: title,
                        message: message,
                        buttons: buttons,
                        isPresented: $isPresented
                    )
                }
            } else {
                MarbleDialogWindow.shared.dismiss()
            }
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
            // Title + message share one size, centered as a single
            // balanced statement; only color separates them.
            VStack(spacing: 6) {
                Text(title)
                    .font(.marbleBody(18))
                    .foregroundStyle(Color("marblePrimary"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    Text(message)
                        .font(.marbleBody(18))
                        .foregroundStyle(Color("marbleSecondary"))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 26)

            // Full-width text-row buttons separated by hairlines — no
            // fills to wash out or shout. Color carries the role.
            VStack(spacing: 0) {
                MarbleDialogDivider()
                ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                    Button {
                        close(then: button.action)
                    } label: {
                        MarbleDialogPill(label: button.label, style: button.style)
                    }
                    .buttonStyle(.plain)
                    if index < buttons.count - 1 {
                        MarbleDialogDivider()
                    }
                }
            }
        }
        .frame(maxWidth: 340)
        .background(Color("marbleBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 8)
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
    /// title and the buttons, in the same editorial card. An optional
    /// `selector` adds a single-select chip group below the fields for
    /// fixed-vocabulary choices (e.g. equipment) that shouldn't be free
    /// text.
    func marbleInputDialog(
        _ title: String,
        message: String? = nil,
        isPresented: Binding<Bool>,
        fields: [MarbleDialogField],
        selector: MarbleDialogSelector? = nil,
        confirmLabel: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        modifier(MarbleInputDialogModifier(
            title: title,
            message: message,
            isPresented: isPresented,
            fields: fields,
            selector: selector,
            confirmLabel: confirmLabel,
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
    /// When true, Confirm stays disabled until this field is non-empty.
    /// Evaluated live from the field's text, so it works even though the
    /// dialog is hosted in a separate window.
    var isRequired: Bool = false
}

/// Single-select chip group inside a `marbleInputDialog`, rendered below
/// the text fields. Used for fixed-vocabulary choices (e.g. equipment)
/// that shouldn't be free text. Tapping the active chip clears it, so an
/// empty selection ("" = uncategorized) is allowed.
struct MarbleDialogSelector {
    let label: String
    let options: [String]
    let selection: Binding<String>
}

private struct MarbleInputDialogModifier: ViewModifier {
    let title: String
    let message: String?
    @Binding var isPresented: Bool
    let fields: [MarbleDialogField]
    let selector: MarbleDialogSelector?
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        // Overlay window, keyed so the text fields get the keyboard.
        content.onChange(of: isPresented) { _, now in
            if now {
                MarbleDialogWindow.shared.present(makeKey: true) {
                    MarbleInputDialogContent(
                        title: title,
                        message: message,
                        fields: fields,
                        selector: selector,
                        confirmLabel: confirmLabel,
                        onConfirm: onConfirm,
                        onCancel: onCancel,
                        isPresented: $isPresented
                    )
                }
            } else {
                MarbleDialogWindow.shared.dismiss()
            }
        }
    }
}

private struct MarbleInputDialogContent: View {
    let title: String
    let message: String?
    let fields: [MarbleDialogField]
    let selector: MarbleDialogSelector?
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Binding var isPresented: Bool

    @FocusState private var focusedFieldID: UUID?
    @State private var shown = false

    /// Derived live from the field bindings (read in body) so it stays
    /// correct even though this view lives in a separate window.
    private var confirmEnabled: Bool {
        fields
            .filter(\.isRequired)
            .allSatisfy { !$0.text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty }
    }

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
        .marbleKeyboardDismiss()
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
            VStack(spacing: 6) {
                Text(title)
                    .font(.marbleBody(18))
                    .foregroundStyle(Color("marblePrimary"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    Text(message)
                        .font(.marbleBody(18))
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
            .padding(.bottom, selector == nil ? 24 : 20)

            // Optional fixed-vocabulary chip group (e.g. equipment).
            if let selector {
                VStack(spacing: 12) {
                    if !selector.label.isEmpty {
                        Text(selector.label.uppercased())
                            .font(.marbleMono(11, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(Color("marbleSecondary"))
                    }
                    FlowLayout(spacing: 8) {
                        ForEach(selector.options, id: \.self) { option in
                            Button {
                                let current = selector.selection.wrappedValue
                                selector.selection.wrappedValue = (current == option) ? "" : option
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                MarbleSelectorChip(
                                    label: option,
                                    isSelected: selector.selection.wrappedValue == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }

            // Same text-row vocabulary as the confirmation dialog.
            VStack(spacing: 0) {
                MarbleDialogDivider()
                Button {
                    close(then: onConfirm)
                } label: {
                    MarbleDialogPill(label: confirmLabel, style: .standard)
                        .opacity(confirmEnabled ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!confirmEnabled)

                MarbleDialogDivider()
                Button {
                    close(then: onCancel)
                } label: {
                    MarbleDialogPill(label: "Cancel", style: .cancel)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 340)
        .background(Color("marbleBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 8)
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

/// One chip in a `MarbleDialogSelector` group. Filled (ink) when active,
/// quiet field-fill when not.
private struct MarbleSelectorChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.marbleMono(12, weight: .medium))
            .foregroundStyle(isSelected ? Color("marbleBackground") : Color("marblePrimary"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color("marblePrimary") : Color("marbleFieldBackground"))
            .clipShape(Capsule())
    }
}

/// Minimal wrapping layout — lays subviews left-to-right, wrapping to a
/// new line when the next would overflow the proposed width. Centers
/// each row within the available width. Used for the dialog chip group.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = row.width == 0 ? size.width : row.width + spacing + size.width
            if projected > maxWidth, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.indices.append(index)
            row.width = row.width == 0 ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

import SwiftUI
import AudioToolbox

// MARK: - Rest Timer State

@Observable
class RestTimerState {
    var selectedDuration: Int = 0
    var remainingSeconds: Int = 0
    var isActive: Bool = false
    private(set) var endDate: Date = .distantPast
    private var timer: Timer?

    var progress: Double {
        guard selectedDuration > 0, isActive else { return 0 }
        let remaining = endDate.timeIntervalSince(Date())
        // Clamp 0...1 so adjustBy(+x) past the original duration doesn't
        // make the progress bar overflow its container.
        return min(1, max(0, remaining / Double(selectedDuration)))
    }

    var formattedRemaining: String {
        // Always M:SS so the pill width stays consistent during countdown
        // ("0:25" instead of "25s"). All values use 4 characters.
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func start(duration: Int) {
        selectedDuration = duration
        remainingSeconds = duration
        endDate = Date().addingTimeInterval(Double(duration))
        isActive = true
        startTicking()
    }

    func skip() {
        stop()
    }

    func adjustBy(_ seconds: Int) {
        endDate = endDate.addingTimeInterval(Double(seconds))
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(Date()))))
        // If adding time pushes remaining past the original duration, treat
        // the new remaining as the new 100% — so the ring/pill resets to full
        // and depletes from there, instead of sitting clamped at full until
        // the original duration is reached again.
        if remainingSeconds > selectedDuration {
            selectedDuration = remainingSeconds
        }
        if remainingSeconds == 0 {
            stop()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingSeconds = 0
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let remaining = Int(ceil(self.endDate.timeIntervalSince(Date())))
            self.remainingSeconds = max(0, remaining)
            if self.remainingSeconds == 0 {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                Self.playBoxingBell()
                self.stop()
            }
        }
    }

    /// Two short bell rings in quick succession — approximates a boxing-
    /// bell round-end. System sound 1013 is the shortest "ding" iOS ships;
    /// fired twice with a ~180ms gap reads as "ding ding." A custom .caf
    /// asset would sound more authentic — this is the system-sound
    /// approximation pending one.
    static func playBoxingBell() {
        AudioServicesPlaySystemSound(1013)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            AudioServicesPlaySystemSound(1013)
        }
    }
}

// MARK: - Floating Rest Timer Button (iOS-26 liquid glass)
//
// Morphs between a glass circle (idle, clock icon only) and a glass pill
// (counting down). Uses .ultraThinMaterial for the glass effect with a
// hairline stroke and quiet shadow. Animates smoothly between states.

struct FloatingRestTimerButton: View {
    @Bindable var state: RestTimerState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if state.isActive {
                activeView
            } else {
                idleView
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.isActive)
    }

    private var idleView: some View {
        Image(systemName: "clock")
            .font(.system(size: 14, weight: .regular))
            .marbleGlassCapsule(size: 44)
    }

    /// Shared content layout for the active timer — icon in a 44pt leading
    /// area to match the idle circle, text expanding to the right. Negative
    /// spacing pulls the text closer to the icon visually without moving the
    /// icon (so the morph from circle stays clean).
    private var timerContent: some View {
        HStack(spacing: -10) {
            Image(systemName: "clock")
                .font(.system(size: 14, weight: .regular))
                .frame(width: 44, height: 44)

            Text(state.formattedRemaining)
                .font(.marbleMono(13, weight: .regular))
                .tracking(1)
                .monospacedDigit()
                .padding(.trailing, 16)
        }
    }

    private var activeView: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            // Default-color content (dark in light mode, light in dark mode).
            // Visible in the UNFILLED (glass) portion of the pill.
            timerContent
                .foregroundStyle(Color("marblePrimary"))
                .background {
                    // Glass base + ink fill that recedes as time passes.
                    // Uses Color("marblePrimary") so the fill adapts to
                    // appearance — dark fill on light mode, light fill on
                    // dark mode (inverted both ways).
                    //
                    // Fill is a Rectangle (not Capsule) so the wiping edge is
                    // a clean vertical line. The outer clipShape(Capsule)
                    // still rounds the pill's outer left/right edges.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            glassBase
                            Rectangle()
                                .fill(Color("marblePrimary"))
                                .frame(width: geo.size.width * state.progress)
                        }
                    }
                }
                .overlay {
                    // Inverted-color content, masked to the FILLED region.
                    // Sits on top of the dark fill so the text reads bone
                    // where the fill is, ink where the fill isn't.
                    GeometryReader { geo in
                        timerContent
                            .foregroundStyle(Color("marbleBackground"))
                            .mask(
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .frame(width: geo.size.width * state.progress)
                                    Spacer(minLength: 0)
                                }
                            )
                    }
                }
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    /// Glass base for the active countdown pill — Liquid Glass on iOS 26+,
    /// material with a hairline stroke as a fallback. Kept as a computed view
    /// rather than calling .marbleGlassCapsule so the shape stays a Capsule
    /// (vs the circle the capsule helper uses).
    @ViewBuilder
    private var glassBase: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(Color.clear)
                .glassEffect(.regular, in: Capsule())
        } else {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m):\(String(format: "%02d", s))" : "\(m)m"
        }
        return "\(seconds)s"
    }
}

// MARK: - Rest Timer Modal

struct RestTimerModal: View {
    @Bindable var state: RestTimerState
    @Environment(\.dismiss) private var dismiss

    private let presets = [30, 60, 90, 120, 180, 300]

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color("marbleTertiary"))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            if state.isActive {
                activeTimerView
            } else {
                presetPickerView
            }
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        // iOS 26 system sheets get Liquid Glass automatically — same path
        // as the template detail sheet. Older iOS falls back to material.
        .modifier(RestTimerGlassBackgroundModifier())
    }

    // MARK: - Preset Picker (inactive)

    private var presetPickerView: some View {
        VStack(spacing: 24) {
            Text("REST TIMER")
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 12).weight(.light))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(presets, id: \.self) { seconds in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        state.start(duration: seconds)
                    } label: {
                        Text(formatPreset(seconds))
                            .marbleSecondaryButton()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Active Timer

    private var activeTimerView: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
        VStack(spacing: 36) {
            // Countdown ring — the number is the artifact, the ring is its
            // depleting clockface around it. Counter-clockwise depletion: the
            // ring shortens from its end (right of 12 o'clock) back toward
            // its start as time passes.
            ZStack {
                Circle()
                    .stroke(Color("marblePrimary").opacity(0.1), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(
                        Color("marblePrimary"),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(formattedBig)
                    .font(.marbleMono(48))
                    .foregroundStyle(Color("marblePrimary"))
                    .monospacedDigit()
            }
            .frame(width: 220, height: 220)
            .padding(.top, 8)

            // Controls
            HStack(spacing: 12) {
                Button {
                    state.adjustBy(-10)
                } label: {
                    Text("−10S")
                        .marbleSecondaryButton(fullWidth: false)
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    state.skip()
                    dismiss()
                } label: {
                    Text("SKIP")
                        .marbleDestructiveButton(fullWidth: false)
                }
                .buttonStyle(.plain)

                Button {
                    state.adjustBy(10)
                } label: {
                    Text("+10S")
                        .marbleSecondaryButton(fullWidth: false)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        }
    }

    private var formattedBig: String {
        let m = state.remainingSeconds / 60
        let s = state.remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatPreset(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m):\(String(format: "%02d", s))" : "\(m)m"
        }
        return "\(seconds)s"
    }
}

/// On iOS 17-25, applies .ultraThinMaterial as the sheet presentation
/// background. On iOS 26+, intentionally does nothing — the system gives
/// sheets Liquid Glass by default, and overriding it with a custom
/// presentationBackground would prevent the proper glass treatment.
private struct RestTimerGlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.presentationBackground(.ultraThinMaterial)
        }
    }
}

#Preview("Floating Button - Idle") {
    FloatingRestTimerButton(state: RestTimerState(), onTap: {})
        .padding()
}

#Preview("Modal") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            RestTimerModal(state: RestTimerState())
        }
}

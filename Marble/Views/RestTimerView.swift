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
        return max(0, remaining / Double(selectedDuration))
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
                AudioServicesPlaySystemSound(1007)
                self.stop()
            }
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
            .foregroundStyle(Color("marblePrimary"))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    /// Shared content layout for the active timer — icon in a 44pt leading
    /// area to match the idle circle, text expanding to the right.
    private var timerContent: some View {
        HStack(spacing: 0) {
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
                    // Glass base + dramatic ink fill that recedes as time
                    // passes. Using Color("marblePrimary") so the fill adapts
                    // to appearance — dark fill on light mode, light fill on
                    // dark mode (inverted both ways).
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.ultraThinMaterial)
                            Capsule()
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
                .overlay(
                    Capsule()
                        .stroke(Color("marblePrimary").opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
        .background(Color("marbleBackground"))
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(12)
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
        VStack(spacing: 28) {
            // Big remaining time
            Text(formattedBig)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 48).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
                .monospacedDigit()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color("marbleTertiary"))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color("marblePrimary"))
                        .frame(width: geo.size.width * state.progress, height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 24)

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

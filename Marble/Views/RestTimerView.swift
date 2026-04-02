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
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        }
        return "\(s)s"
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

// MARK: - Rest Timer Button (toolbar pill)

struct RestTimerButton: View {
    @Bindable var state: RestTimerState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if state.isActive {
                activeButton
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color("marbleSecondary"))
                    .frame(width: 36, height: 36)
            }
        }
        .buttonStyle(.plain)
    }

    private var timerLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
            Text(state.formattedRemaining)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
    }

    private var activeButton: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            GeometryReader { geo in
                let fillWidth = geo.size.width * state.progress
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color("marbleTertiary"))

                    // Fill
                    Capsule()
                        .fill(Color("marblePrimary"))
                        .frame(width: fillWidth)

                    // Dark text (full width, visible over unfilled)
                    timerLabel
                        .foregroundStyle(Color("marblePrimary"))

                    // Inverted text masked to filled region
                    timerLabel
                        .foregroundStyle(Color("marbleBackground"))
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().frame(width: fillWidth)
                                Spacer(minLength: 0)
                            }
                        )
                }
            }
            .frame(width: 90, height: 34)
            .clipShape(Capsule())
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
        .presentationCornerRadius(16)
    }

    // MARK: - Preset Picker (inactive)

    private var presetPickerView: some View {
        VStack(spacing: 24) {
            Text("REST TIMER")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Color("marbleSecondary"))

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(presets, id: \.self) { seconds in
                    Button {
                        state.start(duration: seconds)
                    } label: {
                        Text(formatPreset(seconds))
                            .font(.system(size: 17, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color("marblePrimary"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("marbleCard"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
                .font(.system(size: 56, weight: .light, design: .monospaced))
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
            HStack(spacing: 20) {
                Button {
                    state.adjustBy(-10)
                } label: {
                    Text("-10s")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(width: 72, height: 44)
                        .background(Color("marbleCard"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    state.skip()
                    dismiss()
                } label: {
                    Text("SKIP")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 44)
                        .background(Color(.systemRed).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    state.adjustBy(10)
                } label: {
                    Text("+10s")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(width: 72, height: 44)
                        .background(Color("marbleCard"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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

#Preview("Button - Inactive") {
    RestTimerButton(state: RestTimerState(), onTap: {})
        .padding()
}

#Preview("Modal") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            RestTimerModal(state: RestTimerState())
        }
}

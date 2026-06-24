import SwiftUI
import AVFoundation

// MARK: - Rest Timer State

@Observable
class RestTimerState {
    var selectedDuration: Int = 0
    var remainingSeconds: Int = 0
    var isActive: Bool = false
    /// The exercise entry whose set kicked off this rest. Drives the
    /// inline countdown bar (it renders only beneath that exercise).
    /// nil when the timer was started manually from the toolbar — in
    /// that case only the top-left floating pill shows the countdown.
    var originExerciseID: UUID? = nil
    /// The specific set that started this rest — the inline bar slots in
    /// directly beneath it.
    var originSetID: UUID? = nil
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

    func start(duration: Int, originExerciseID: UUID? = nil, originSetID: UUID? = nil) {
        selectedDuration = duration
        remainingSeconds = duration
        endDate = Date().addingTimeInterval(Double(duration))
        self.originExerciseID = originExerciseID
        self.originSetID = originSetID
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
        originExerciseID = nil
        originSetID = nil
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let remaining = Int(ceil(self.endDate.timeIntervalSince(Date())))
            self.remainingSeconds = max(0, remaining)
            if self.remainingSeconds == 0 {
                Self.fireRoundEnd()
                self.stop()
            }
        }
    }

    /// "Go mode" — the round-end signal: a synthesized boxing bell paired
    /// with a strong double buzz. The success notification + a heavy
    /// impact ~120ms later reads as a deliberate two-beat vibration
    /// rather than a single soft tap.
    static func fireRoundEnd() {
        BoxingBell.shared.ring()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

// MARK: - Boxing Bell

/// Plays the round-end boxing bell. Prefers a bundled audio file if one
/// is present (drop a `boxing-bell.<wav/caf/m4a/mp3/aiff>` into the app
/// target); otherwise falls back to a runtime-synthesized "ding-ding".
///
/// The synth approximates struck brass with INHARMONIC partials (non-
/// integer ratios — what makes metal ring instead of a pure tone), a
/// fast attack and exponential decay, two strikes ~190ms apart.
///
/// Either way it routes through an AVAudioSession configured for
/// `.playback` so it sounds even with the silent switch on, and
/// `.mixWithOthers` so it overlays the user's music instead of pausing it.
final class BoxingBell {
    static let shared = BoxingBell()

    /// Candidate filenames (without extension) and extensions to look for
    /// in the bundle. The first match wins. Drop your file in as any of
    /// these and it's picked up automatically — no code change needed.
    private static let fileNames = ["boxing-bell", "boxingbell", "bell"]
    private static let fileExtensions = ["wav", "caf", "m4a", "mp3", "aiff"]

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var buffer: AVAudioPCMBuffer?

    /// AVAudioPlayer for a bundled file, when one exists. Preferred over
    /// the synth fallback.
    private var filePlayer: AVAudioPlayer?

    private init() {
        if let url = Self.bundledBellURL(),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.prepareToPlay()
            filePlayer = player
        } else {
            // No file shipped — build the synthesized fallback buffer.
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            buffer = Self.makeBellBuffer(format: format, sampleRate: sampleRate)
        }
    }

    private static func bundledBellURL() -> URL? {
        for name in fileNames {
            for ext in fileExtensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }

    func ring() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)

        // Bundled file path.
        if let filePlayer {
            filePlayer.currentTime = 0
            filePlayer.play()
            return
        }

        // Synthesized fallback.
        guard let buffer else { return }
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        player.play()
    }

    private static func makeBellBuffer(format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer? {
        let duration = 1.1
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        // Bright brass-bell base with inharmonic partials. The ratios are
        // borrowed from struck-metal models — deliberately non-integer.
        let base = 660.0
        let partials: [(ratio: Double, amp: Double, decay: Double)] = [
            (1.00, 1.00, 5.0),
            (2.71, 0.60, 6.5),
            (5.43, 0.35, 8.0),
            (8.21, 0.18, 10.0),
        ]
        // Two strikes — "ding-ding". Second a touch quieter and later.
        let strikes: [(start: Double, gain: Double)] = [(0.0, 1.0), (0.19, 0.85)]

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for strike in strikes {
                let st = t - strike.start
                if st < 0 { continue }
                // Soft 4ms attack so the onset isn't a click.
                let attack = min(1.0, st / 0.004)
                var s = 0.0
                for p in partials {
                    s += p.amp * exp(-st * p.decay) * sin(2.0 * .pi * base * p.ratio * st)
                }
                sample += strike.gain * attack * s
            }
            // Headroom so overlapping strikes never clip past ±1.0.
            samples[i] = Float(sample * 0.18)
        }
        return buffer
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
        VStack(spacing: 0) {
            Text("REST TIMER")
                .font(.marbleMono(12))
                .tracking(1.5)
                .foregroundStyle(Color("marbleSecondary"))
                .padding(.bottom, 14)

            // Full-width rows — big tap targets, hairline-separated,
            // matching the dialog text-row vocabulary.
            ForEach(Array(presets.enumerated()), id: \.element) { index, seconds in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    state.start(duration: seconds)
                } label: {
                    Text(formatPreset(seconds))
                        .font(.marbleMono(16))
                        .tracking(1)
                        .foregroundStyle(Color("marblePrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < presets.count - 1 {
                    Rectangle()
                        .fill(Color("marblePrimary").opacity(0.08))
                        .frame(height: 0.5)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Active Timer

    private var activeTimerView: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
        VStack(spacing: 32) {
            // Countdown ring — the number is the artifact, the ring is its
            // depleting clockface around it.
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
            .padding(.top, 4)

            // Controls in one row: the adjusters are quiet glass pills
            // (same vocabulary as the nav buttons); SKIP is the solid
            // primary, carrying the contrast as the consequential action.
            HStack(spacing: 10) {
                Button {
                    state.adjustBy(-10)
                } label: {
                    Text("−10S").marbleSecondaryButton(fullWidth: true)
                }
                .buttonStyle(.plain)

                Button {
                    state.adjustBy(10)
                } label: {
                    Text("+10S").marbleSecondaryButton(fullWidth: true)
                }
                .buttonStyle(.plain)

                controlButton("SKIP") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    state.skip()
                    dismiss()
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        }
    }

    /// Solid, high-contrast control button (SKIP) for the running timer.
    /// Vertical padding matches marbleSecondaryButton (10) so it sits the
    /// same height as the glass adjuster pills beside it.
    private func controlButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.marbleMono(13, weight: .regular))
                .tracking(1)
                .foregroundStyle(Color("marbleBackground"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color("marblePrimary"), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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

// MARK: - Inline Rest Timer Bar
//
// Full-width countdown that slots in directly beneath the set you just
// completed. Reuses the floating pill's wipe-fill exactly: an ink fill
// that DRAINS left-to-right as the rest runs down, exposing the light
// bar beneath it. The content is rendered twice — ink over the unfilled
// (light) region, bone over the filled (black) region — so the text
// flips color cleanly across the draining edge. Tapping opens the modal;
// the trailing SKIP target ends the rest.

struct InlineRestTimerBar: View {
    @Bindable var state: RestTimerState
    let onTap: () -> Void
    let onSkip: () -> Void

    /// The bar's content laid out once; rendered in two colors (ink for
    /// the light region, bone for the filled region) by the two layers.
    private func content(_ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .regular))

            Text("RESTING")
                .font(.marbleMono(11))
                .tracking(1.5)

            Spacer()

            Text(state.formattedRemaining)
                .font(.marbleMono(15))
                .tracking(1)
                .monospacedDigit()

            Text("SKIP")
                .font(.marbleMono(11))
                .tracking(1)
                .opacity(0.55)
                .padding(.leading, 4)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            ZStack {
                // Base: ink content over the light bar, with the draining
                // black fill behind it (full at start, receding to empty).
                content(Color("marblePrimary"))
                    .background {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Color("marblePrimary").opacity(0.05)
                                Rectangle()
                                    .fill(Color("marblePrimary"))
                                    .frame(width: geo.size.width * state.progress)
                            }
                        }
                    }

                // Overlay: bone content, masked to the filled region so it
                // shows only where the black fill currently is.
                GeometryReader { geo in
                    content(Color("marbleBackground"))
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: geo.size.width * state.progress)
                                Spacer(minLength: 0)
                            }
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            // SKIP hit target, kept separate from the wipe layers so the
            // tap isn't swallowed by the open-modal gesture.
            .overlay(alignment: .trailing) {
                Button(action: onSkip) {
                    Color.clear
                        .frame(width: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
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

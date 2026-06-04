import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 1
    @State private var workoutSession = WorkoutSession()
    @State private var didAttemptRestore = false
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let tabs = ["TRACK", "TRAIN", "YOU"]

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainAppView
            } else {
                NavigationStack {
                    OnboardingFlow()
                }
            }
        }
        .environment(workoutSession)
        .preferredColorScheme(colorScheme)
        // Restore an in-progress workout on first appearance — uses
        // ModelContext to resolve exercise references by name.
        // didAttemptRestore guards against re-running if the view
        // re-appears (it shouldn't matter since restoreSnapshot is
        // idempotent on the same data, but cleaner this way).
        .task {
            guard !didAttemptRestore else { return }
            didAttemptRestore = true
            workoutSession.restoreSnapshot(context: modelContext)
        }
        // Snapshot on backgrounding so any in-flight edits (typed
        // weight that hasn't lost focus yet) get persisted. The
        // start/end calls also snapshot, but those don't fire when
        // the user is just editing.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                workoutSession.saveSnapshot()
            }
        }
    }

    private var mainAppView: some View {
        @Bindable var session = workoutSession

        return ZStack(alignment: .bottom) {
            // Content fills the full screen, including under the tab bar so
            // the bar's glass has something to refract.
            Group {
                switch selectedTab {
                case 0: TrackView()
                case 1: TrainView()
                case 2: YouView()
                default: TrainView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                // Mini-bar — shown when a workout is active AND minimized.
                // Tap to re-expand. Workout continues recording the whole
                // time because the timer lives in WorkoutSession, not in
                // ActiveWorkoutView.
                if workoutSession.isActive && !workoutSession.isExpanded {
                    WorkoutMiniBar(session: workoutSession)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Custom tab bar — glass refracts content scrolling beneath.
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = index
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(tabs[index])
                                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.medium))
                                    .tracking(1)
                                    .foregroundStyle(selectedTab == index ? Color("marblePrimary") : Color("marbleSecondary"))

                                Circle()
                                    .fill(selectedTab == index ? Color("marblePrimary") : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .modifier(TabBarGlassModifier())
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workoutSession.isExpanded)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: workoutSession.isActive)
        }
        .ignoresSafeArea(.keyboard)
        // Workout presented at the ContentView level so it survives tab
        // changes and can be re-expanded from the mini-bar regardless of
        // which tab is currently selected.
        .fullScreenCover(isPresented: $session.isExpanded) {
            ActiveWorkoutView()
                .environment(workoutSession)
        }
    }
}

/// Mini-bar shown above the tab bar when a workout is in progress and
/// minimized. Glass capsule, workout name + elapsed time. Tap → expand
/// back to the full ActiveWorkoutView.
private struct WorkoutMiniBar: View {
    @Bindable var session: WorkoutSession

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            session.expand()
        } label: {
            HStack(spacing: 12) {
                // Tiny pulsing dot — "live" indicator
                Circle()
                    .fill(Color("marblePrimary"))
                    .frame(width: 6, height: 6)

                Text(session.name.isEmpty ? "Workout" : session.name)
                    .font(.marbleBody(15))
                    .foregroundStyle(Color("marblePrimary"))
                    .lineLimit(1)

                Spacer()

                Text(session.formattedTime)
                    .font(.marbleMono(13))
                    .monospacedDigit()
                    .foregroundStyle(Color("marbleSecondary"))

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color("marbleSecondary"))
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .marbleGlassPill(horizontalPadding: 0, height: 52)
        }
        .buttonStyle(.plain)
    }
}

/// Applies real Liquid Glass to the tab bar on iOS 26+. The glass background
/// is sized wider AND taller than the visible area so the bright edge
/// highlights on the left, right, and bottom end up off-screen — only the
/// subtle top edge remains visible (which is what gives it the glass
/// character). A faint backdrop is layered behind the glass so the labels
/// stand out a touch more against busy scrolling content.
/// Falls back to .ultraThinMaterial on iOS 17-25.
private struct TabBarGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    ZStack {
                        // Faint backdrop — fogs the content slightly so the
                        // tab labels read cleanly without losing the glass
                        // character of the bar.
                        Rectangle()
                            .fill(Color("marbleBackground").opacity(0.35))
                        Rectangle()
                            .fill(Color.clear)
                            .glassEffect(.regular, in: Rectangle())
                    }
                    .padding(.horizontal, -40) // hide vertical edge shines
                    .padding(.bottom, -40)     // hide bottom edge shine
                    .ignoresSafeArea(edges: .bottom)
                }
        } else {
            content
                .background(.ultraThinMaterial.opacity(0.95))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutTemplate.self, Workout.self], inMemory: true)
}

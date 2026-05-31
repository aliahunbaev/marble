import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
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
        .preferredColorScheme(colorScheme)
    }

    private var mainAppView: some View {
        ZStack(alignment: .bottom) {
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

            // Custom tab bar — taller, glass refracts content scrolling
            // beneath, extends through the bottom safe area. Matches the
            // Quran-app reference: the bar reads as a glass surface
            // floating over content, not a small chrome strip.
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
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 32) // breathing room above home indicator
            .modifier(TabBarGlassModifier())
        }
        .ignoresSafeArea(.keyboard)
    }
}

/// Applies real Liquid Glass to the tab bar on iOS 26+ via .glassEffect
/// directly on the bar (proper refraction, edge highlight). Extends through
/// the bottom safe area so the glass continues into the home indicator zone.
/// Falls back to .ultraThinMaterial on iOS 17-25.
private struct TabBarGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    Rectangle()
                        .fill(Color.clear)
                        .glassEffect(.regular, in: Rectangle())
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

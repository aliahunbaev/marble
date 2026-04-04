import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @AppStorage("appTheme") private var appTheme: String = "system"

    private let tabs = ["TRACK", "TRAIN", "YOU"]

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch selectedTab {
                case 0: TrackView()
                case 1: TrainView()
                case 2: YouView()
                default: TrainView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            Rectangle()
                .fill(Color("marblePrimary").opacity(0.06))
                .frame(height: 0.5)
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
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 16)
            .background(Color("marbleBackground"))
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutTemplate.self, Workout.self], inMemory: true)
}

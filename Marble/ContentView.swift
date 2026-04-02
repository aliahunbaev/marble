import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1

    private let tabs = ["TRACK", "TRAIN", "YOU"]

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
                .fill(Color("marbleTertiary"))
                .frame(height: 1)
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = index
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tabs[index])
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .tracking(1.5)
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutTemplate.self, Workout.self], inMemory: true)
}

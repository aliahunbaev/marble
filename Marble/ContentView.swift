
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FoodTrackingView()
                .tabItem {
                    Label("FUEL", systemImage: "fork.knife")
                }

            WeightTrackingView()
                .tabItem {
                    Label("WEIGHT", systemImage: "chart.line.uptrend.xyaxis")
                }

            WorkoutTrackingView()
                .tabItem {
                    Label("TRAIN", systemImage: "dumbbell.fill")
                }

            ProgressPhotosView()
                .tabItem {
                    Label("PROGRESS", systemImage: "camera.fill")
                }
        }
        .tint(.marblePrimary)
    }
}

#Preview {
    ContentView()
}

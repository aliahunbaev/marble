import SwiftUI
import SwiftData

struct YouView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("defaultRestTimer") private var defaultRestTimer: Int = 90
    @State private var showingClearConfirmation = false

    private let restTimerOptions = [30, 60, 90, 120, 180, 300]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    appearanceSection
                    preferencesSection
                    dataSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationBarTitleDisplayMode(.inline)
            .alert("Clear All Data", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will delete all workouts, templates, and exercise data. This cannot be undone.")
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "APPEARANCE")

            HStack(spacing: 0) {
                themeOption(label: "Light", value: "light", icon: "sun.max")
                themeOption(label: "Dark", value: "dark", icon: "moon")
                themeOption(label: "System", value: "system", icon: "circle.lefthalf.filled")
            }
        }
    }

    private func themeOption(label: String, value: String, icon: String) -> some View {
        let isSelected = appTheme == value
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                appTheme = value
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                Text(label)
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                    .tracking(0.5)
            }
            .foregroundStyle(isSelected ? Color("marblePrimary") : Color("marbleSecondary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected ? Color("marblePrimary") : Color("marblePrimary").opacity(0.12),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "PREFERENCES")

            VStack(spacing: 0) {
                // Weight Unit
                HStack {
                    Text("Weight Unit")
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                    Spacer()
                    HStack(spacing: 0) {
                        unitOption(label: "lbs", isSelected: weightUnit == "lbs") {
                            weightUnit = "lbs"
                        }
                        unitOption(label: "kg", isSelected: weightUnit == "kg") {
                            weightUnit = "kg"
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 14)

                // Rest Timer
                HStack {
                    Text("Rest Timer")
                        .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                        .foregroundStyle(Color("marblePrimary"))
                    Spacer()
                    Menu {
                        ForEach(restTimerOptions, id: \.self) { seconds in
                            Button {
                                defaultRestTimer = seconds
                            } label: {
                                HStack {
                                    Text(formatRestTimer(seconds))
                                    if seconds == defaultRestTimer {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(formatRestTimer(defaultRestTimer))
                                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                                .foregroundStyle(Color("marbleSecondary"))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(Color("marbleSecondary"))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private func unitOption(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                .foregroundStyle(isSelected ? Color("marblePrimary") : Color("marbleSecondary"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? Color("marblePrimary") : Color("marblePrimary").opacity(0.12),
                            lineWidth: isSelected ? 1 : 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func formatRestTimer(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m):\(String(format: "%02d", s))m" : "\(m)m"
        }
        return "\(seconds)s"
    }

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "DATA")

            Button {
                showingClearConfirmation = true
            } label: {
                Text("Clear All Data")
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: TrackedLift.self)
            try modelContext.delete(model: Workout.self)
            try modelContext.delete(model: ExerciseLog.self)
            try modelContext.delete(model: WorkoutSet.self)
            try modelContext.delete(model: WorkoutTemplate.self)
            try modelContext.delete(model: Exercise.self)
            try modelContext.save()
        } catch {
            // Silently handle
        }
    }
}

#Preview {
    YouView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

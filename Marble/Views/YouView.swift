import SwiftUI
import SwiftData

struct YouView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
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

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "PREFERENCES")

            VStack(spacing: 0) {
                settingsRow(label: "Weight Unit", value: "lbs")
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.leading, 14)
                settingsRow(label: "Rest Timer", value: "90s")
            }
        }
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                .foregroundStyle(Color("marblePrimary"))
            Spacer()
            Text(value)
                .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
                .foregroundStyle(Color("marbleSecondary"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
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

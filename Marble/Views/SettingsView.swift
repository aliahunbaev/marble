import SwiftUI
import SwiftData

/// Settings sub-screen — accessed via the gear icon on the You tab.
/// Contains the configurations users rarely revisit: app icon, appearance,
/// preferences, and destructive data actions. Burying these one tap deeper
/// frees the You tab to be an identity surface (profile + workout feed).
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("appIcon") private var appIcon: String = "light"

    @State private var showingClearConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false

    /// The sheet's color scheme. We ALWAYS resolve to an explicit .light or
    /// .dark and never pass nil — passing nil to .preferredColorScheme on a
    /// sheet doesn't unwind a previously forced scheme cleanly. For "system",
    /// we read the actual device color scheme from the active window scene.
    private var resolvedScheme: ColorScheme {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return systemColorScheme
        }
    }

    private var systemColorScheme: ColorScheme {
        let scenes = UIApplication.shared.connectedScenes
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = scene.windows.first {
            return window.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }
        return .light
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    appIconSection
                    appearanceSection
                    preferencesSection
                    dataSection
                    if auth.isAuthenticated {
                        accountSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(.marbleMono(11))
                        .tracking(2)
                        .foregroundStyle(Color("marblePrimary"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
            }
            .alert("Clear All Data", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will delete all workouts, templates, and exercise data. This cannot be undone.")
            }
        }
        .preferredColorScheme(resolvedScheme)
    }

    // MARK: - App Icon

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "APP ICON")

            HStack(spacing: 12) {
                iconOption(label: "Light", value: "light", imageName: "icon-preview-light")
                iconOption(label: "Dark", value: "dark", imageName: "icon-preview-dark")
            }
        }
    }

    private func iconOption(label: String, value: String, imageName: String) -> some View {
        let isSelected = appIcon == value
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appIcon = value
            let iconName: String? = value == "light" ? nil : "AppIcon-Dark"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error {
                        print("Icon change error: \(error)")
                    }
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(imageName)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? Color("marblePrimary") : Color("marblePrimary").opacity(0.12),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
                Text(label)
                    .font(.marbleMono(11))
                    .tracking(1)
                    .foregroundStyle(isSelected ? Color("marblePrimary") : Color("marbleSecondary"))
            }
        }
        .buttonStyle(.plain)
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
                    .font(.marbleMono(11))
                    .tracking(1)
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
                        .font(.marbleBody(14))
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
            }
        }
    }

    private func unitOption(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.marbleMono(13))
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

    // MARK: - Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "DATA")

            Button {
                showingClearConfirmation = true
            } label: {
                Text("Clear All Data")
                    .font(.marbleMono(13))
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

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACCOUNT")

            // Sign Out
            Button {
                showingSignOutConfirmation = true
            } label: {
                Text("Sign Out")
                    .font(.marbleMono(13))
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out") {
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            }

            // Delete Account
            Button {
                showingDeleteConfirmation = true
            } label: {
                Text("Delete Account")
                    .font(.marbleMono(13))
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await auth.deleteAccount()
                        dismiss()
                    }
                }
            } message: {
                Text("This will permanently delete your account and profile. Your local workout data will remain on this device.")
            }
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
        Task { await CloudSyncService.shared.clearAllCloudData() }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

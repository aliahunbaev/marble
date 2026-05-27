import SwiftUI
import SwiftData

struct YouView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("defaultRestTimer") private var defaultRestTimer: Int = 90
    @AppStorage("appIcon") private var appIcon: String = "light"
    @State private var showingClearConfirmation = false
    @State private var showingSignIn = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var isEditingName = false
    @State private var editedName = ""

    private let restTimerOptions = [30, 60, 90, 120, 180, 300]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    profileSection
                    appIconSection
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

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "PROFILE")

            if auth.isAuthenticated, let profile = auth.userProfile {
                VStack(spacing: 0) {
                    // Name
                    HStack {
                        if isEditingName {
                            TextField("Name", text: $editedName)
                                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                                .foregroundStyle(Color("marblePrimary"))
                                .onSubmit {
                                    Task {
                                        await auth.updateName(editedName)
                                        isEditingName = false
                                    }
                                }
                        } else {
                            Text(profile.name)
                                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                                .foregroundStyle(Color("marblePrimary"))
                        }
                        Spacer()
                        Button(isEditingName ? "Save" : "Edit") {
                            if isEditingName {
                                Task {
                                    await auth.updateName(editedName)
                                    isEditingName = false
                                }
                            } else {
                                editedName = profile.name
                                isEditingName = true
                            }
                        }
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                        .foregroundStyle(Color("marbleSecondary"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if let email = profile.email {
                        Rectangle()
                            .fill(Color("marblePrimary").opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 14)

                        HStack {
                            Text(email)
                                .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                                .foregroundStyle(Color("marbleSecondary"))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                }

                // Sign Out
                Button {
                    showingSignOutConfirmation = true
                } label: {
                    Text("Sign Out")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
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
                    Button("Sign Out") { auth.signOut() }
                    Button("Cancel", role: .cancel) { }
                }

                // Delete Account
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete Account")
                        .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 13).weight(.light))
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
                        Task { await auth.deleteAccount() }
                    }
                } message: {
                    Text("This will permanently delete your account and profile. Your local workout data will remain on this device.")
                }
            } else {
                Button {
                    showingSignIn = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 16, weight: .light))
                        Text("Sign in to save your profile")
                            .font(.custom("ABC Favorit Variable Unlicensed Trial", size: 14).weight(.light))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                    }
                    .foregroundStyle(Color("marblePrimary"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color("marblePrimary").opacity(0.12), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingSignIn) {
                    SignInView()
                        .environmentObject(auth)
                }
            }
        }
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
                    .font(.custom("ABC Favorit Mono Variable Unlicensed Trial", size: 11).weight(.light))
                    .foregroundStyle(isSelected ? Color("marblePrimary") : Color("marbleSecondary"))
                    .tracking(0.5)
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
        Task { await CloudSyncService.shared.clearAllCloudData() }
    }
}

#Preview {
    YouView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

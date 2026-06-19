import SwiftUI
import SwiftData

/// Settings sub-screen — accessed via the gear icon on the You tab.
/// Contains the configurations users rarely revisit: app icon, appearance,
/// preferences, and destructive data actions. Burying these one tap deeper
/// frees the You tab to be an identity surface (profile + workout feed).
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appIcon") private var appIcon: String = "light"

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
        keyWindow?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    /// The foreground key window — used both to read the live system
    /// appearance and to pin it across an app-icon change.
    private var keyWindow: UIWindow? {
        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    appIconSection
                    appearanceSection
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
            // All dialogs attached at the screen root so their
            // full-screen overlay centres on the page. Attaching a
            // marbleDialog to an inner Button sizes the overlay to
            // the button, which made them appear next to the button
            // instead of centred.
            .marbleDialog(
                "Sign out?",
                isPresented: $showingSignOutConfirmation,
                buttons: [
                    .standard("Sign Out") {
                        auth.signOut()
                        dismiss()
                    },
                    .cancel(),
                ]
            )
            .marbleDialog(
                "Delete account?",
                message: "This will permanently delete your account and profile. Your local workout data will remain on this device.",
                isPresented: $showingDeleteConfirmation,
                buttons: [
                    .destructive("Delete") {
                        Task {
                            await auth.deleteAccount()
                            dismiss()
                        }
                    },
                    .cancel(),
                ]
            )
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

            // In "system" appearance the app follows the device via
            // preferredColorScheme(nil). The system alert that
            // setAlternateIconName presents momentarily resets the window
            // to the default (light) appearance, which flashes a
            // dark-mode app to light and back. Pin the window to its
            // current style across the swap, then restore system control.
            let shouldPin = appTheme == "system"
            let window = keyWindow
            if shouldPin, let window {
                window.overrideUserInterfaceStyle = window.traitCollection.userInterfaceStyle
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error {
                        print("Icon change error: \(error)")
                    }
                    if shouldPin, let window {
                        // Hand appearance back to the system once the
                        // alert has dismissed.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            window.overrideUserInterfaceStyle = .unspecified
                        }
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

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACCOUNT")

            // Sign Out — secondary, reversible
            Button {
                showingSignOutConfirmation = true
            } label: {
                Text("SIGN OUT")
                    .marbleSecondaryButton()
            }
            .buttonStyle(.plain)

            // Delete Account — destructive, irreversible
            Button {
                showingDeleteConfirmation = true
            } label: {
                Text("DELETE ACCOUNT")
                    .marbleDestructiveButton()
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

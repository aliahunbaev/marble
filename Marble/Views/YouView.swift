import SwiftUI
import SwiftData

struct YouView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.modelContext) private var modelContext

    @State private var showingSignIn = false
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingSettings = false
    @State private var isEditingName = false
    @State private var editedName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    profileSection
                    GallerySection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color("marbleBackground"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color("marblePrimary"))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
                                .font(.marbleBody(14))
                                .foregroundStyle(Color("marblePrimary"))
                                .onSubmit {
                                    Task {
                                        await auth.updateName(editedName)
                                        isEditingName = false
                                    }
                                }
                        } else {
                            Text(profile.name)
                                .font(.marbleBody(14))
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
                        .font(.marbleMono(11))
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
                                .font(.marbleBody(14))
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
                    Button("Sign Out") { auth.signOut() }
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
                            .font(.marbleBody(14))
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
}

#Preview {
    YouView()
        .modelContainer(for: [Workout.self, Exercise.self, WorkoutTemplate.self], inMemory: true)
}

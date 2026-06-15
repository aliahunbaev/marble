import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthenticationService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: String?

    var isAuthenticated: Bool { user != nil }
    var modelContext: ModelContext?

    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let db = Firestore.firestore()
    private var didSyncForCurrentSession = false

    init() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                if let user {
                    await self?.fetchProfile(for: user.uid)
                    await self?.performInitialSync()
                } else {
                    self?.userProfile = nil
                    self?.didSyncForCurrentSession = false
                }
            }
        }
    }

    private func performInitialSync() async {
        guard !didSyncForCurrentSession, let context = modelContext else { return }
        didSyncForCurrentSession = true
        // Pull cloud data into local
        await CloudSyncService.shared.restoreFromCloud(into: context)
        // Restore photos
        await PhotoStorageService.shared.restoreFromCloud(into: context)
        // Seed Push/Pull/Legs starter templates for a brand-new account.
        // Safe here because restore has finished — if this account had
        // its own templates in the cloud they're already present, so
        // seedIfFreshStart sees a non-empty table and skips. Runs before
        // the push so a genuinely-new account's starters sync up too.
        TemplateSeed.seedIfFreshStart(context: context)
        // Push any local-only data that existed before sign-in
        CloudSyncService.shared.pushAllLocalToCloud(from: context)
        // Retry any photo uploads that were pending
        await PhotoStorageService.shared.retryPendingUploads(context: context)
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Sign in with Apple

    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                self.error = "Failed to get Apple credentials"
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            await signIn(with: credential, fullName: appleCredential.fullName)

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                self.error = error.localizedDescription
            }
        }
    }

    func prepareSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Email Auth

    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createAccount(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let profile = UserProfile(
                id: result.user.uid,
                name: name,
                email: email,
                joinDate: Date()
            )
            try await saveProfile(profile)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            // Clear the locally-cached avatar so the signed-out state
            // doesn't keep showing the previous account's photo. The
            // cloud copy stays and returns on next sign-in.
            PhotoStorageService.shared.clearLocalAvatar()
            // NOTE: we deliberately do NOT wipe local SwiftData here.
            // An earlier version did a bulk context.delete(model:),
            // which deleted child objects (ExerciseLog/WorkoutSet) but
            // left parent Workout shells behind — corrupting the store
            // and making restore skip them (cloudID already present).
            // The app already gates everything behind the sign-in wall
            // when signed out, so lingering local data is never visible;
            // and restoreFromCloud is now "cloud-wins", so it heals any
            // stale/empty local copy on the next sign-in regardless.
            didSyncForCurrentSession = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async {
        guard let user else { return }
        isLoading = true
        do {
            await CloudSyncService.shared.clearAllCloudData()
            try await db.collection("users").document(user.uid).delete()
            try await user.delete()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Profile

    private func fetchProfile(for uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if doc.exists {
                self.userProfile = try doc.data(as: UserProfile.self)
            } else if let user {
                // First sign-in — create profile
                let profile = UserProfile(
                    id: uid,
                    name: user.displayName ?? "Athlete",
                    email: user.email,
                    joinDate: Date()
                )
                try await saveProfile(profile)
            }
        } catch {
            print("Profile fetch error: \(error)")
        }
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        try db.collection("users").document(profile.id).setData(from: profile)
        self.userProfile = profile
    }

    func updateName(_ name: String) async {
        guard var profile = userProfile else { return }
        profile.name = name
        do {
            try await saveProfile(profile)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Private

    private func signIn(with credential: AuthCredential, fullName: PersonNameComponents? = nil) async {
        isLoading = true
        error = nil
        do {
            let result = try await Auth.auth().signIn(with: credential)

            // On first Apple sign-in, create profile with name
            let doc = try await db.collection("users").document(result.user.uid).getDocument()
            if !doc.exists {
                let name = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let profile = UserProfile(
                    id: result.user.uid,
                    name: name.isEmpty ? "Athlete" : name,
                    email: result.user.email,
                    joinDate: Date()
                )
                try await saveProfile(profile)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

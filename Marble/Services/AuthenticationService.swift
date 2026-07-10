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
        // Seed from Firebase's synchronously-cached session so the very
        // first frame already knows the user is signed in. Without this,
        // `user` is nil until the async auth-state listener fires, and
        // ContentView flashes the sign-in wall for a beat on every cold
        // launch. The listener below still runs and does the real work
        // (profile fetch, initial sync) — this only fixes first paint.
        user = Auth.auth().currentUser
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

    /// UserDefaults key recording which account's data lives in the
    /// local store. The device belongs to exactly one account at a time.
    private static let localDataOwnerKey = "Marble.localDataOwnerUID"

    private func performInitialSync() async {
        guard !didSyncForCurrentSession, let context = modelContext,
              let uid = user?.uid else { return }
        didSyncForCurrentSession = true

        // Account isolation: if the local store belongs to a DIFFERENT
        // account, wipe it before restoring — an account switch behaves
        // like a fresh device. Same-account re-sign-in keeps local data
        // (instant + offline-friendly; restore heals it below). This is
        // what prevents one account's data from ever being shown to —
        // or pushed into the cloud of — another.
        let defaults = UserDefaults.standard
        let owner = defaults.string(forKey: Self.localDataOwnerKey)
        if let owner, owner != uid {
            LocalDataReset.wipe(context: context)
        }
        defaults.set(uid, forKey: Self.localDataOwnerKey)

        // Pull cloud data into local
        await CloudSyncService.shared.restoreFromCloud(into: context)
        // Restore photos
        await PhotoStorageService.shared.restoreFromCloud(into: context)
        // Seed Push/Pull/Legs starter templates for a brand-new account.
        // Safe here because restore has finished — if this account had
        // its own templates in the cloud they're already present, so
        // seedIfFreshStart sees a non-empty table and skips.
        TemplateSeed.seedIfFreshStart(context: context)
        // NOTE: there is deliberately no "push all local to cloud" step
        // anymore. It existed to migrate pre-account local data, but
        // accounts are required now, every mutation uploads at action
        // time (Firestore writes queue offline automatically) — and on
        // an account switch it was the leak that copied the previous
        // account's data into the new account's cloud.
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
            // NOTE: we intentionally KEEP the cached avatar (and all
            // local data) on sign-out. Accounts are required, so a
            // signed-out user only ever sees the sign-in wall — the
            // previous avatar is never visible. Keeping it cached means
            // signing back into the same account shows the photo
            // instantly instead of waiting on a cloud re-download.
            // restoreAvatarFromCloud still corrects it on the rare
            // case of a different account signing in on this device.
            // We deliberately do NOT wipe local SwiftData here either.
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
        error = nil
        do {
            try await performAccountDeletion(user)
        } catch {
            // Firebase refuses to delete an account on a stale session —
            // it requires a recent login. Reauthenticate, then retry.
            if (error as NSError).code == AuthErrorCode.requiresRecentLogin.rawValue {
                do {
                    try await reauthenticate(user)
                    try await performAccountDeletion(user)
                } catch {
                    self.error = (error as NSError).localizedDescription
                }
            } else {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func performAccountDeletion(_ user: FirebaseAuth.User) async throws {
        await CloudSyncService.shared.clearAllCloudData()
        try await db.collection("users").document(user.uid).delete()
        try await user.delete()
    }

    /// Reauthenticate the user so a sensitive op (account deletion) can
    /// proceed. Apple accounts re-run Sign in with Apple silently; other
    /// providers fall back to an instructive message (the user can sign
    /// out and back in, which refreshes the session).
    private func reauthenticate(_ user: FirebaseAuth.User) async throws {
        let providerID = user.providerData.first?.providerID ?? ""
        switch providerID {
        case "apple.com":
            let credential = try await freshAppleCredential()
            try await user.reauthenticate(with: credential)
        default:
            throw NSError(
                domain: "Marble",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey:
                    "For your security, sign out and sign back in, then delete your account."]
            )
        }
    }

    /// Drive a fresh Sign in with Apple programmatically and return a
    /// Firebase credential for reauthentication.
    private func freshAppleCredential() async throws -> AuthCredential {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let authorization = try await AppleAuthBroker.shared.perform(request: request)
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw NSError(
                domain: "Marble",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't verify your Apple ID."]
            )
        }
        return OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
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

// MARK: - Apple authorization async bridge

/// Bridges a one-shot ASAuthorizationController flow to async/await, used
/// for reauthentication (account deletion). The SwiftUI SignInWithApple
/// button handles the normal sign-in; this drives the same flow
/// programmatically when we need a fresh credential mid-session.
private final class AppleAuthBroker: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    static let shared = AppleAuthBroker()

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    func perform(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        continuation?.resume(returning: authorization)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

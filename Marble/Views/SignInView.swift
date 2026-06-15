import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthenticationService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isEmailMode = false
    @State private var isCreateAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Wordmark — the brand set in title case, matching the app's
            // logo treatment rather than the mono all-caps used for
            // chrome labels.
            Text("Marble")
                .font(.marbleBody(40))
                .foregroundStyle(Color("marblePrimary"))

            Spacer()
                .frame(height: 40)

            if isEmailMode {
                emailForm
            } else {
                signInButtons
            }

            Spacer()
                .frame(height: 24)

            if let error = auth.error {
                Text(error)
                    .font(.marbleBody(13))
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .marbleAtmosphereBackground()
        // Close affordance — this view is presented as a full-screen
        // cover from the You tab, so it needs an explicit dismiss.
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.top, 8)
        }
        // Dismiss automatically the moment auth succeeds. Without this
        // the sign-in surface stayed up on top of the now-signed-in app.
        // In the onboarding NavigationLink context this simply pops back
        // to the account step, which then shows its signed-in state.
        .onChange(of: auth.isAuthenticated) { _, isAuthed in
            if isAuthed { dismiss() }
        }
    }

    // MARK: - Sign In Buttons

    private var signInButtons: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.signIn) { request in
                let nonce = auth.prepareSignInWithApple()
                request.requestedScopes = [.fullName, .email]
                request.nonce = nonce
            } onCompletion: { result in
                Task { await auth.handleSignInWithApple(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isEmailMode = true
                }
            } label: {
                Text("Continue with email")
                    .font(.marbleBody(15, weight: .regular))
                    .foregroundStyle(Color("marblePrimary"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color("marbleCard"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("marbleTertiary"), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Email Form

    private var emailForm: some View {
        VStack(spacing: 14) {
            if isCreateAccount {
                TextField("Name", text: $name)
                    .textFieldStyle(MarbleTextFieldStyle())
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            TextField("Email", text: $email)
                .textFieldStyle(MarbleTextFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .textFieldStyle(MarbleTextFieldStyle())
                .textContentType(isCreateAccount ? .newPassword : .password)

            Button {
                Task {
                    if isCreateAccount {
                        await auth.createAccount(email: email, password: password, name: name)
                    } else {
                        await auth.signIn(email: email, password: password)
                    }
                }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView()
                            .tint(Color("marbleBackground"))
                    } else {
                        Text(isCreateAccount ? "Create Account" : "Sign In")
                            .font(.marbleBody(15, weight: .regular))
                    }
                }
                .foregroundStyle(Color("marbleBackground"))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color("marblePrimary"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(email.isEmpty || password.isEmpty || (isCreateAccount && name.isEmpty))
            .opacity(email.isEmpty || password.isEmpty || (isCreateAccount && name.isEmpty) ? 0.5 : 1)

            HStack(spacing: 4) {
                Text(isCreateAccount ? "Have an account?" : "No account?")
                    .font(.marbleBody(13))
                    .foregroundStyle(Color("marbleSecondary"))

                Button(isCreateAccount ? "Sign in" : "Create one") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCreateAccount.toggle()
                        auth.error = nil
                    }
                }
                .font(.marbleBody(13, weight: .regular))
                .foregroundStyle(Color("marblePrimary"))
            }

            Button("Back") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isEmailMode = false
                    auth.error = nil
                }
            }
            .font(.marbleBody(13))
            .foregroundStyle(Color("marbleSecondary"))
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Text Field Style

struct MarbleTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.marbleBody(15))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color("marbleFieldBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

import SwiftUI

struct OnboardingFlow: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var savedName: String = ""
    @EnvironmentObject private var auth: AuthenticationService

    @State private var step: Int = 0
    @State private var name: String = ""

    private let totalSteps = 5

    var body: some View {
        ZStack {
            backgroundForStep
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: step)

            Group {
                switch step {
                case 0: revealScreen
                case 1: thesisScreen
                case 2: premiseScreen
                case 3: nameScreen
                case 4: accountScreen
                default: revealScreen
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundForStep: some View {
        switch step {
        case 0, 1, 2:
            // Dark, philosophical screens
            ZStack {
                Color.black
                RadialGradient(
                    colors: [
                        Color(red: 0.18, green: 0.14, blue: 0.10).opacity(0.6),
                        Color.black.opacity(0)
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 700
                )
            }
        default:
            // Warm bone — the brand shift
            Color("marbleBackground")
        }
    }

    // MARK: - Screen 1 — The Reveal

    @State private var revealOpacity: Double = 0
    @State private var revealTracking: CGFloat = 24

    private var revealScreen: some View {
        VStack {
            Spacer()

            Text("MARBLE")
                .font(.marbleBody(22))
                .tracking(revealTracking)
                .foregroundStyle(.white)
                .opacity(revealOpacity)

            Spacer()

            Text("TAP TO CONTINUE")
                .font(.marbleMono(10))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.3))
                .opacity(revealOpacity)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) {
                revealOpacity = 1
                revealTracking = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    // MARK: - Screen 2 — The Thesis

    private var thesisScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                Text("Man cannot remake himself\nwithout suffering, for he is\nboth the marble and the sculptor.")
                    .font(.marbleBody(22))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 32)

                Text("— ALEXIS CARREL")
                    .font(.marbleMono(11))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .transition(.opacity)

            Spacer()

            continueButton(label: "CONTINUE", emphasized: false, lightOnDark: true)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 3 — The Premise

    private var premiseScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Text("This is your record.")
                    .font(.marbleBody(28))
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text("No coaches. No notifications. No noise.")
                    Text("Just the work, and what you make of it.")
                }
                .font(.marbleBody(15))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()

            continueButton(label: "CONTINUE", emphasized: false, lightOnDark: true)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 4 — The Name

    @FocusState private var nameFieldFocused: Bool

    private var nameScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Text("What should we call you?")
                    .font(.marbleBody(22))
                    .foregroundStyle(Color("marblePrimary"))

                TextField("", text: $name)
                    .font(.marbleBody(28))
                    .foregroundStyle(Color("marblePrimary"))
                    .multilineTextAlignment(.center)
                    .focused($nameFieldFocused)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .onSubmit {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            advance()
                        }
                    }

                Rectangle()
                    .fill(Color("marblePrimary").opacity(0.2))
                    .frame(height: 0.5)
                    .padding(.horizontal, 40)
            }

            Spacer()

            continueButton(label: "CONTINUE", emphasized: true, lightOnDark: false)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.bottom, 40)
        }
        .onAppear {
            // Pre-fill with existing name if available
            if name.isEmpty {
                if let profile = auth.userProfile {
                    name = profile.name
                } else if !savedName.isEmpty {
                    name = savedName
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFieldFocused = true
            }
        }
    }

    // MARK: - Screen 5 — The Account

    private var accountScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("Save your work.")
                    .font(.marbleBody(22))
                    .foregroundStyle(Color("marblePrimary"))

                Text("So your record is yours, forever.")
                    .font(.marbleBody(14))
                    .foregroundStyle(Color("marbleSecondary"))
            }

            Spacer()

            VStack(spacing: 12) {
                if auth.isAuthenticated {
                    // Already signed in — show confirmation
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .light))
                        Text("SIGNED IN")
                            .font(.marbleMono(11, weight: .medium))
                            .tracking(2)
                    }
                    .foregroundStyle(Color("marbleSecondary"))
                    .padding(.vertical, 12)

                    continueButton(label: "BEGIN", emphasized: true, lightOnDark: false)
                } else {
                    NavigationLink {
                        SignInView()
                            .environmentObject(auth)
                    } label: {
                        Text("Sign in")
                            .font(.marbleBody(15, weight: .regular))
                            .foregroundStyle(Color("marbleBackground"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("marblePrimary"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)

                    Button {
                        finishOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(.marbleBody(14))
                            .foregroundStyle(Color("marbleSecondary"))
                            .padding(.vertical, 12)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func continueButton(label: String, emphasized: Bool, lightOnDark: Bool) -> some View {
        Button {
            advance()
        } label: {
            Text(label)
                .font(.marbleMono(12, weight: .medium))
                .tracking(2)
                .foregroundStyle(buttonForeground(emphasized: emphasized, lightOnDark: lightOnDark))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonBackground(emphasized: emphasized, lightOnDark: lightOnDark))
                .overlay(buttonBorder(emphasized: emphasized, lightOnDark: lightOnDark))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
    }

    private func buttonForeground(emphasized: Bool, lightOnDark: Bool) -> Color {
        if emphasized {
            return lightOnDark ? .black : Color("marbleBackground")
        }
        return lightOnDark ? .white : Color("marblePrimary")
    }

    private func buttonBackground(emphasized: Bool, lightOnDark: Bool) -> Color {
        if emphasized {
            return lightOnDark ? .white : Color("marblePrimary")
        }
        return .clear
    }

    private func buttonBorder(emphasized: Bool, lightOnDark: Bool) -> some View {
        Capsule()
            .stroke(
                emphasized ? Color.clear :
                    (lightOnDark ? Color.white.opacity(0.4) : Color("marblePrimary").opacity(0.3)),
                lineWidth: 0.5
            )
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.5)) {
                step += 1
            }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            savedName = trimmed
            if auth.isAuthenticated {
                Task { await auth.updateName(trimmed) }
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
    }
}

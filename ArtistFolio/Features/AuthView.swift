// MARK: - Auth Views (Landing, Create Account, Sign In)
// Matches Figma: Landing (30:2818), Create Account (30:2859), Sign In (30:2931)
import SwiftUI

// MARK: - Landing View

struct LandingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                // Simulated dark oil-painting background
                LinearGradient(
                    colors: [Color(hex: "#1B3A4B"), Color(hex: "#2D4A5A"), Color(hex: "#1A2535"), Color(hex: "#0D1B2A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Logo
                    ZStack {
                        Circle().fill(.white.opacity(0.08)).frame(width: 96, height: 96)
                        VStack(spacing: 1) {
                            Image(systemName: "rectangle.portrait.fill")
                                .font(.system(size: 30, weight: .regular)).foregroundColor(.white)
                            HStack(spacing: 0) {
                                Text("artist").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                Text("folio").font(.system(size: 13, weight: .light)).foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.bottom, 72)

                    // Tagline
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Where art\nfinds its home.")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white).lineSpacing(4)
                        Text("Buy and sell original paintings directly between artists and collectors, worldwide.")
                            .font(.system(size: 15)).foregroundColor(.white.opacity(0.72)).lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AFSpacing.xl).padding(.bottom, AFSpacing.xl)

                    // Buttons
                    VStack(spacing: 12) {
                        NavigationLink(destination: CreateAccountView()) {
                            HStack {
                                Text("Get Started").font(.system(size: 17, weight: .semibold))
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 55)
                            .background(Color.afPrimary).clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())

                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                                .font(.system(size: 17, weight: .medium)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).frame(height: 58)
                                .background(.white.opacity(0.12)).clipShape(Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 1.5))
                        }
                        .buttonStyle(PlainButtonStyle())

                        HStack(spacing: 12) {
                            Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
                            Text("OR CONTINUE WITH")
                                .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.55))
                                .tracking(0.72).fixedSize()
                            Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            Button {} label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "apple.logo").font(.system(size: 16))
                                    Text("Apple").font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.afTextPrimary)
                                .frame(maxWidth: .infinity).frame(height: 51)
                                .background(Color.white).clipShape(Capsule())
                            }

                            Button {} label: {
                                HStack(spacing: 8) {
                                    Text("G").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "#4285F4"))
                                    Text("Google").font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity).frame(height: 51)
                                .background(.white.opacity(0.12)).clipShape(Capsule())
                                .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1.5))
                            }
                        }
                    }
                    .padding(.horizontal, AFSpacing.xl).padding(.bottom, 44)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Create Account View

struct CreateAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole = .collector
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                HStack { Spacer(); LogoSmall(); Spacer() }.padding(.top, AFSpacing.md)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Create Account").font(.system(size: 28, weight: .bold)).foregroundColor(.afTextPrimary)
                    Text("Join thousands of artists and collectors").font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                HStack(spacing: 0) {
                    RolePill(role: .collector, label: "I'm a Collector", isSelected: selectedRole == .collector) { selectedRole = .collector }
                    RolePill(role: .artist, label: "I'm an Artist", isSelected: selectedRole == .artist) { selectedRole = .artist }
                }
                .background(Color.afSurface2).clipShape(Capsule())
                .overlay(Capsule().stroke(Color.afBorder, lineWidth: 1))

                FormField(label: "FULL NAME", placeholder: "Your name", text: $fullName)
                FormField(label: "EMAIL", placeholder: "your@email.com", text: $email, keyboardType: .emailAddress)
                SecureFormField(label: "PASSWORD", placeholder: "Min. 8 characters", text: $password, showPassword: $showPassword)

                SocialLoginSection()

                (Text("By creating an account you agree to our ").font(AFFont.caption).foregroundColor(.afTextSecondary)
                 + Text("Terms of Service").font(AFFont.captionBold).foregroundColor(.afPrimary)
                 + Text(" and ").font(AFFont.caption).foregroundColor(.afTextSecondary)
                 + Text("Privacy Policy").font(AFFont.captionBold).foregroundColor(.afPrimary)
                 + Text(".").font(AFFont.caption).foregroundColor(.afTextSecondary))

                Button {
                    Task { await createAccount() }
                } label: {
                    if isLoading { ProgressView().tint(.white) } else { Text("Create Account") }
                }
                .buttonStyle(AFPrimaryButtonStyle())
                .disabled(fullName.isEmpty || email.isEmpty || password.count < 8)

                HStack {
                    Spacer()
                    Text("Already have an account?").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    NavigationLink("Sign In") { SignInView() }.font(AFFont.headlineSmall).foregroundColor(.afPrimary)
                    Spacer()
                }
            }
            .padding(.horizontal, AFSpacing.lg).padding(.bottom, AFSpacing.xxl)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.afTextPrimary) }
            }
        }
    }

    private func createAccount() async {
        isLoading = true; defer { isLoading = false }
        try? await appState.authService.signUpWithEmail(email: email, password: password, displayName: fullName, role: selectedRole)
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                HStack { Spacer(); LogoSmall(); Spacer() }.padding(.top, AFSpacing.md)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back").font(.system(size: 28, weight: .bold)).foregroundColor(.afTextPrimary)
                    Text("Sign in to continue to Artist Folio").font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                }

                FormField(label: "EMAIL", placeholder: "your@email.com", text: $email, keyboardType: .emailAddress)
                SecureFormField(label: "PASSWORD", placeholder: "Your password", text: $password, showPassword: $showPassword)

                Button("Forgot password?") {}
                    .font(AFFont.headlineSmall).foregroundColor(.afPrimary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                SocialLoginSection()

                Button {
                    Task { await signIn() }
                } label: {
                    if isLoading { ProgressView().tint(.white) } else { Text("Sign In") }
                }
                .buttonStyle(AFPrimaryButtonStyle())
                .disabled(email.isEmpty || password.count < 6)

                HStack {
                    Spacer()
                    Text("Don't have an account?").font(AFFont.bodySmall).foregroundColor(.afTextSecondary)
                    NavigationLink("Sign Up") { CreateAccountView() }.font(AFFont.headlineSmall).foregroundColor(.afPrimary)
                    Spacer()
                }
            }
            .padding(.horizontal, AFSpacing.lg).padding(.bottom, AFSpacing.xxl)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.afTextPrimary) }
            }
        }
    }

    private func signIn() async {
        isLoading = true; defer { isLoading = false }
        try? await appState.authService.signInWithEmail(email: email, password: password)
    }
}

// MARK: - Reusable Auth Components

struct LogoSmall: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.portrait.fill").font(.system(size: 14)).foregroundColor(.afPrimary)
            HStack(spacing: 0) {
                Text("artist").font(.system(size: 16, weight: .bold)).foregroundColor(.afTextPrimary)
                Text("folio").font(.system(size: 16, weight: .light)).foregroundColor(.afTextSecondary)
            }
        }
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(label).font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
            TextField(placeholder, text: $text)
                .font(AFFont.bodyLarge).keyboardType(keyboardType)
                .autocapitalization(.none).disableAutocorrection(true)
                .padding(.horizontal, AFSpacing.md).frame(height: 50)
                .background(Color.afSurface2)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
        }
    }
}

struct SecureFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(label).font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
            HStack {
                if showPassword { TextField(placeholder, text: $text).font(AFFont.bodyLarge) }
                else { SecureField(placeholder, text: $text).font(AFFont.bodyLarge) }
                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye").foregroundColor(.afTextTertiary)
                }
            }
            .padding(.horizontal, AFSpacing.md).frame(height: 50)
            .background(Color.afSurface2)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
        }
    }
}

struct RolePill: View {
    let role: UserRole
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label).font(AFFont.headlineSmall)
                .foregroundColor(isSelected ? .white : .afTextSecondary)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(isSelected ? Color.afPrimary : Color.clear)
                .clipShape(Capsule())
        }
    }
}

struct SocialLoginSection: View {
    var body: some View {
        VStack(spacing: AFSpacing.md) {
            HStack {
                Rectangle().fill(Color.afBorder).frame(height: 0.5)
                Text("OR CONTINUE WITH").font(AFFont.labelSmall).foregroundColor(.afTextTertiary).fixedSize()
                Rectangle().fill(Color.afBorder).frame(height: 0.5)
            }
            HStack(spacing: 12) {
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo").font(.system(size: 16))
                        Text("Apple").font(AFFont.headlineSmall)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 48)
                    .background(Color.black).clipShape(Capsule())
                }
                Button {} label: {
                    HStack(spacing: 8) {
                        Text("G").font(.system(size: 16, weight: .bold)).foregroundColor(Color(hex: "#4285F4"))
                        Text("Google").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                    }
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Color.white).clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.afBorder, lineWidth: 1))
                }
            }
        }
    }
}

// Legacy alias kept for compatibility
struct SocialButton: View {
    let icon: String; let label: String
    enum SocialStyle { case dark, light, transparent }
    var style: SocialStyle = .dark

    var body: some View {
        Button {} label: {
            HStack(spacing: 8) { Image(systemName: icon); Text(label) }
                .font(AFFont.headlineSmall)
                .foregroundColor(style == .light ? .afTextPrimary : .white)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(style == .light ? Color.white : style == .dark ? Color.black : .white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(style == .transparent ? .white.opacity(0.3) : .clear, lineWidth: 1))
        }
    }
}

#Preview { LandingView().environmentObject(AppState()) }

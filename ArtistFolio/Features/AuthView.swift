import SwiftUI

struct LegalView: View {
    var body: some View {
        List {
            section("Community Terms", "By publishing on Artist Folio, you confirm that you own or have the rights to your work. There is no tolerance for objectionable content or abusive users, including sexual exploitation, hate, harassment, threats, scams, or stolen work.")
            section("Moderation", "Anyone can report an artwork or artist and block an artist. We review reports and may remove content that breaks these terms.")
            section("Purchases", "Artist Folio does not process payments, shipping, or returns. Any transaction is arranged directly between the artist and the collector, at their own risk.")
            section("Privacy", "Your profile, artworks, and any contact details you choose to add are public. Saved art, followed artists, and blocked artists stay in your private iCloud database. Artist Folio does not track you or sell your data.")
            section("Deleting Your Account", "You can delete your account from Profile at any time. This permanently removes your profile, artworks, and private library. Reports you submitted may be retained for safety review.")
        }
        .navigationTitle("Terms & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        Section(title) {
            Text(body).font(.subheadline)
        }
    }
}

struct CreateAccountView: View {
    @EnvironmentObject var appState: AppState
    @Binding var path: [AuthRoute]
    @State private var role: UserRole = .collector
    @State private var name = ""
    @State private var email = ""
    @State private var acceptedTerms = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var validationMessage: String? {
        if name.trimmed.isEmpty { return "Add your name." }
        if role == .artist, ContactLinks.mailURL(email) == nil { return "Add a valid email so collectors can reach you." }
        if !acceptedTerms { return "Accept the terms to continue." }
        return nil
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: AFSpacing.sm) {
                    BrandLogo(height: 56)
                    Text("Create Account").font(.title2.bold())
                    Text("Join artists and collectors").font(.subheadline).foregroundStyle(Color.afTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("I am a", selection: $role.animation()) {
                    Text("I'm a Collector").tag(UserRole.collector)
                    Text("I'm an Artist").tag(UserRole.artist)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                TextField("Full Name", text: $name)
                    .textContentType(.name)
                if role == .artist {
                    TextField("Contact Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } footer: {
                if role == .artist { Text("Your contact email is public so collectors can reach you.") }
            }

            Section {
                NavigationLink("Terms & Privacy") { LegalView() }
                Toggle("I Agree to the Terms", isOn: $acceptedTerms)
            } footer: {
                if let message = errorMessage ?? validationMessage {
                    Text(message).foregroundStyle(errorMessage == nil ? Color.afTextSecondary : Color.red)
                }
            }

            Section {
                VStack(spacing: AFSpacing.xxs) {
                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if isWorking { ProgressView() } else { Label("Continue with iCloud", systemImage: "icloud.fill") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .primaryAction()
                    .disabled(validationMessage != nil || isWorking)

                    Button("Already have an account? Sign In") { path = [.signIn] }
                        .buttonStyle(.borderless)
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await appState.createAccount(displayName: name.trimmed, role: role, contactEmail: email.trimmed)
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }
}

struct SignInView: View {
    @EnvironmentObject var appState: AppState
    @Binding var path: [AuthRoute]
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: AFSpacing.xl) {
                BrandLogo(height: 56)
                VStack(spacing: AFSpacing.xxs) {
                    Text("Welcome back").font(.title2.bold())
                    Text("Sign in to continue to Artist Folio").font(.subheadline).foregroundStyle(Color.afTextSecondary)
                }
                FeatureRow(icon: "icloud", title: "Your iCloud Is Your Account", detail: "No password to remember. We use the iCloud account on this device.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AFSpacing.md)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                if let message {
                    Text(message).font(.footnote).foregroundStyle(Color.afTextSecondary).multilineTextAlignment(.center)
                }
            }
            .padding(AFSpacing.lg)
        }
        .navigationBarTitleDisplayMode(.inline)
        .afBottomBar {
            VStack(spacing: AFSpacing.xxs) {
                Button {
                    Task { await signIn() }
                } label: {
                    Group {
                        if isWorking { ProgressView() } else { Label("Continue with iCloud", systemImage: "icloud.fill") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryAction()
                .disabled(isWorking)

                Button("Don't have an account? Sign Up") { path = [.createAccount] }
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, AFSpacing.lg)
            .padding(.top, AFSpacing.xs)
        }
    }

    private func signIn() async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        switch await appState.continueWithICloud() {
        case .needsProfile: message = "No profile found for this iCloud account. Sign up to create one."
        case .unavailable: message = AppError.accountUnavailable.errorDescription
        case .entered, .noICloud: break
        }
    }
}

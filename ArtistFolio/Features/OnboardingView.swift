import SwiftUI

enum AuthRoute: Hashable {
    case createAccount, signIn
}

struct OnboardingRootView: View {
    @State private var showLanding = false
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if showLanding {
                    LandingView(path: $path).transition(.opacity)
                } else {
                    OnboardingPagesView { withAnimation(.smooth) { showLanding = true } }
                        .transition(.opacity)
                }
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .createAccount: CreateAccountView(path: $path)
                case .signIn: SignInView(path: $path)
                }
            }
        }
    }
}

private struct OnboardingPage: Identifiable {
    let id: Int
    let image: String
    let title: String
    let detail: String
}

private struct OnboardingPagesView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(id: 0, image: "OnboardingArtist", title: "Your Art, Your Gallery", detail: "Artist Folio is a home for original art. Build your portfolio and reach collectors worldwide."),
        OnboardingPage(id: 1, image: "OnboardingGallery", title: "No Middlemen, No Limits", detail: "Connect directly with collectors anywhere in the world. No galleries or agents required."),
        OnboardingPage(id: 2, image: "OnboardingApp", title: "Safe, Simple, Beautiful", detail: "Report and block tools, private saved art, and a beautiful experience for art lovers on both sides.")
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: AFSpacing.md) {
            TabView(selection: $page.animation()) {
                ForEach(pages) { item in
                    ScrollView {
                        VStack(spacing: AFSpacing.lg) {
                            Image(item.image)
                                .resizable()
                                .scaledToFit()
                                .grayscale(1)
                                .frame(maxHeight: 320)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: AFRadius.lg, style: .continuous))
                                .accessibilityHidden(true)
                            Text(item.title)
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            Text(item.detail)
                                .font(.body)
                                .foregroundStyle(Color.afTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, AFSpacing.xl)
                        .padding(.top, AFSpacing.xxl)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 6) {
                ForEach(pages) { item in
                    Capsule()
                        .fill(item.id == page ? Color.afPrimary : Color(uiColor: .systemGray4))
                        .frame(width: item.id == page ? 24 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(page + 1) of \(pages.count)")

            VStack(spacing: AFSpacing.xxs) {
                Button {
                    if isLast { onFinish() } else { withAnimation { page += 1 } }
                } label: {
                    Text(isLast ? "Get Started" : "Continue").frame(maxWidth: .infinity)
                }
                .primaryAction()

                Button("Skip", action: onFinish)
                    .font(.subheadline)
                    .foregroundStyle(Color.afTextSecondary)
                    .frame(minHeight: 44)
                    .opacity(isLast ? 0 : 1)
                    .disabled(isLast)
            }
            .padding(.horizontal, AFSpacing.xl)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct LandingView: View {
    @EnvironmentObject var appState: AppState
    @Binding var path: [AuthRoute]
    @State private var showDemoOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.md) {
            HStack {
                Spacer()
                BrandLogo(height: 104)
            }
            .padding(.top, AFSpacing.xxl)

            Spacer()

            VStack(alignment: .leading, spacing: AFSpacing.xs) {
                Text("Where art\nfinds its home.").font(.title.bold())
                Text("Discover original paintings and connect directly with the artists who make them.")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(spacing: AFSpacing.sm) {
                Button { path = [.createAccount] } label: {
                    Label("Get Started", systemImage: "chevron.forward")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .primaryAction()

                Button { path = [.signIn] } label: {
                    Text("Sign In").frame(maxWidth: .infinity)
                }
                .secondaryAction()

                HStack(spacing: AFSpacing.lg) {
                    Button("Browse as Guest") { appState.enterApp(createProfile: false) }
                    Button("Explore Demo") { withAnimation(.smooth) { showDemoOptions.toggle() } }
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)

                if showDemoOptions {
                    Text("Try every feature with sample content. No iCloud account is needed, and nothing is saved.")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: AFSpacing.sm) {
                        Button { Task { await appState.startDemo(as: .artist) } } label: {
                            Text("Artist Demo").frame(maxWidth: .infinity)
                        }
                        .secondaryAction()
                        Button { Task { await appState.startDemo(as: .collector) } } label: {
                            Text("Collector Demo").frame(maxWidth: .infinity)
                        }
                        .secondaryAction()
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AFSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [Color(white: 0.2), Color(white: 0.08), .black],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AFSpacing.xs) {
            configuration.title
            configuration.icon.font(.footnote.weight(.semibold))
        }
    }
}

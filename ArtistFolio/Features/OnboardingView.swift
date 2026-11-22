import SwiftUI

struct OnboardingRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xxl) {
                VStack(spacing: AFSpacing.sm) {
                    Image(systemName: "photo.artframe")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Welcome to Artist Folio")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AFSpacing.xxl)

                VStack(alignment: .leading, spacing: AFSpacing.xl) {
                    FeatureRow(icon: "paintbrush.pointed", title: "Your Art, Your Gallery", detail: "Build a portfolio and reach collectors worldwide.")
                    FeatureRow(icon: "safari", title: "Discover Original Work", detail: "Browse by style and medium, and save pieces you love.")
                    FeatureRow(icon: "person.2", title: "Connect Directly", detail: "Reach artists by email, Instagram, or their website.")
                }
                .padding(.horizontal, AFSpacing.xs)
            }
            .padding(.horizontal, AFSpacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: AFSpacing.sm) {
                Text("iCloud keeps your profile secure. No password needed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button { appState.enterApp(createProfile: false) } label: {
                    Text("Browse Art").frame(maxWidth: .infinity)
                }
                .primaryAction()
                Button { appState.enterApp(createProfile: true) } label: {
                    Text("Create Profile").frame(maxWidth: .infinity)
                }
                .secondaryAction()
            }
            .padding(.horizontal, AFSpacing.xl)
            .padding(.vertical, AFSpacing.sm)
            .background(.bar)
        }
    }
}

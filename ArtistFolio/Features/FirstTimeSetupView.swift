import SwiftUI

struct FirstTimeSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.xxl) {
                Text(appState.isArtist ? "Welcome, Artist" : "Welcome, Collector")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, AFSpacing.xxl)

                VStack(alignment: .leading, spacing: AFSpacing.xl) {
                    if appState.isArtist {
                        FeatureRow(icon: "photo.badge.plus", title: "Add Your Work", detail: "Upload photos from your library to reach collectors.")
                        FeatureRow(icon: "pencil.and.ruler", title: "Open to Commissions", detail: "Turn this on in Edit Profile so collectors know to contact you.")
                        FeatureRow(icon: "paintpalette", title: "Manage Your Studio", detail: "Edit listings and mark pieces as sold.")
                    } else {
                        FeatureRow(icon: "safari", title: "Discover Art", detail: "Browse original work by style and medium.")
                        FeatureRow(icon: "heart", title: "Save Favorites", detail: "Keep pieces you love in one private place.")
                        FeatureRow(icon: "person.badge.plus", title: "Follow Artists", detail: "See their new work on Home.")
                    }
                }
                .padding(.horizontal, AFSpacing.xs)
            }
            .padding(.horizontal, AFSpacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if appState.isArtist { appState.selectedTab = .studio }
                dismiss()
            } label: {
                Text(appState.isArtist ? "Go to Studio" : "Start Discovering").frame(maxWidth: .infinity)
            }
            .primaryAction()
            .padding(.horizontal, AFSpacing.xl)
            .padding(.vertical, AFSpacing.sm)
            .background(.bar)
        }
    }
}

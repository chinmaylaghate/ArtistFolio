import SwiftUI

struct LandingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1B3A4B"), Color(hex: "#2D4A5A"), Color(hex: "#1A2535"), Color(hex: "#0D1B2A")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.08)).frame(width: 96, height: 96)
                    VStack(spacing: 1) {
                        Image(systemName: "rectangle.portrait.fill")
                            .font(.system(size: 30)).foregroundColor(.white)
                        HStack(spacing: 0) {
                            Text("artist").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                            Text("folio").font(.system(size: 13, weight: .light)).foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Artist Folio")
                .padding(.bottom, 72)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Where art\nfinds its home.")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                    Text("Discover original art and connect directly with the artists who make it.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.78))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AFSpacing.xl)
                .padding(.bottom, AFSpacing.xl)

                VStack(spacing: 12) {
                    Button { appState.enterApp(createProfile: false) } label: {
                        HStack {
                            Text("Browse Art")
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(AFPrimaryButtonStyle())

                    Button("Create Profile") { appState.enterApp(createProfile: true) }
                        .buttonStyle(AFSecondaryButtonStyle())

                    Text("Your iCloud account keeps your profile secure. No password needed.")
                        .font(AFFont.caption)
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.top, AFSpacing.xxs)
                }
                .padding(.horizontal, AFSpacing.xl)
                .padding(.bottom, 44)
            }
        }
    }
}

struct LegalView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                section("Community Terms", "By publishing on Artist Folio, you confirm that you own or have the rights to your work. There is no tolerance for objectionable content or abusive users, including sexual exploitation, hate, harassment, threats, scams, or stolen work.")
                section("Moderation", "Anyone can report an artwork or artist and block an artist. Reports are reviewed within 24 hours. Violating content is removed and repeat offenders lose access.")
                section("Purchases", "Artist Folio does not process payments, shipping, or returns. Any transaction is arranged directly between the artist and the collector, at their own risk.")
                section("Privacy", "Your profile, artworks, and any contact details you choose to add are public. Saved art, followed artists, and blocked artists stay in your private iCloud database. Artist Folio does not track you or sell your data.")
                section("Deleting Your Account", "You can delete your account from Profile at any time. This permanently removes your profile, artworks, and private library. Reports you submitted may be retained for safety review.")
            }
            .padding(AFSpacing.lg)
            .padding(.bottom, 100)
        }
        .background(Color.afBackground)
        .navigationTitle("Terms & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(title).font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            Text(body).font(AFFont.bodyMedium).foregroundColor(.afTextSecondary).lineSpacing(4)
        }
    }
}

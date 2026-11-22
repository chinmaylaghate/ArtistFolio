// MARK: - Splash Screen
// Matches Figma: Artist_Folio_Splash 4 (logo center)
import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: AFSpacing.xs) {
                // Logo — matches Figma "ArtistFolio_Logo" frame
                ZStack {
                    Circle()
                        .fill(Color.afPrimary.opacity(0.08))
                        .frame(width: 120, height: 120)
                    VStack(spacing: 2) {
                        Image(systemName: "rectangle.portrait.fill")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundColor(.afPrimary)
                        HStack(spacing: 0) {
                            Text("artist")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.afTextPrimary)
                            Text("folio")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.afTextSecondary)
                        }
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Text("Where Art Finds Its Home")
                    .font(AFFont.caption)
                    .foregroundColor(.afTextTertiary)
                    .opacity(taglineOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.7)) {
                taglineOpacity = 1.0
            }
        }
    }
}

#Preview { SplashView() }

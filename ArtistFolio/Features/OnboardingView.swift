// MARK: - Onboarding Flow
// Matches Figma: Artist_Folio_Splash 5/6/7 (30:2766..30:2802)
import SwiftUI

struct OnboardingRootView: View {
    @State private var currentPage: Int = 0
    @State private var showLanding: Bool = false

    let slides: [OnboardingSlide] = [
        OnboardingSlide(
            iconName: "paintbrush.pointed.fill",
            gradientColors: [Color(hex: "#3F73D3"), Color(hex: "#2F5FBF")],
            title: "Your Art, Your Gallery",
            subtitle: "Artist Folio is the marketplace built for artists who paint. List your originals and reach collectors worldwide."
        ),
        OnboardingSlide(
            iconName: "globe.americas.fill",
            gradientColors: [Color(hex: "#5B3CC4"), Color(hex: "#3F73D3")],
            title: "No Middlemen, No Limits",
            subtitle: "Sell directly to collectors anywhere in the world. Keep more of what you earn. No galleries, no agents required."
        ),
        OnboardingSlide(
            iconName: "checkmark.shield.fill",
            gradientColors: [Color(hex: "#34C759"), Color(hex: "#28A745")],
            title: "Safe, Simple, Beautiful",
            subtitle: "Secure payments, built-in messaging, and a beautiful experience designed for art lovers on both sides."
        ),
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if showLanding {
                LandingView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity))
            } else {
                onboardingContent.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showLanding)
    }

    var onboardingContent: some View {
        VStack(spacing: 0) {
            // Illustration
            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    OnboardingIllustration(slide: slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: UIScreen.main.bounds.height * 0.46)

            // Text
            VStack(spacing: AFSpacing.sm) {
                Text(slides[currentPage].title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.afTextPrimary)
                    .multilineTextAlignment(.center)
                    .id(currentPage)
                Text(slides[currentPage].subtitle)
                    .font(AFFont.bodyMedium).foregroundColor(.afTextSecondary)
                    .multilineTextAlignment(.center).lineSpacing(4)
                    .padding(.horizontal, AFSpacing.lg)
                    .id("sub_\(currentPage)")
            }
            .padding(.horizontal, AFSpacing.md).padding(.top, AFSpacing.xl)
            .animation(.easeInOut(duration: 0.25), value: currentPage)

            Spacer()

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.afPrimary : Color.afBorder)
                        .frame(width: i == currentPage ? 24 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, AFSpacing.lg)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPage < slides.count - 1 { currentPage += 1 }
                    else { showLanding = true }
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Continue" : "Get Started")
            }
            .buttonStyle(AFPrimaryButtonStyle())
            .padding(.horizontal, AFSpacing.lg)

            if currentPage < slides.count - 1 {
                Button("Skip") { withAnimation { showLanding = true } }
                    .font(AFFont.bodyMedium).foregroundColor(.afTextTertiary)
                    .padding(.top, AFSpacing.sm)
            }

            Spacer().frame(height: AFSpacing.xl)
        }
    }
}

struct OnboardingSlide {
    let iconName: String
    let gradientColors: [Color]
    let title: String
    let subtitle: String
}

struct OnboardingIllustration: View {
    let slide: OnboardingSlide

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: slide.gradientColors.map { $0.opacity(0.10) },
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 260, height: 260)
            Circle()
                .fill(LinearGradient(colors: slide.gradientColors.map { $0.opacity(0.16) },
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 180, height: 180)
            Image(systemName: slide.iconName)
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(LinearGradient(colors: slide.gradientColors,
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .padding(.top, 40)
    }
}

#Preview { OnboardingRootView() }

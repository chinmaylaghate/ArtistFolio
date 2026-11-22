import SwiftUI

struct OnboardingRootView: View {
    @State private var currentPage = 0
    @State private var showLanding = false

    let slides: [OnboardingSlide] = [
        OnboardingSlide(
            iconName: "paintbrush.pointed.fill",
            gradientColors: [Color(hex: "#3F73D3"), Color(hex: "#2F5FBF")],
            title: "Your Art, Your Gallery",
            subtitle: "Artist Folio is a home for original art. Build a portfolio and reach collectors worldwide."
        ),
        OnboardingSlide(
            iconName: "globe.americas.fill",
            gradientColors: [Color(hex: "#5B3CC4"), Color(hex: "#3F73D3")],
            title: "Discover Original Work",
            subtitle: "Browse by style and medium, save pieces you love, and follow the artists behind them."
        ),
        OnboardingSlide(
            iconName: "person.2.fill",
            gradientColors: [Color(hex: "#34C759"), Color(hex: "#28A745")],
            title: "Connect Directly",
            subtitle: "Reach artists through the contact details they share. Any purchase is arranged between you and the artist."
        ),
    ]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if showLanding {
                LandingView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                onboardingContent.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showLanding)
    }

    private var onboardingContent: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    OnboardingIllustration(slide: slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .containerRelativeFrame(.vertical) { height, _ in height * 0.46 }

            VStack(spacing: AFSpacing.sm) {
                Text(slides[currentPage].title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.afTextPrimary)
                    .multilineTextAlignment(.center)
                Text(slides[currentPage].subtitle)
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AFSpacing.lg)
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.xl)
            .animation(.easeInOut(duration: 0.25), value: currentPage)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.afPrimary : Color.afBorder)
                        .frame(width: index == currentPage ? 24 : 6, height: 6)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            .padding(.bottom, AFSpacing.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(currentPage + 1) of \(slides.count)")

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentPage < slides.count - 1 { currentPage += 1 } else { showLanding = true }
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Continue" : "Get Started")
            }
            .buttonStyle(AFPrimaryButtonStyle())
            .padding(.horizontal, AFSpacing.lg)

            if currentPage < slides.count - 1 {
                Button("Skip") { withAnimation { showLanding = true } }
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afTextSecondary)
                    .frame(minHeight: 44)
                    .padding(.top, AFSpacing.xxs)
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
                .fill(LinearGradient(colors: slide.gradientColors.map { $0.opacity(0.10) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 260, height: 260)
            Circle()
                .fill(LinearGradient(colors: slide.gradientColors.map { $0.opacity(0.16) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 180, height: 180)
            Image(systemName: slide.iconName)
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(LinearGradient(colors: slide.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .padding(.top, 40)
        .accessibilityHidden(true)
    }
}

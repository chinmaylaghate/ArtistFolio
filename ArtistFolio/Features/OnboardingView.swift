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
            iconName: "bubble.left.and.bubble.right.fill",
            gradientColors: [Color(hex: "#34C759"), Color(hex: "#1A7F3C")],
            title: "Message & Commission",
            subtitle: "Chat directly with artists. Request a custom commission and track it all in one place."
        ),
        OnboardingSlide(
            iconName: "person.2.fill",
            gradientColors: [Color(hex: "#FF6B6B"), Color(hex: "#C0392B")],
            title: "Connect Directly",
            subtitle: "Every purchase is arranged between you and the artist. No middleman. Direct relationships."
        ),
    ]

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
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
    @State private var animating = false

    var body: some View {
        ZStack {
            // Blurred ambient blobs
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(slide.gradientColors[i % slide.gradientColors.count].opacity(0.18))
                    .frame(width: CGFloat(200 - i * 40))
                    .offset(
                        x: CGFloat([-30, 30, 0][i]),
                        y: CGFloat([20, -20, 30][i])
                    )
                    .blur(radius: 20)
                    .scaleEffect(animating ? 1.08 : 0.95)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(Double(i) * 0.5), value: animating)
            }

            // Art canvas frame
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 220, height: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(LinearGradient(colors: slide.gradientColors.map { $0.opacity(0.4) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
                .shadow(color: slide.gradientColors[0].opacity(0.25), radius: 24, y: 8)

            // Main icon
            Image(systemName: slide.iconName)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(LinearGradient(colors: slide.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.pulse, options: .repeating)
                .scaleEffect(animating ? 1.05 : 0.98)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animating)

            // Decorative accent dots
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(slide.gradientColors[i % 2].opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(
                        x: [100.0, -100.0, 90.0, -85.0][i],
                        y: [-80.0, -70.0, 85.0, 90.0][i]
                    )
                    .scaleEffect(animating ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: animating)
            }
        }
        .padding(.top, 40)
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}

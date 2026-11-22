import SwiftUI

struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: AFSpacing.xs) {
            Image(systemName: "photo.artframe")
                .font(.system(.largeTitle))
                .imageScale(.large)
                .foregroundStyle(.tint)
            Wordmark().font(.title2)
        }
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.92)
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            withAnimation(.smooth(duration: 0.5)) { isVisible = true }
        }
    }
}

#Preview { SplashView() }

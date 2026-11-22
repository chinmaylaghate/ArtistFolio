// MARK: - ArtistFolioApp Entry Point
import SwiftUI

@main
struct ArtistFolioApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.afBackground.ignoresSafeArea()

            if appState.showSplash {
                SplashView()
                    .transition(.opacity)
            } else if !appState.isAuthenticated {
                OnboardingRootView()
                    .transition(.opacity)
            } else if appState.showFirstTimeSetup {
                if appState.isArtist {
                    ArtistSetupFlow()
                        .transition(.opacity)
                } else {
                    CollectorSetupFlow()
                        .transition(.opacity)
                }
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.4), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: appState.showFirstTimeSetup)
    }
}

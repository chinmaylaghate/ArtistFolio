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

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.afBackground.ignoresSafeArea()
            if appState.showSplash {
                SplashView().transition(.opacity)
            } else if !appState.hasEnteredApp {
                OnboardingRootView().transition(.opacity)
            } else {
                MainTabView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.showSplash)
        .animation(.easeInOut(duration: 0.4), value: appState.hasEnteredApp)
        .sheet(isPresented: $appState.showProfileSetup) {
            ProfileEditorView(mode: .create)
        }
        .alert("iCloud Required", isPresented: $appState.showICloudPrompt) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("You can browse without an account. Sign in to iCloud on this device to save art, follow artists, or publish your work.")
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { appState.alertMessage != nil },
            set: { if !$0 { appState.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.alertMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !appState.showSplash {
                Task { await appState.reloadSession() }
            }
        }
    }
}

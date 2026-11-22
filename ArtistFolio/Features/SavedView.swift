import SwiftUI

struct SavedView: View {
    @EnvironmentObject var appState: AppState
    @State private var artworks: [Artwork] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var visible: [Artwork] {
        artworks.filter { appState.isSaved($0.id) && appState.isVisible($0) }
    }

    var body: some View {
        Group {
            if !appState.hasICloud {
                EmptyStateView(icon: "icloud", title: "Sign In to Save Art", subtitle: "Saved art stays private in your iCloud account.", actionTitle: "Learn How") {
                    appState.showICloudPrompt = true
                }
            } else if isLoading {
                ProgressView()
            } else if let errorMessage, visible.isEmpty {
                EmptyStateView(icon: "wifi.exclamationmark", title: "Couldn't Load Saved Art", subtitle: errorMessage, actionTitle: "Try Again") {
                    Task { await load() }
                }
            } else if visible.isEmpty {
                EmptyStateView(icon: "heart", title: "No Saved Artworks", subtitle: "Tap the heart on any artwork to save it here.")
            } else {
                ScrollView {
                    ArtworkGrid(artworks: visible).padding(.horizontal, AFSpacing.md)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Saved")
        .task(id: appState.library.saved) { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            artworks = try await appState.backend.artworks(ids: Array(appState.library.saved))
        } catch is CancellationError {
            return
        } catch {
            errorMessage = AppState.message(for: error)
        }
        isLoading = false
    }
}

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ForEach(appState.availableTabs, id: \.self) { tab in
                NavigationStack {
                    root(for: tab).artNavigation()
                }
                .tabItem { Label(tab.label, systemImage: tab.icon) }
                .tag(tab)
            }
        }
        .sensoryFeedback(.selection, trigger: appState.selectedTab)
        .sheet(item: $appState.openedLink) { LinkedContentView(link: $0) }
    }

    @ViewBuilder
    private func root(for tab: TabItem) -> some View {
        switch tab {
        case .home: HomeView()
        case .search: SearchView()
        case .studio: StudioView()
        case .saved: SavedView()
        case .profile: ProfileView()
        }
    }
}

/// The artwork or artist behind a shared link, shown in its own navigation stack.
struct LinkedContentView: View {
    @Environment(\.dismiss) private var dismiss
    let link: AppLink

    var body: some View {
        NavigationStack {
            Group {
                switch link {
                case .artwork(let id): LinkedArtworkView(artworkID: id)
                case .artist(let id): ArtistProfileView(artistId: id)
                }
            }
            .artNavigation()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LinkedArtworkView: View {
    @EnvironmentObject var appState: AppState
    let artworkID: String
    @State private var artwork: Artwork?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let artwork {
                ArtworkDetailView(artwork: artwork)
            } else if isLoading {
                ProgressView()
            } else {
                EmptyStateView(icon: "photo.artframe", title: "Artwork Unavailable", subtitle: "This piece may have been removed or hidden.")
            }
        }
        .task(id: artworkID) {
            let found = try? await appState.backend.artworks(ids: [artworkID]).first
            artwork = found.flatMap { appState.isVisible($0) ? $0 : nil }
            isLoading = false
        }
    }
}

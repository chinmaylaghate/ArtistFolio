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

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSearch = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home: NavigationStack { HomeView() }.afGlassNavBar()
                case .studio: NavigationStack { StudioView() }.afGlassNavBar()
                case .saved: NavigationStack { SavedView() }.afGlassNavBar()
                case .profile: NavigationStack { ProfileView() }.afGlassNavBar()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if appState.tabBarHiders == 0 {
                GlassTabBar(showSearch: $showSearch)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.tabBarHiders == 0)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showSearch) {
            NavigationStack { SearchView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct GlassTabBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSearch: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(appState.availableTabs, id: \.self) { tab in
                    GlassTabItem(tab: tab, isSelected: appState.selectedTab == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = tab }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .afGlassShadow()

            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.afTextPrimary)
                    .frame(width: 46, height: 46)
            }
            .background(.ultraThinMaterial, in: Circle())
            .afGlassShadow()
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

struct GlassTabItem: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 100)
                            .fill(Color(hex: "#EDEDED"))
                            .frame(width: 52, height: 36)
                    }
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .afPrimary : .afTextPrimary)
                        .frame(height: 36)
                }
                Text(tab.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .afPrimary : .afTextPrimary)
                    .lineLimit(1)
            }
            .frame(minWidth: 64)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

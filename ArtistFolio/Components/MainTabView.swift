// MARK: - Main Tab View with Glass Navigation
// Implements Figma "Tab Bar - iPhone" glass morphism design
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSearch: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Tab Content ──────────────────────────────────────
            Group {
                switch appState.selectedTab {
                case .home:
                    NavigationStack { HomeView() }
                        .afGlassNavBar()
                case .studio:
                    NavigationStack { StudioView() }
                        .afGlassNavBar()
                case .saved:
                    NavigationStack { SavedView() }
                        .afGlassNavBar()
                case .messages:
                    NavigationStack { MessagesView() }
                        .afGlassNavBar()
                case .profile:
                    NavigationStack { ProfileView() }
                        .afGlassNavBar()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Glass Tab Bar ─────────────────────────────────────
            GlassTabBar(showSearch: $showSearch)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showSearch) {
            NavigationStack { SearchView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Glass Tab Bar
// Replicates Figma: floating pill group + separate search pill
// Material: .ultraThinMaterial (= rgba(255,255,255,0.65) + blur)
// Shadow: 0 8px 40px rgba(0,0,0,0.12)

struct GlassTabBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSearch: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // ── Main tab pill ────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(appState.availableTabs, id: \.self) { tab in
                    GlassTabItem(
                        tab: tab,
                        isSelected: appState.selectedTab == tab,
                        badgeCount: badgeCount(for: tab)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .afGlassShadow()

            // ── Search pill ──────────────────────────────────────
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.afTextPrimary)
                    .frame(width: 46, height: 46)
            }
            .background(.ultraThinMaterial, in: Circle())
            .afGlassShadow()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func badgeCount(for tab: TabItem) -> Int {
        switch tab {
        case .messages: return appState.unreadMessageCount
        default: return 0
        }
    }
}

// MARK: - Glass Tab Item

struct GlassTabItem: View {
    let tab: TabItem
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        if isSelected {
                            // Active selection background from Figma: rgba(237,237,237,1)
                            RoundedRectangle(cornerRadius: 100)
                                .fill(Color(hex: "#EDEDED"))
                                .frame(width: 52, height: 36)
                        }

                        Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .afPrimary : .afTextPrimary)
                    }

                    if badgeCount > 0 {
                        Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.afError)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -4)
                    }
                }

                Text(tab.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .afPrimary : .afTextPrimary)
                    .lineLimit(1)
            }
            .frame(minWidth: 52)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AppState())
}

// MARK: - AppState & Environment
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - Auth State
    @Published var currentUser: AppUser?
    @Published var isAuthenticated: Bool = false
    @Published var isLoadingAuth: Bool = true

    // MARK: - Navigation
    @Published var selectedTab: TabItem = .home
    @Published var showSplash: Bool = true
    @Published var showOnboarding: Bool = false
    @Published var showFirstTimeSetup: Bool = false

    // MARK: - Cart
    @Published var cartItems: [CartItem] = []
    var cartCount: Int { cartItems.count }
    var cartTotal: Double { cartItems.reduce(0) { $0 + $1.artwork.price + ($1.selectedShipping?.price ?? 0) } }

    // MARK: - Favorites
    @Published var favoriteArtworkIds: Set<String> = []

    // MARK: - Notifications
    @Published var unreadNotificationCount: Int = 3
    @Published var unreadMessageCount: Int = 2

    // MARK: - Services
    let authService = AuthService()
    let artworkService = ArtworkService()
    let orderService = OrderService()
    let chatService = ChatService()
    let notificationService = NotificationService()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed
    var isArtist: Bool { currentUser?.role == .artist || currentUser?.role == .both }
    var isCollector: Bool { currentUser?.role == .collector || currentUser?.role == .both }

    var availableTabs: [TabItem] {
        if isArtist {
            return [.home, .studio, .messages, .profile]
        } else {
            return [.home, .saved, .messages, .profile]
        }
    }

    init() {
        setupAuthListener()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                self.showSplash = false
            }
        }
    }

    private func setupAuthListener() {
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                let wasAuthenticated = self.isAuthenticated
                self.currentUser = user
                self.isAuthenticated = user != nil
                self.isLoadingAuth = false
                if user == nil {
                    self.showOnboarding = true
                    self.showFirstTimeSetup = false
                } else if !wasAuthenticated {
                    // Newly authenticated — show first-time setup
                    self.showFirstTimeSetup = true
                }
            }
            .store(in: &cancellables)
    }

    func completeFirstTimeSetup() {
        withAnimation(.easeInOut(duration: 0.4)) {
            showFirstTimeSetup = false
        }
    }

    // MARK: - Cart Actions
    func addToCart(_ artwork: Artwork) {
        guard !cartItems.contains(where: { $0.artwork.id == artwork.id }) else { return }
        let item = CartItem(id: UUID().uuidString, artwork: artwork, selectedShipping: artwork.shippingOptions.first, addedAt: Date())
        cartItems.append(item)
    }

    func removeFromCart(id: String) {
        cartItems.removeAll { $0.id == id }
    }

    func clearCart() {
        cartItems.removeAll()
    }

    // MARK: - Favorites Actions
    func toggleFavorite(artworkId: String) {
        if favoriteArtworkIds.contains(artworkId) {
            favoriteArtworkIds.remove(artworkId)
        } else {
            favoriteArtworkIds.insert(artworkId)
        }
    }

    func isFavorite(artworkId: String) -> Bool {
        favoriteArtworkIds.contains(artworkId)
    }

    // MARK: - Sign Out
    func signOut() {
        Task {
            await authService.signOut()
            cartItems.removeAll()
            favoriteArtworkIds.removeAll()
            currentUser = nil
            isAuthenticated = false
            showOnboarding = true
            selectedTab = .home
        }
    }
}

// MARK: - Tab Items

enum TabItem: String, CaseIterable {
    case home, studio, saved, messages, profile

    var icon: String {
        switch self {
        case .home:     return "house"
        case .studio:   return "paintpalette"
        case .saved:    return "heart"
        case .messages: return "envelope"
        case .profile:  return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home:     return "house.fill"
        case .studio:   return "paintpalette.fill"
        case .saved:    return "heart.fill"
        case .messages: return "envelope.fill"
        case .profile:  return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .home:     return "Home"
        case .studio:   return "Studio"
        case .saved:    return "Saved"
        case .messages: return "Messages"
        case .profile:  return "Profile"
        }
    }
}

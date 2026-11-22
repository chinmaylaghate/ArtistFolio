// MARK: - Deep Link & URL Handling
import SwiftUI

// MARK: - Deep Link Router
// Handles: artistfolio://artwork/abc123
//           artistfolio://artist/xyz789
//           artistfolio://order/order123
//           https://artistfolio.com/artwork/abc123 (universal links)

enum DeepLink: Equatable {
    case artwork(id: String)
    case artist(id: String)
    case order(id: String)
    case event(id: String)
    case checkout(artworkId: String)
    case notifications
    case profile

    static func from(url: URL) -> DeepLink? {
        // Handle universal links: https://artistfolio.com/artwork/abc
        if let host = url.host, host.contains("artistfolio.com") {
            return fromPath(url.pathComponents)
        }
        // Handle custom scheme: artistfolio://artwork/abc
        if url.scheme == "artistfolio" {
            let components = [url.host ?? ""] + url.pathComponents.filter { $0 != "/" }
            return fromPath(components)
        }
        return nil
    }

    private static func fromPath(_ parts: [String]) -> DeepLink? {
        guard parts.count >= 2 else { return nil }
        switch parts[0] {
        case "artwork":   return .artwork(id: parts[1])
        case "artist":    return .artist(id: parts[1])
        case "order":     return .order(id: parts[1])
        case "event":     return .event(id: parts[1])
        case "checkout":  return .checkout(artworkId: parts[1])
        case "notifications": return .notifications
        case "profile":   return .profile
        default:          return nil
        }
    }
}

// MARK: - URL Handler Extension on AppState
extension AppState {
    func handle(url: URL) {
        guard let link = DeepLink.from(url: url) else { return }
        switch link {
        case .artwork:
            selectedTab = .home
        case .artist:
            selectedTab = .home
        case .order:
            selectedTab = .profile
        case .notifications:
            selectedTab = .home
        case .profile:
            selectedTab = .profile
        default:
            break
        }
    }
}

// MARK: - Scene Phase Handler
struct ScenePhaseHandler: ViewModifier {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    Task { await appState.notificationService.fetchNotifications() }
                case .background:
                    // Save any pending state
                    break
                default:
                    break
                }
            }
            .onOpenURL { url in
                appState.handle(url: url)
            }
    }
}

extension View {
    func withScenePhaseHandling() -> some View {
        modifier(ScenePhaseHandler())
    }
}

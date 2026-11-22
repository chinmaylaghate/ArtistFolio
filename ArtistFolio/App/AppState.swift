import CloudKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Session: Equatable {
        case loading
        case guest
        case needsProfile(userID: String)
        case active(UserProfile)
    }

    @Published private(set) var session: Session = .loading
    @Published private(set) var library = UserLibrary()
    @Published private(set) var contentVersion = 0
    @Published var selectedTab: TabItem = .home
    @Published var showSplash = true
    @Published var showProfileSetup = false
    @Published var showICloudPrompt = false
    @Published var showFirstTimeSetup = false
    @Published var alertMessage: String?
    @Published var hasEnteredApp: Bool {
        didSet { UserDefaults.standard.set(hasEnteredApp, forKey: Self.enteredKey) }
    }

    let backend: ArtBackend
    private static let enteredKey = "hasEnteredApp"
    private var accountObserver: NSObjectProtocol?

    init(backend: ArtBackend? = nil) {
        self.backend = backend ?? BackendFactory.make()
        hasEnteredApp = UserDefaults.standard.bool(forKey: Self.enteredKey)
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.reloadSession(resetIdentity: true) }
        }
        Task {
            await reloadSession()
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
    }

    deinit {
        if let accountObserver { NotificationCenter.default.removeObserver(accountObserver) }
    }

    var profile: UserProfile? {
        if case .active(let profile) = session { return profile }
        return nil
    }

    var currentUserID: String? {
        switch session {
        case .active(let profile): return profile.id
        case .needsProfile(let id): return id
        default: return nil
        }
    }

    var isArtist: Bool { profile?.role == .artist }
    var hasICloud: Bool { currentUserID != nil }

    var availableTabs: [TabItem] {
        [.home, .search, isArtist ? .studio : .saved, .profile]
    }

    func reloadSession(resetIdentity: Bool = false) async {
        if resetIdentity { await backend.resetIdentity() }
        do {
            guard let id = try await backend.currentUserID() else {
                session = .guest
                library = UserLibrary()
                normalizeTab()
                return
            }
            if let profile = try await backend.profile(ownerID: id) {
                session = .active(profile)
            } else {
                session = .needsProfile(userID: id)
            }
            library = try await backend.library()
        } catch {
            if session == .loading { session = .guest }
        }
        normalizeTab()
    }

    func enterApp(createProfile: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) { hasEnteredApp = true }
        if createProfile { beginProfileSetup() }
    }

    func beginProfileSetup() {
        Task {
            await reloadSession()
            switch session {
            case .needsProfile: showProfileSetup = true
            case .active: break
            default: showICloudPrompt = true
            }
        }
    }

    func updateProfile(_ updated: UserProfile, isFirstTime: Bool = false) {
        session = .active(updated)
        normalizeTab()
        refreshContent()
        if isFirstTime { showFirstTimeSetup = true }
    }

    func refreshContent() {
        contentVersion += 1
    }

    func isVisible(_ artwork: Artwork) -> Bool {
        !library.blocked.contains(artwork.artistId)
    }

    func isSaved(_ artworkID: String) -> Bool { library.saved.contains(artworkID) }
    func isFollowing(_ artistID: String) -> Bool { library.following.contains(artistID) }
    func isBlocked(_ artistID: String) -> Bool { library.blocked.contains(artistID) }

    func toggleSaved(_ artworkID: String) {
        toggle(.saved, id: artworkID, included: !isSaved(artworkID))
    }

    func toggleFollowing(_ artistID: String) {
        toggle(.following, id: artistID, included: !isFollowing(artistID))
    }

    func setBlocked(_ artistID: String, blocked: Bool) {
        toggle(.blocked, id: artistID, included: blocked)
        if blocked, isFollowing(artistID) {
            toggle(.following, id: artistID, included: false)
        }
    }

    func report(target: ReportTarget, targetID: String, reason: ReportReason, note: String) async -> Bool {
        guard hasICloud else {
            showICloudPrompt = true
            return false
        }
        do {
            try await backend.submitReport(target: target, targetID: targetID, reason: reason, note: note)
            return true
        } catch {
            alertMessage = Self.message(for: error)
            return false
        }
    }

    func deleteAccount() async -> Bool {
        do {
            try await backend.deleteAccount()
            library = UserLibrary()
            selectedTab = .home
            await reloadSession(resetIdentity: true)
            refreshContent()
            return true
        } catch {
            alertMessage = "Your account was not fully deleted. \(Self.message(for: error)) Please try again."
            return false
        }
    }

    static func message(for error: Error) -> String {
        if let error = error as? AppError { return error.errorDescription ?? "Something went wrong." }
        if let error = error as? CKError {
            switch error.code {
            case .networkUnavailable, .networkFailure: return "You appear to be offline. Check your connection and try again."
            case .notAuthenticated: return "Sign in to iCloud in Settings to continue."
            case .quotaExceeded: return "Your iCloud storage is full."
            case .requestRateLimited, .serviceUnavailable, .zoneBusy: return "iCloud is busy. Try again shortly."
            case .permissionFailure: return "You don't have permission to do that."
            default: break
            }
        }
        return "Something went wrong. Please try again."
    }

    private func toggle(_ kind: LibraryKind, id: String, included: Bool) {
        guard hasICloud else {
            showICloudPrompt = true
            return
        }
        apply(kind, id: id, included: included)
        Task {
            do {
                try await backend.setLibrary(kind, id: id, included: included)
            } catch {
                apply(kind, id: id, included: !included)
                alertMessage = Self.message(for: error)
            }
        }
    }

    private func apply(_ kind: LibraryKind, id: String, included: Bool) {
        switch kind {
        case .saved: library.saved.set(id, included)
        case .following: library.following.set(id, included)
        case .blocked: library.blocked.set(id, included)
        }
    }

    private func normalizeTab() {
        if !availableTabs.contains(selectedTab) { selectedTab = .home }
    }
}

private extension Set where Element == String {
    mutating func set(_ value: String, _ included: Bool) {
        if included { insert(value) } else { remove(value) }
    }
}

enum BackendFactory {
    static func make() -> ArtBackend {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil {
            return DemoBackend(mode: "guest")
        }
        if let mode = UserDefaults.standard.string(forKey: "demo") {
            return DemoBackend(mode: mode)
        }
        #endif
        return CloudKitService()
    }
}

enum TabItem: String, CaseIterable {
    case home, search, studio, saved, profile

    var icon: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .studio: return "paintpalette"
        case .saved: return "heart"
        case .profile: return "person.crop.circle"
        }
    }

    var label: String { rawValue.capitalized }
}

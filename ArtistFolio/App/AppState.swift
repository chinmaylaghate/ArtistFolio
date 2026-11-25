import CloudKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Session: Equatable {
        case loading
        case guest
        case needsProfile(userID: String)
        case profileUnavailable(userID: String)
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
    /// An artwork or artist opened from a shared link or QR code; shown over the tabs.
    @Published var openedLink: AppLink?
    @Published var hasEnteredApp: Bool {
        didSet {
            // Demo sessions are in-memory, so relaunching returns to the normal entry flow.
            if !isDemoMode { UserDefaults.standard.set(hasEnteredApp, forKey: Self.enteredKey) }
        }
    }
    @Published private(set) var isDemoMode = false

    private(set) var backend: ArtBackend
    private let liveBackend: ArtBackend
    private static let enteredKey = "hasEnteredApp"
    private var accountObserver: NSObjectProtocol?
    private var accountGeneration = 0
    private var didBackfillSizes = false

    init(backend: ArtBackend? = nil) {
        let resolved = backend ?? BackendFactory.make()
        self.backend = resolved
        liveBackend = resolved
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
        case .needsProfile(let id), .profileUnavailable(let id): return id
        default: return nil
        }
    }

    var isProfileUnavailable: Bool {
        if case .profileUnavailable = session { return true }
        return false
    }

    var isArtist: Bool { profile?.role == .artist }
    var hasICloud: Bool { currentUserID != nil }

    var availableTabs: [TabItem] {
        [.home, .search, isArtist ? .studio : .saved, .profile]
    }

    func reloadSession(resetIdentity: Bool = false) async {
        if resetIdentity {
            accountGeneration += 1
            session = .loading
            library = UserLibrary()
            normalizeTab()
            await backend.resetIdentity()
        }
        // A reload that began under a previous iCloud account must not publish its results.
        let generation = accountGeneration

        let userID: String?
        do {
            userID = try await backend.currentUserID()
        } catch {
            guard generation == accountGeneration else { return }
            if session == .loading { session = .guest }
            normalizeTab()
            return
        }
        guard generation == accountGeneration else { return }
        guard let userID else {
            session = .guest
            library = UserLibrary()
            normalizeTab()
            return
        }
        if currentUserID != userID { library = UserLibrary() }

        do {
            let loaded = try await backend.profile(ownerID: userID)
            guard generation == accountGeneration else { return }
            session = loaded.map(Session.active) ?? .needsProfile(userID: userID)
        } catch {
            guard generation == accountGeneration else { return }
            if currentUserID != userID { session = .profileUnavailable(userID: userID) }
        }

        let loadedLibrary = try? await backend.library()
        guard generation == accountGeneration else { return }
        if let loadedLibrary { library = loadedLibrary }
        normalizeTab()
    }

    func enterApp(createProfile: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) { hasEnteredApp = true }
        if createProfile { beginProfileSetup() }
    }

    func startDemo(as role: UserRole) async {
        isDemoMode = true
        backend = DemoBackend(mode: role.rawValue)
        selectedTab = .home
        await reloadSession(resetIdentity: true)
        refreshContent()
        withAnimation(.easeInOut(duration: 0.3)) { hasEnteredApp = true }
    }

    func exitDemo() async {
        guard isDemoMode else { return }
        isDemoMode = false
        backend = liveBackend
        selectedTab = .home
        withAnimation(.easeInOut(duration: 0.3)) {
            hasEnteredApp = UserDefaults.standard.bool(forKey: Self.enteredKey)
        }
        await reloadSession(resetIdentity: true)
        refreshContent()
    }

    enum ICloudAccess { case entered, needsProfile, noICloud, unavailable }

    func continueWithICloud() async -> ICloudAccess {
        await reloadSession()
        switch session {
        case .active:
            enterApp(createProfile: false)
            return .entered
        case .needsProfile:
            return .needsProfile
        case .profileUnavailable:
            return .unavailable
        case .guest, .loading:
            showICloudPrompt = true
            return .noICloud
        }
    }

    func createAccount(displayName: String, role: UserRole, contactEmail: String) async throws {
        switch await continueWithICloud() {
        case .entered, .noICloud:
            return
        case .unavailable:
            throw AppError.accountUnavailable
        case .needsProfile:
            guard let userID = currentUserID else { throw AppError.iCloudRequired }
            var profile = UserProfile(id: userID, displayName: displayName, role: role)
            profile.contactEmail = role == .artist ? contactEmail : ""
            let saved = try await backend.saveProfile(profile, avatar: nil)
            enterApp(createProfile: false)
            updateProfile(saved, isFirstTime: true)
        }
    }

    func beginProfileSetup() {
        Task {
            await reloadSession()
            switch session {
            case .needsProfile: showProfileSetup = true
            case .active, .loading: break
            case .profileUnavailable: alertMessage = "We couldn't load your profile. Check your connection and try again."
            case .guest: showICloudPrompt = true
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
    /// Handles a universal link. Returns false for links the app doesn't recognise.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let link = AppLink(url: url) else { return false }
        openedLink = link
        return true
    }

    /// Older listings were saved without a size band, so the size filter misses them.
    /// Fills it in for the signed-in artist's own listings once per launch; a failure is retried on the next Studio load.
    func backfillSizeClassesOnce() async {
        guard !didBackfillSizes, !isDemoMode, hasICloud else { return }
        didBackfillSizes = true
        if (try? await backend.backfillSizeClasses()) == nil { didBackfillSizes = false }
    }

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
            if isDemoMode {
                await exitDemo()
                return true
            }
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

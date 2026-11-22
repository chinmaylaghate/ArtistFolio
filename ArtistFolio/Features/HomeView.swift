import CloudKit
import SwiftUI

@MainActor
final class FeedModel: ObservableObject {
    @Published var artworks: [Artwork] = []
    @Published var following: [Artwork] = []
    @Published var discover: [Artwork] = []
    @Published var featuredArtists: [UserProfile] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    private var cursor: CKQueryOperation.Cursor?

    func load(backend: ArtBackend, medium: ArtworkMedium?, followed: Set<String>) async {
        isLoading = artworks.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        var filters = ArtworkFilters()
        if let medium { filters.mediums = [medium] }
        do {
            let page = try await backend.artworks(filters: filters, cursor: nil)
            guard !Task.isCancelled else { return }
            artworks = page.items
            cursor = page.cursor
            if medium == nil {
                discover = page.items
            } else if discover.isEmpty {
                discover = (try? await backend.artworks(filters: ArtworkFilters(), cursor: nil))?.items ?? []
            }
            featuredArtists = await Self.artists(in: discover, backend: backend)
            following = await Self.followingFeed(backend: backend, followed: followed)
        } catch is CancellationError {
        } catch {
            errorMessage = AppState.message(for: error)
        }
    }

    func loadMore(backend: ArtBackend) async {
        guard let cursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let page = try? await backend.artworks(filters: ArtworkFilters(), cursor: cursor) {
            let known = Set(artworks.map(\.id))
            artworks += page.items.filter { !known.contains($0.id) }
            self.cursor = page.cursor
        }
    }

    private static func artists(in artworks: [Artwork], backend: ArtBackend) async -> [UserProfile] {
        var seen = Set<String>()
        let ids = artworks.map(\.artistId).filter { seen.insert($0).inserted }.prefix(12)
        var output: [UserProfile] = []
        for id in ids {
            if let profile = try? await backend.profile(ownerID: id), profile.role == .artist {
                output.append(profile)
            }
        }
        return output
    }

    private static func followingFeed(backend: ArtBackend, followed: Set<String>) async -> [Artwork] {
        var output: [Artwork] = []
        for id in followed.sorted().prefix(10) {
            output += (try? await backend.artworks(ownerID: id)) ?? []
        }
        return Array(output.sorted { $0.createdAt > $1.createdAt }.prefix(10))
    }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model = FeedModel()
    @State private var selectedMedium: ArtworkMedium?
    @State private var showNewArtwork = false
    @AppStorage("dismissedFollowPrompt") private var dismissedFollowPrompt = false

    private let mediums: [ArtworkMedium] = [.oilOnCanvas, .acrylic, .watercolor, .mixedMedia, .digital, .drawing]

    private var loadKey: String {
        "\(selectedMedium?.rawValue ?? "all")-\(appState.contentVersion)-\(appState.library.following.sorted())"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                if let hero = heroArtwork {
                    FeaturedCollectionCard(artwork: hero)
                        .padding(.horizontal, AFSpacing.md)
                }

                if showFollowPrompt {
                    FollowPromptCard(artists: suggestedArtists) {
                        withAnimation(.smooth) { dismissedFollowPrompt = true }
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                if !suggestedArtists.isEmpty {
                    FeaturedArtistsSection(artists: suggestedArtists)
                }

                if !justListed.isEmpty {
                    JustListedSection(artworks: justListed)
                }

                let followingVisible = model.following.filter(appState.isVisible)
                if !followingVisible.isEmpty {
                    VStack(alignment: .leading, spacing: AFSpacing.sm) {
                        Text("From Artists You Follow")
                            .font(.title2.bold())
                            .padding(.horizontal, AFSpacing.md)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: AFSpacing.sm) {
                                ForEach(followingVisible) { artwork in
                                    ArtworkLink(artwork: artwork).frame(width: 150)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, AFSpacing.md)
                        }
                        .scrollTargetBehavior(.viewAligned)
                    }
                }

                VStack(alignment: .leading, spacing: AFSpacing.sm) {
                    Text("New Arrivals")
                        .font(.title2.bold())
                        .padding(.horizontal, AFSpacing.md)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AFSpacing.xs) {
                            FilterChip(label: "All", isSelected: selectedMedium == nil) { selectedMedium = nil }
                            ForEach(mediums) { medium in
                                FilterChip(label: medium.rawValue, isSelected: selectedMedium == medium) { selectedMedium = medium }
                            }
                        }
                        .padding(.horizontal, AFSpacing.md)
                    }
                    content.padding(.horizontal, AFSpacing.md)
                }
            }
            .padding(.bottom, AFSpacing.md)
        }
        .navigationTitle("Home")
        .toolbar {
            if appState.isArtist {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Artwork", systemImage: "plus") { showNewArtwork = true }
                }
            }
        }
        .refreshable { await reload() }
        .task(id: loadKey) { await reload() }
        .sheet(isPresented: $showNewArtwork) { ArtworkEditorView(existing: nil) }
    }

    private var heroArtwork: Artwork? {
        model.discover.first { $0.style == StyleCollectionLink.featured.style && appState.isVisible($0) }
    }

    private var suggestedArtists: [UserProfile] {
        model.featuredArtists.filter { !appState.isBlocked($0.id) && $0.id != appState.currentUserID }
    }

    private var justListed: [Artwork] {
        Array(model.discover.filter { $0.status == .available && appState.isVisible($0) }.prefix(8))
    }

    private var showFollowPrompt: Bool {
        !dismissedFollowPrompt && appState.library.following.isEmpty && !suggestedArtists.isEmpty
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, AFSpacing.xxl)
        } else if let error = model.errorMessage, model.artworks.isEmpty {
            EmptyStateView(icon: "wifi.exclamationmark", title: "Couldn't Load Art", subtitle: error, actionTitle: "Try Again") {
                Task { await reload() }
            }
        } else if model.artworks.filter(appState.isVisible).isEmpty {
            EmptyStateView(icon: "photo.on.rectangle.angled", title: "No Artworks Yet", subtitle: "New work will appear here as artists publish it.")
        } else {
            ArtworkGrid(artworks: model.artworks) {
                guard selectedMedium == nil else { return }
                Task { await model.loadMore(backend: appState.backend) }
            }
            if model.isLoadingMore {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private func reload() async {
        await model.load(backend: appState.backend, medium: selectedMedium, followed: appState.library.following)
    }
}

struct StyleCollectionLink: Hashable {
    let style: ArtworkStyle
    let title: String
    let subtitle: String

    static let featured = StyleCollectionLink(style: .abstract, title: "Abstract Masters", subtitle: "Bold forms & pure emotion")
}

struct ArtistDirectoryLink: Hashable {
    let artists: [UserProfile]
}

private struct FeaturedCollectionCard: View {
    let artwork: Artwork
    private let link = StyleCollectionLink.featured

    var body: some View {
        NavigationLink(value: link) {
            Color.clear
                .frame(height: 176)
                .overlay(CloudImage(url: artwork.thumbnailURL, maxPixels: 1200))
                .overlay(LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.15), .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    VStack(spacing: AFSpacing.xxs) {
                        Label("FEATURED COLLECTION", systemImage: "sparkles")
                            .font(.caption.weight(.medium))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text(link.title).font(.title2.weight(.semibold))
                        Text(link.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    }
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(AFSpacing.md)
                }
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: AFRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Featured collection, \(link.title). \(link.subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct FollowPromptCard: View {
    let artists: [UserProfile]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AFSpacing.md) {
            HStack(alignment: .top, spacing: AFSpacing.sm) {
                Image(systemName: "person.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.afPrimary.opacity(0.14), in: RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Follow your favourite artists").font(.headline)
                    Text("See their new work first, right here on Home.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -AFSpacing.xs)
                .padding(.trailing, -AFSpacing.xs)
                .accessibilityLabel("Dismiss")
            }
            NavigationLink(value: ArtistDirectoryLink(artists: artists)) {
                Label("Discover Artists", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .primaryAction()
        }
        .padding(AFSpacing.md)
        .background(Color.afPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: AFRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.lg, style: .continuous).strokeBorder(Color.afPrimary.opacity(0.2)))
    }
}

private struct FeaturedArtistsSection: View {
    let artists: [UserProfile]

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Featured Artists").font(.title2.bold())
                Spacer()
                NavigationLink("See All", value: ArtistDirectoryLink(artists: artists))
                    .font(.subheadline)
            }
            .padding(.horizontal, AFSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: AFSpacing.md) {
                    ForEach(artists) { artist in
                        NavigationLink(value: ArtistLink(id: artist.id)) {
                            VStack(spacing: AFSpacing.xxs) {
                                AvatarCircle(name: artist.displayName, url: artist.avatarURL, size: 68)
                                    .padding(3)
                                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5))
                                    .padding(.bottom, 2)
                                Text(artist.displayName.components(separatedBy: " ").first ?? artist.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let city = artist.location.components(separatedBy: ",").first, !city.isEmpty {
                                    Text(city).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .frame(width: 84)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(artist.location.isEmpty ? artist.displayName : "\(artist.displayName), \(artist.location)")
                    }
                }
                .padding(.horizontal, AFSpacing.md)
            }
        }
    }
}

private struct JustListedSection: View {
    let artworks: [Artwork]

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Label {
                Text("Just Listed").font(.title2.bold())
            } icon: {
                Image(systemName: "clock").foregroundStyle(.orange)
            }
            .padding(.horizontal, AFSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: AFSpacing.sm) {
                    ForEach(artworks) { artwork in
                        NavigationLink(value: artwork) {
                            Color.clear
                                .frame(width: 140, height: 168)
                                .overlay(CloudImage(url: artwork.thumbnailURL, maxPixels: 500))
                                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom))
                                .overlay(alignment: .bottom) {
                                    VStack(spacing: 1) {
                                        Text(artwork.title).font(.footnote.weight(.semibold)).lineLimit(1)
                                        Text(artwork.priceText).font(.caption).foregroundStyle(.white.opacity(0.85))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(AFSpacing.xs)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(artwork.title), \(artwork.priceText)")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, AFSpacing.md)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

struct StyleCollectionView: View {
    @EnvironmentObject var appState: AppState
    let link: StyleCollectionLink
    @State private var artworks: [Artwork] = []
    @State private var cursor: CKQueryOperation.Cursor?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var filters: ArtworkFilters {
        var filters = ArtworkFilters()
        filters.styles = [link.style]
        return filters
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage, artworks.isEmpty {
                EmptyStateView(icon: "wifi.exclamationmark", title: "Couldn't Load Collection", subtitle: errorMessage, actionTitle: "Try Again") {
                    Task { await load() }
                }
            } else if artworks.filter(appState.isVisible).isEmpty {
                EmptyStateView(icon: "photo.on.rectangle.angled", title: "No Artworks Yet", subtitle: "New work will appear here as artists publish it.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AFSpacing.md) {
                        Text(link.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        ArtworkGrid(artworks: artworks) {
                            Task { await loadMore() }
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(link.title)
        .toolbar(.hidden, for: .tabBar)
        .task(id: appState.contentVersion) { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            let page = try await appState.backend.artworks(filters: filters, cursor: nil)
            artworks = page.items
            cursor = page.cursor
        } catch is CancellationError {
            return
        } catch {
            errorMessage = AppState.message(for: error)
        }
        isLoading = false
    }

    private func loadMore() async {
        guard let current = cursor else { return }
        cursor = nil
        guard let page = try? await appState.backend.artworks(filters: filters, cursor: current) else {
            cursor = current
            return
        }
        let known = Set(artworks.map(\.id))
        artworks += page.items.filter { !known.contains($0.id) }
        cursor = page.cursor
    }
}

struct ArtistDirectoryView: View {
    @EnvironmentObject var appState: AppState
    let artists: [UserProfile]

    private var visible: [UserProfile] {
        artists.filter { !appState.isBlocked($0.id) }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                EmptyStateView(icon: "person.2", title: "No Artists Yet", subtitle: "Artists appear here when they publish work.")
            } else {
                List(visible) { artist in
                    NavigationLink(value: ArtistLink(id: artist.id)) {
                        HStack {
                            ArtistRow(profile: artist)
                            Spacer()
                            Button(appState.isFollowing(artist.id) ? "Following" : "Follow") {
                                appState.toggleFollowing(artist.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .sensoryFeedback(.selection, trigger: appState.isFollowing(artist.id))
                        }
                    }
                }
            }
        }
        .navigationTitle("Artists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

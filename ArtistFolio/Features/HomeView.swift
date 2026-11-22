import CloudKit
import SwiftUI

@MainActor
final class FeedModel: ObservableObject {
    @Published var artworks: [Artwork] = []
    @Published var following: [Artwork] = []
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

    private let mediums: [ArtworkMedium] = [.oilOnCanvas, .acrylic, .watercolor, .mixedMedia, .digital, .drawing]

    private var loadKey: String {
        "\(selectedMedium?.rawValue ?? "all")-\(appState.contentVersion)-\(appState.library.following.sorted())"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AFSpacing.xs) {
                        FilterChip(label: "All", isSelected: selectedMedium == nil) { selectedMedium = nil }
                        ForEach(mediums) { medium in
                            FilterChip(label: medium.rawValue, isSelected: selectedMedium == medium) { selectedMedium = medium }
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                }

                let followingVisible = model.following.filter(appState.isVisible)
                if selectedMedium == nil, !followingVisible.isEmpty {
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
                    Text("New Arrivals").font(.title2.bold())
                    content
                }
                .padding(.horizontal, AFSpacing.md)
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

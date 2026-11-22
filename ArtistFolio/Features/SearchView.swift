import SwiftUI

@MainActor
final class SearchModel: ObservableObject {
    @Published var filters = ArtworkFilters()
    @Published var artworks: [Artwork] = []
    @Published var artists: [UserProfile] = []
    @Published var isLoading = false
    @Published var hasSearched = false
    @Published var errorMessage: String?

    var isActive: Bool { !filters.text.trimmed.isEmpty || filters.hasRefinements }

    func search(backend: ArtBackend) async {
        guard isActive else {
            artworks = []
            artists = []
            hasSearched = false
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let foundArtworks = backend.artworks(filters: filters, cursor: nil)
            async let foundArtists = backend.searchProfiles(text: filters.hasRefinements ? "" : filters.text)
            let (page, people) = try await (foundArtworks, foundArtists)
            guard !Task.isCancelled else { return }
            artworks = page.items
            artists = people
            hasSearched = true
        } catch is CancellationError {
        } catch {
            errorMessage = AppState.message(for: error)
            hasSearched = true
        }
    }
}

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var model = SearchModel()
    @StateObject private var thumbnails = CollectionThumbnails()
    @State private var showFilters = false
    @State private var showMoreCollections = false

    private var searchKey: String {
        let f = model.filters
        return "\(f.text.trimmed)|\(f.styles)|\(f.mediums)|\(f.minPrice)|\(f.maxPrice)|\(f.sortBy)"
    }

    private var thumbnailKey: String {
        "\(appState.contentVersion)-\(appState.library.blocked.sorted())"
    }

    var body: some View {
        results
            .navigationTitle("Search")
            .searchable(text: $model.filters.text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Art, artists, styles")
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort By", selection: $model.filters.sortBy) {
                            ForEach(ArtworkFilters.SortOption.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFilters = true
                    } label: {
                        Label("Filters", systemImage: model.filters.hasRefinements
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) { FiltersSheet(filters: $model.filters) }
            .navigationDestination(isPresented: $showMoreCollections) {
                MoreCollectionsView(thumbnails: thumbnails)
            }
            .task(id: thumbnailKey) {
                await thumbnails.prepare(backend: appState.backend, isVisible: appState.isVisible)
            }
            .task(id: searchKey) {
                if !model.filters.text.isEmpty {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                }
                await model.search(backend: appState.backend)
            }
    }

    @ViewBuilder
    private var results: some View {
        if !model.isActive {
            browse
        } else if model.isLoading && model.artworks.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage {
            EmptyStateView(icon: "wifi.exclamationmark", title: "Search Failed", subtitle: error, actionTitle: "Try Again") {
                Task { await model.search(backend: appState.backend) }
            }
        } else if model.hasSearched,
                  model.artworks.filter(appState.isVisible).isEmpty,
                  visibleArtists.isEmpty {
            ContentUnavailableView.search(text: model.filters.text.trimmed)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.lg) {
                    if !visibleArtists.isEmpty {
                        VStack(alignment: .leading, spacing: AFSpacing.sm) {
                            Text("Artists").font(.title2.bold())
                            ForEach(visibleArtists) { artist in
                                NavigationLink(value: ArtistLink(id: artist.id)) {
                                    HStack {
                                        ArtistRow(profile: artist)
                                        Spacer()
                                        Image(systemName: "chevron.forward")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !model.artworks.filter(appState.isVisible).isEmpty {
                        Text("Artworks").font(.title2.bold())
                        ArtworkGrid(artworks: model.artworks)
                    }
                }
                .padding(.horizontal, AFSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var visibleArtists: [UserProfile] {
        model.artists.filter { !appState.isBlocked($0.id) }
    }

    @ViewBuilder
    private var browse: some View {
        if !thumbnails.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if thumbnails.available.isEmpty {
            EmptyStateView(icon: "square.grid.2x2", title: "No Collections Yet", subtitle: "Collections appear as artists publish their work.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.md) {
                    Label {
                        Text("Browse Collections")
                    } icon: {
                        Image(systemName: "safari").foregroundStyle(.tint)
                    }
                    .font(.title2.bold())
                    CollectionGrid(collections: thumbnails.upfront, thumbnails: thumbnails)
                    if !thumbnails.more.isEmpty {
                        Button { showMoreCollections = true } label: {
                            Text("View More").frame(maxWidth: .infinity)
                        }
                        .secondaryAction()
                    }
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.bottom, AFSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await thumbnails.prepare(backend: appState.backend, isVisible: appState.isVisible)
            }
        }
    }
}

@MainActor
final class CollectionThumbnails: ObservableObject {
    @Published private(set) var urls: [String: URL] = [:]
    @Published private(set) var available: [ArtCollection] = []
    @Published private(set) var hasLoaded = false

    var upfront: [ArtCollection] { Array(available.prefix(ArtCollection.upfrontCount)) }
    var more: [ArtCollection] { Array(available.dropFirst(ArtCollection.upfrontCount)) }

    func prepare(backend: ArtBackend, isVisible: (Artwork) -> Bool) async {
        guard let firstPage = try? await backend.artworks(filters: ArtworkFilters(), cursor: nil) else {
            guard !Task.isCancelled, !hasLoaded else { return }
            available = ArtCollection.all
            hasLoaded = true
            return
        }
        var matches: [String: [Artwork]] = [:]
        let catalog = firstPage.items.filter(isVisible)
        for collection in ArtCollection.all {
            let found = catalog.filter(collection.matches)
            if !found.isEmpty { matches[collection.id] = found }
        }

        var unknown: Set<String> = []
        if firstPage.cursor != nil {
            let remaining = ArtCollection.all.filter { matches[$0.id] == nil }
            for start in stride(from: 0, to: remaining.count, by: 4) {
                let batch = remaining[start..<min(start + 4, remaining.count)]
                let pages = await withTaskGroup(of: (String, ArtworkPage?).self) { group in
                    for collection in batch {
                        group.addTask { (collection.id, try? await backend.artworks(filters: collection.filters, cursor: nil)) }
                    }
                    var output: [(String, ArtworkPage?)] = []
                    for await result in group { output.append(result) }
                    return output
                }
                for (id, page) in pages {
                    guard let page else {
                        unknown.insert(id)
                        continue
                    }
                    let found = page.items.filter(isVisible)
                    if !found.isEmpty { matches[id] = found }
                }
            }
        }
        guard !Task.isCancelled else { return }

        var output: [String: URL] = [:]
        for collection in ArtCollection.all {
            if let url = Self.pick(from: matches[collection.id] ?? [], avoiding: Set(output.values)) {
                output[collection.id] = url
            }
        }
        urls = output
        // A failed lookup is not proof a collection is empty, so its tile stays.
        available = ArtCollection.all.filter { matches[$0.id] != nil || unknown.contains($0.id) }
        hasLoaded = true
    }

    private static func pick(from artworks: [Artwork], avoiding used: Set<URL>) -> URL? {
        let candidates = artworks.compactMap(\.thumbnailURL)
        return candidates.first { !used.contains($0) } ?? candidates.first
    }
}

private struct CollectionGrid: View {
    let collections: [ArtCollection]
    @ObservedObject var thumbnails: CollectionThumbnails

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: AFSpacing.sm), GridItem(.flexible())], spacing: AFSpacing.sm) {
            ForEach(collections) { collection in
                NavigationLink(value: collection) {
                    CollectionTile(title: collection.title, url: thumbnails.urls[collection.id])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CollectionTile: View {
    let title: String
    let url: URL?

    var body: some View {
        Color.clear
            .aspectRatio(1.45, contentMode: .fit)
            .overlay(CloudImage(url: url, maxPixels: 600))
            .overlay(LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom))
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(AFSpacing.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) collection")
            .accessibilityAddTraits(.isButton)
    }
}

private struct MoreCollectionsView: View {
    @ObservedObject var thumbnails: CollectionThumbnails

    var body: some View {
        ScrollView {
            CollectionGrid(collections: thumbnails.more, thumbnails: thumbnails)
                .padding(.horizontal, AFSpacing.md)
                .padding(.bottom, AFSpacing.md)
        }
        .navigationTitle("More Collections")
        .toolbar(.hidden, for: .tabBar)
    }
}

struct FiltersSheet: View {
    @Binding var filters: ArtworkFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Price Range") {
                    VStack(alignment: .leading) {
                        LabeledContent("Minimum", value: filters.minPrice, format: .currency(code: "USD").precision(.fractionLength(0)))
                        Slider(value: $filters.minPrice, in: 0...max(filters.maxPrice, 100), step: 50)
                            .accessibilityLabel("Minimum price")
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Maximum", value: filters.maxPrice, format: .currency(code: "USD").precision(.fractionLength(0)))
                        Slider(value: $filters.maxPrice, in: min(filters.minPrice, ArtworkFilters.priceCeiling - 100)...ArtworkFilters.priceCeiling, step: 100)
                            .accessibilityLabel("Maximum price")
                    }
                }
                options("Style", ArtworkStyle.allCases, selection: $filters.styles, label: \.rawValue)
                options("Medium", ArtworkMedium.allCases, selection: $filters.mediums, label: \.rawValue)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        let text = filters.text
                        filters = ArtworkFilters()
                        filters.text = text
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func options<T: Hashable & Identifiable>(_ title: String, _ options: [T], selection: Binding<[T]>, label: KeyPath<T, String>) -> some View {
        Section(title) {
            ForEach(options) { option in
                CheckmarkRow(title: option[keyPath: label], isSelected: selection.wrappedValue.contains(option)) {
                    if selection.wrappedValue.contains(option) {
                        selection.wrappedValue.removeAll { $0 == option }
                    } else {
                        selection.wrappedValue.append(option)
                    }
                }
            }
        }
    }
}

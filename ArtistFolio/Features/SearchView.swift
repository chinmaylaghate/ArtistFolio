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
    @State private var showFilters = false

    private var searchKey: String {
        let f = model.filters
        return "\(f.text.trimmed)|\(f.styles)|\(f.mediums)|\(f.minPrice)|\(f.maxPrice)|\(f.sortBy)"
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

    private var browse: some View {
        List {
            Section("Browse by Style") {
                ForEach(ArtworkStyle.allCases) { style in
                    Button {
                        model.filters.styles = [style]
                    } label: {
                        HStack {
                            Text(style.rawValue).foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
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

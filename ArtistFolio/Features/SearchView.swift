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
    @FocusState private var isFocused: Bool
    @State private var showFilters = false

    private var searchKey: String {
        let f = model.filters
        return "\(f.text.trimmed)|\(f.styles)|\(f.mediums)|\(f.minPrice)|\(f.maxPrice)|\(f.sortBy)"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AFSpacing.md) {
                Text("Discover")
                    .font(AFFont.displaySmall)
                    .foregroundColor(.afTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: AFSpacing.sm) {
                    HStack(spacing: AFSpacing.sm) {
                        Image(systemName: "magnifyingglass").foregroundColor(.afTextTertiary).accessibilityHidden(true)
                        TextField("Search art, artists, styles", text: $model.filters.text)
                            .font(AFFont.bodyMedium)
                            .focused($isFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                        if !model.filters.text.isEmpty {
                            Button { model.filters.text = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.afTextTertiary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .frame(height: 44)
                    .background(Color.afSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))

                    Button { showFilters = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16))
                            .foregroundColor(model.filters.hasRefinements ? .white : .afTextSecondary)
                            .frame(width: 44, height: 44)
                            .background(model.filters.hasRefinements ? Color.afPrimary : Color.afSurface2)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.top, AFSpacing.lg)
            .padding(.bottom, AFSpacing.sm)

            ScrollView(showsIndicators: false) {
                results
                    .padding(.horizontal, AFSpacing.md)
                    .padding(.vertical, AFSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color.afBackground)
        .toolbar(.hidden, for: .navigationBar)
        .artNavigation()
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
            ProgressView().tint(.afPrimary).padding(.top, AFSpacing.xxxl)
        } else if let error = model.errorMessage {
            EmptyStateView(icon: "wifi.exclamationmark", title: "Search Failed", subtitle: error, actionTitle: "Try Again") {
                Task { await model.search(backend: appState.backend) }
            }
        } else if model.hasSearched,
                  model.artworks.filter(appState.isVisible).isEmpty,
                  visibleArtists.isEmpty {
            EmptyStateView(icon: "magnifyingglass", title: "No Results", subtitle: "Search matches whole words. Try a title, artist, style, or medium.")
        } else {
            VStack(alignment: .leading, spacing: AFSpacing.lg) {
                if !visibleArtists.isEmpty {
                    VStack(alignment: .leading, spacing: AFSpacing.xs) {
                        Text("Artists").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
                        ForEach(visibleArtists) { artist in
                            NavigationLink(value: ArtistLink(id: artist.id)) { ArtistRow(profile: artist) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                Picker("Sort", selection: $model.filters.sortBy) {
                    ForEach(ArtworkFilters.SortOption.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(.afPrimary)
                ArtworkGrid(artworks: model.artworks)
            }
        }
    }

    private var visibleArtists: [UserProfile] {
        model.artists.filter { !appState.isBlocked($0.id) }
    }

    private var browse: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Text("Browse by Style").font(AFFont.headlineMedium).foregroundColor(.afTextPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: AFSpacing.sm)], spacing: AFSpacing.sm) {
                ForEach(ArtworkStyle.allCases) { style in
                    Button { model.filters.styles = [style] } label: {
                        Text(style.rawValue)
                            .font(AFFont.captionBold)
                            .foregroundColor(.afPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(Color.afPrimaryBg)
                            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct FiltersSheet: View {
    @Binding var filters: ArtworkFilters
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.xl) {
                    VStack(alignment: .leading, spacing: AFSpacing.sm) {
                        Text("Price Range").font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                        Text("Min: $\(Int(filters.minPrice))").font(AFFont.caption).foregroundColor(.afTextSecondary)
                        Slider(value: $filters.minPrice, in: 0...max(filters.maxPrice, 100), step: 50)
                            .tint(.afPrimary)
                            .accessibilityLabel("Minimum price")
                        Text("Max: $\(Int(filters.maxPrice))").font(AFFont.caption).foregroundColor(.afTextSecondary)
                        Slider(value: $filters.maxPrice, in: min(filters.minPrice, ArtworkFilters.priceCeiling - 100)...ArtworkFilters.priceCeiling, step: 100)
                            .tint(.afPrimary)
                            .accessibilityLabel("Maximum price")
                    }

                    pills("Style", ArtworkStyle.allCases, selection: $filters.styles, label: \.rawValue)
                    pills("Medium", ArtworkMedium.allCases, selection: $filters.mediums, label: \.rawValue)
                }
                .padding(AFSpacing.md)
            }
            .background(Color.afBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        let text = filters.text
                        filters = ArtworkFilters()
                        filters.text = text
                    }
                    .foregroundColor(.afTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(.afPrimary)
                }
            }
        }
    }

    private func pills<T: Hashable & Identifiable>(_ title: String, _ options: [T], selection: Binding<[T]>, label: KeyPath<T, String>) -> some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Text(title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
            FlowLayout(spacing: AFSpacing.xs) {
                ForEach(options) { option in
                    FilterPill(label: option[keyPath: label], isSelected: selection.wrappedValue.contains(option)) {
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
}

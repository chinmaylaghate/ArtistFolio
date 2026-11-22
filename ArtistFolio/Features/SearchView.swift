// MARK: - Search & Discover
import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var showFilters: Bool = false
    @State private var selectedArtwork: Artwork?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AFSpacing.md) {
                Text("Discover")
                    .font(AFFont.displaySmall)
                    .foregroundColor(.afTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AFSpacing.md)

                // Search bar
                HStack(spacing: AFSpacing.sm) {
                    HStack(spacing: AFSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.afTextTertiary)
                        TextField("Search artworks, artists, styles...", text: $vm.searchQuery)
                            .font(AFFont.bodyMedium)
                            .foregroundColor(.afTextPrimary)
                            .tint(Color.afAccent)
                            .focused($isSearchFocused)
                            .onSubmit { Task { await vm.search() } }

                        if !vm.searchQuery.isEmpty {
                            Button {
                                vm.searchQuery = ""
                                vm.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.afTextTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .frame(height: 44)
                    .background(Color.afSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AFRadius.lg))

                    // Filters button
                    Button {
                        showFilters = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: AFRadius.md)
                                .fill(vm.hasActiveFilters ? Color.afAccent : Color.afSurface)
                                .frame(width: 44, height: 44)

                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(vm.hasActiveFilters ? Color.afPrimary : Color.afTextSecondary)
                        }
                    }
                }
                .padding(.horizontal, AFSpacing.md)
            }
            .padding(.top, AFSpacing.sm)
            .background(Color.afBackground)

            // Sort options
            if !vm.searchQuery.isEmpty || vm.hasActiveFilters {
                SortBar(selected: $vm.sortOption)
                    .padding(.vertical, AFSpacing.xs)
                    .background(Color.afBackground)
            }

            // Content
            ScrollView(showsIndicators: false) {
                if vm.searchQuery.isEmpty && !vm.hasActiveFilters {
                    // Browse state
                    BrowseContent(vm: vm, selectedArtwork: $selectedArtwork)
                } else if vm.isLoading {
                    ProgressView()
                        .tint(Color.afAccent)
                        .padding(.top, AFSpacing.xxxl)
                } else if vm.searchResults.isEmpty {
                    EmptySearchView(query: vm.searchQuery)
                } else {
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: AFSpacing.sm) {
                        ForEach(vm.searchResults) { artwork in
                            ArtworkCard(artwork: artwork)
                                .onTapGesture { selectedArtwork = artwork }
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                    .padding(.vertical, AFSpacing.md)
                }
            }
        }
        .background(Color.afBackground)
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedArtwork) { artwork in
            ArtworkDetailView(artwork: artwork)
        }
        .sheet(isPresented: $showFilters) {
            FiltersSheet(filters: $vm.filters) {
                Task { await vm.search() }
            }
        }
        .onChange(of: vm.searchQuery) {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await vm.search()
            }
        }
    }
}

struct BrowseContent: View {
    let vm: SearchViewModel
    @Binding var selectedArtwork: Artwork?

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.lg) {
            // Trending searches
            VStack(alignment: .leading, spacing: AFSpacing.sm) {
                Text("Trending")
                    .font(AFFont.headlineMedium)
                    .foregroundColor(.afTextPrimary)
                    .padding(.horizontal, AFSpacing.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["Abstract", "Oil Painting", "Minimalist", "Portrait", "Landscape", "Watercolor"], id: \.self) { term in
                            Button {
                                vm.searchQuery = term
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                    Text(term)
                                        .font(AFFont.labelMedium)
                                }
                                .foregroundColor(.afTextSecondary)
                                .padding(.horizontal, AFSpacing.sm)
                                .padding(.vertical, AFSpacing.xs)
                                .background(Color.afSurface)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, AFSpacing.md)
                }
            }

            // Browse by Style
            VStack(alignment: .leading, spacing: AFSpacing.sm) {
                Text("Browse by Style")
                    .font(AFFont.headlineMedium)
                    .foregroundColor(.afTextPrimary)
                    .padding(.horizontal, AFSpacing.md)

                let styleColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: styleColumns, spacing: AFSpacing.sm) {
                    ForEach(ArtworkStyle.allCases.prefix(6), id: \.self) { style in
                        StyleTile(style: style) {
                            vm.filters.styles = [style]
                        }
                    }
                }
                .padding(.horizontal, AFSpacing.md)
            }

            // Recent artworks
            SectionHeader(title: "New Arrivals", actionLabel: "See All") {}
                .padding(.horizontal, AFSpacing.md)

            ArtworkGrid(artworks: Artwork.previews, isLoading: false) { artwork in
                selectedArtwork = artwork
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.bottom, AFSpacing.xl)
        }
        .padding(.top, AFSpacing.md)
    }
}

struct StyleTile: View {
    let style: ArtworkStyle
    let action: () -> Void

    var styleColor: Color {
        switch style {
        case .abstract: return Color(hex: "#E74C3C")
        case .realism: return Color(hex: "#2980B9")
        case .impressionism: return Color(hex: "#F39C12")
        case .expressionism: return Color(hex: "#8E44AD")
        case .surrealism: return Color(hex: "#1ABC9C")
        case .minimalism: return Color(hex: "#95A5A6")
        default: return Color(hex: "#27AE60")
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: AFRadius.md)
                    .fill(styleColor.opacity(0.15))
                    .frame(height: 72)

                VStack(spacing: 4) {
                    Circle()
                        .fill(styleColor.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().fill(styleColor).frame(width: 14, height: 14)
                        )

                    Text(style.rawValue)
                        .font(AFFont.captionBold)
                        .foregroundColor(.afTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

struct SortBar: View {
    @Binding var selected: ArtworkFilters.SortOption

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AFSpacing.xs) {
                ForEach(ArtworkFilters.SortOption.allCases, id: \.self) { option in
                    Button {
                        selected = option
                    } label: {
                        Text(option.rawValue)
                            .font(AFFont.labelMedium)
                            .foregroundColor(selected == option ? Color.afPrimary : Color.afTextSecondary)
                            .padding(.horizontal, AFSpacing.md)
                            .padding(.vertical, AFSpacing.xxs + 2)
                            .background(selected == option ? Color.afAccent : Color.afSurface)
                            .clipShape(Capsule())
                    }
                    .animation(.easeInOut(duration: 0.15), value: selected)
                }
            }
            .padding(.horizontal, AFSpacing.md)
        }
    }
}

struct EmptySearchView: View {
    let query: String

    var body: some View {
        VStack(spacing: AFSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50, weight: .ultraLight))
                .foregroundColor(.afTextTertiary)
                .padding(.top, AFSpacing.xxxl)

            Text("No results for \"\(query)\"")
                .font(AFFont.headlineSmall)
                .foregroundColor(.afTextPrimary)

            Text("Try different keywords or browse by style above.")
                .font(AFFont.bodySmall)
                .foregroundColor(.afTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AFSpacing.xl)
    }
}

// MARK: - Filters Sheet

struct FiltersSheet: View {
    @Binding var filters: ArtworkFilters
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AFSpacing.xl) {
                    // Price Range
                    VStack(alignment: .leading, spacing: AFSpacing.sm) {
                        Text("Price Range")
                            .font(AFFont.headlineSmall)
                            .foregroundColor(.afTextPrimary)

                        HStack {
                            Text("$\(Int(filters.minPrice))")
                            Spacer()
                            Text("$\(Int(filters.maxPrice))")
                        }
                        .font(AFFont.bodySmall)
                        .foregroundColor(.afTextSecondary)

                        // Min price slider
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Min: $\(Int(filters.minPrice))").font(AFFont.caption).foregroundColor(.afTextTertiary)
                            Slider(value: $filters.minPrice, in: 0...filters.maxPrice, step: 50)
                                .tint(Color.afAccent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max: $\(Int(filters.maxPrice))").font(AFFont.caption).foregroundColor(.afTextTertiary)
                            Slider(value: $filters.maxPrice, in: filters.minPrice...50000, step: 100)
                                .tint(Color.afAccent)
                        }
                    }

                    // Style
                    FilterSection(title: "Style") {
                        FlowLayout(spacing: AFSpacing.xs) {
                            ForEach(ArtworkStyle.allCases, id: \.self) { style in
                                FilterTogglePill(label: style.rawValue, isSelected: filters.styles.contains(style)) {
                                    if filters.styles.contains(style) {
                                        filters.styles.removeAll { $0 == style }
                                    } else {
                                        filters.styles.append(style)
                                    }
                                }
                            }
                        }
                    }

                    // Medium
                    FilterSection(title: "Medium") {
                        FlowLayout(spacing: AFSpacing.xs) {
                            ForEach(ArtworkMedium.allCases, id: \.self) { medium in
                                FilterTogglePill(label: medium.rawValue, isSelected: filters.mediums.contains(medium)) {
                                    if filters.mediums.contains(medium) {
                                        filters.mediums.removeAll { $0 == medium }
                                    } else {
                                        filters.mediums.append(medium)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AFSpacing.md)
            }
            .background(Color.afBackground)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        filters = ArtworkFilters()
                    }
                    .foregroundColor(.afTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .foregroundColor(.afAccent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct FilterSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.sm) {
            Text(title)
                .font(AFFont.headlineSmall)
                .foregroundColor(.afTextPrimary)
            content
        }
    }
}

struct FilterTogglePill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AFFont.labelMedium)
                .foregroundColor(isSelected ? Color.afPrimary : Color.afTextSecondary)
                .padding(.horizontal, AFSpacing.md)
                .padding(.vertical, AFSpacing.xxs + 2)
                .background(isSelected ? Color.afAccent : Color.afSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.afAccent : Color.afBorder, lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - ViewModel

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [Artwork] = []
    @Published var filters: ArtworkFilters = ArtworkFilters()
    @Published var sortOption: ArtworkFilters.SortOption = .newest
    @Published var isLoading: Bool = false

    var hasActiveFilters: Bool {
        !filters.styles.isEmpty || !filters.mediums.isEmpty || filters.minPrice > 0 || filters.maxPrice < 50000
    }

    private let service = ArtworkService()

    func search() async {
        guard !searchQuery.isEmpty || hasActiveFilters else { return }
        isLoading = true
        do {
            searchResults = try await service.searchArtworks(query: searchQuery, filters: filters)
        } catch {}
        isLoading = false
    }
}

#Preview {
    NavigationStack { SearchView() }
        .environmentObject(AppState())
}

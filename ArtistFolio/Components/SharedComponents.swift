import SwiftUI

struct Wordmark: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("artist").fontWeight(.bold)
            Text("folio").fontWeight(.light).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Artist Folio")
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: AFSpacing.md) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AvatarCircle: View {
    let name: String
    var url: URL?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .systemGray5))
            if let url {
                CloudImage(url: url, maxPixels: 300)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent)
            }
        }
    }
}

struct StatusBadge: View {
    let status: ArtworkStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AFSpacing.xs)
            .padding(.vertical, 3)
            .background(status == .sold ? Color.black.opacity(0.75) : Color.orange, in: Capsule())
    }
}

struct SaveButton: View {
    @EnvironmentObject var appState: AppState
    let artwork: Artwork

    private var isSaved: Bool { appState.isSaved(artwork.id) }

    var body: some View {
        Button { appState.toggleSaved(artwork.id) } label: {
            Image(systemName: isSaved ? "heart.fill" : "heart")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSaved ? Color.red : Color.primary)
                .symbolEffect(.bounce, value: isSaved)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSaved)
        .accessibilityLabel(isSaved ? "Remove \(artwork.title) from saved" : "Save \(artwork.title)")
    }
}

struct ArtworkCard: View {
    let artwork: Artwork

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Color.clear
                .aspectRatio(0.85, contentMode: .fit)
                .overlay(CloudImage(url: artwork.thumbnailURL, maxPixels: 600))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if artwork.status != .available {
                        StatusBadge(status: artwork.status).padding(AFSpacing.xs)
                    }
                }
                .overlay(alignment: .topTrailing) { SaveButton(artwork: artwork) }
                .padding(.bottom, 6)
            Text(artwork.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(artwork.artistName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(artwork.priceText)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

struct ArtworkLink: View {
    @EnvironmentObject var appState: AppState
    let artwork: Artwork

    var body: some View {
        NavigationLink(value: artwork) {
            ArtworkCard(artwork: artwork)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                appState.toggleSaved(artwork.id)
            } label: {
                Label(appState.isSaved(artwork.id) ? "Remove from Saved" : "Save",
                      systemImage: appState.isSaved(artwork.id) ? "heart.slash" : "heart")
            }
            ShareLink(item: "\(artwork.title) by \(artwork.artistName) on Artist Folio")
        }
    }
}

struct ArtworkGrid: View {
    @EnvironmentObject var appState: AppState
    let artworks: [Artwork]
    var onReachEnd: (() -> Void)?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AFSpacing.sm, alignment: .top)], spacing: AFSpacing.lg) {
            ForEach(artworks.filter(appState.isVisible)) { artwork in
                ArtworkLink(artwork: artwork)
                    .onAppear {
                        if artwork.id == artworks.last?.id { onReachEnd?() }
                    }
            }
        }
    }
}

struct ArtistRow: View {
    let profile: UserProfile

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            AvatarCircle(name: profile.displayName, url: profile.avatarURL, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.displayName).font(.body).foregroundStyle(.primary)
                if !profile.location.isEmpty {
                    Text(profile.location).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.afPrimary : Color(uiColor: .secondarySystemFill), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CheckmarkRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func artNavigation() -> some View {
        navigationDestination(for: Artwork.self) { ArtworkDetailView(artwork: $0) }
            .navigationDestination(for: ArtistLink.self) { ArtistProfileView(artistId: $0.id) }
    }
}

struct ArtistLink: Hashable {
    let id: String
}

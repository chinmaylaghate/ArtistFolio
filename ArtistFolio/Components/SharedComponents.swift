import SwiftUI

struct LogoSmall: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "rectangle.portrait.fill").font(.system(size: 14)).foregroundColor(.afPrimary)
            HStack(spacing: 0) {
                Text("artist").font(.system(size: 16, weight: .bold)).foregroundColor(.afTextPrimary)
                Text("folio").font(.system(size: 16, weight: .light)).foregroundColor(.afTextSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Artist Folio")
    }
}

struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalize = true

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(label).font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
            TextField(placeholder, text: $text)
                .font(AFFont.bodyLarge)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalize ? .sentences : .never)
                .autocorrectionDisabled(!autocapitalize)
                .padding(.horizontal, AFSpacing.md)
                .frame(height: 50)
                .background(Color.afSurface2)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
                .accessibilityLabel(label.capitalized)
        }
    }
}

struct TextAreaField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var limit = 1000

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xs) {
            Text(label).font(AFFont.sectionHeader).foregroundColor(.afTextSecondary).tracking(0.5)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AFFont.bodyMedium)
                        .foregroundColor(.afTextTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .font(AFFont.bodyMedium)
                    .frame(minHeight: 96)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(label.capitalized)
                    .onChange(of: text) { _, value in
                        if value.count > limit { text = String(value.prefix(limit)) }
                    }
            }
            .background(Color.afSurface2)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
            Text("\(text.count)/\(limit)")
                .font(AFFont.caption)
                .foregroundColor(.afTextTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct RolePill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AFFont.headlineSmall)
                .foregroundColor(isSelected ? .white : .afTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? Color.afPrimary : Color.clear)
                .clipShape(Capsule())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AvatarCircle: View {
    let name: String
    var url: URL?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Color.afPrimaryBg)
            if let url {
                CloudImage(url: url, maxPixels: 300)
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.afPrimary)
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
        VStack(spacing: AFSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 46, weight: .ultraLight))
                .foregroundColor(.afTextTertiary)
                .accessibilityHidden(true)
            Text(title).font(AFFont.headlineMedium).foregroundColor(.afTextPrimary).multilineTextAlignment(.center)
            Text(subtitle).font(AFFont.bodySmall).foregroundColor(.afTextSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(AFOutlineButtonStyle())
                    .frame(maxWidth: 220)
                    .padding(.top, AFSpacing.xs)
            }
        }
        .padding(AFSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct StatusBadge: View {
    let status: ArtworkStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status == .sold ? Color.afTextPrimary : Color.afOrange)
            .clipShape(Capsule())
    }
}

struct ArtworkCard: View {
    @EnvironmentObject var appState: AppState
    let artwork: Artwork

    var body: some View {
        VStack(alignment: .leading, spacing: AFSpacing.xxs) {
            Color.clear
                .aspectRatio(0.85, contentMode: .fit)
                .overlay(CloudImage(url: artwork.thumbnailURL, maxPixels: 600))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                .overlay(alignment: .topLeading) {
                    if artwork.status != .available {
                        StatusBadge(status: artwork.status).padding(AFSpacing.xs)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button { appState.toggleSaved(artwork.id) } label: {
                        Image(systemName: appState.isSaved(artwork.id) ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(appState.isSaved(artwork.id) ? .afError : .afTextPrimary)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.isSaved(artwork.id) ? "Remove \(artwork.title) from saved" : "Save \(artwork.title)")
                }
            Text(artwork.title).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary).lineLimit(1)
                .padding(.top, AFSpacing.xxs)
            Text(artwork.artistName).font(AFFont.caption).foregroundColor(.afTextSecondary).lineLimit(1)
            Text(artwork.priceText).font(AFFont.headlineSmall).foregroundColor(.afPrimary)
        }
    }
}

struct ArtworkGrid: View {
    @EnvironmentObject var appState: AppState
    let artworks: [Artwork]
    var onReachEnd: (() -> Void)?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 16) {
            ForEach(artworks.filter(appState.isVisible)) { artwork in
                NavigationLink(value: artwork) {
                    ArtworkCard(artwork: artwork)
                }
                .buttonStyle(.plain)
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
            AvatarCircle(name: profile.displayName, url: profile.avatarURL, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName).font(AFFont.headlineSmall).foregroundColor(.afTextPrimary)
                if !profile.location.isEmpty {
                    Text(profile.location).font(AFFont.caption).foregroundColor(.afTextSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.afTextTertiary)
        }
        .padding(AFSpacing.sm)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AFRadius.md).stroke(Color.afBorder, lineWidth: 1))
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

struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AFFont.labelMedium)
                .foregroundColor(isSelected ? .white : .afTextSecondary)
                .padding(.horizontal, AFSpacing.md)
                .padding(.vertical, AFSpacing.xs)
                .background(isSelected ? Color.afPrimary : Color.afSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.afBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
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

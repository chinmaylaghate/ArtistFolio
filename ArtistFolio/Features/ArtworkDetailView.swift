// MARK: - Artwork Detail
import SwiftUI
import RealityKit // for AR

struct ArtworkDetailView: View {
    let artwork: Artwork
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedImageIndex: Int = 0
    @State private var showARPreview: Bool = false
    @State private var showBuySheet: Bool = false
    @State private var showCertificate: Bool = false
    @State private var showArtistProfile: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var isInCart: Bool = false
    @State private var addedToCart: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Image Gallery
                ArtworkImageGallery(
                    imageURLs: artwork.imageURLs.isEmpty ? ["placeholder"] : artwork.imageURLs,
                    selectedIndex: $selectedImageIndex,
                    colorPalette: artwork.colorPalette
                )

                // Action chips (AR, Share, Save)
                HStack(spacing: AFSpacing.sm) {
                    ActionChip(icon: "arkit", label: "AR Preview") {
                        showARPreview = true
                    }

                    ActionChip(icon: "square.and.arrow.up", label: "Share") {
                        showShareSheet = true
                    }

                    ActionChip(
                        icon: appState.isFavorite(artworkId: artwork.id) ? "heart.fill" : "heart",
                        label: appState.isFavorite(artworkId: artwork.id) ? "Saved" : "Save",
                        tint: appState.isFavorite(artworkId: artwork.id) ? .afError : nil
                    ) {
                        appState.toggleFavorite(artworkId: artwork.id)
                    }

                    if artwork.hasCertificate {
                        ActionChip(icon: "checkmark.seal", label: "Certificate", tint: .afAccent) {
                            showCertificate = true
                        }
                    }
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.vertical, AFSpacing.md)

                // Main content
                VStack(alignment: .leading, spacing: AFSpacing.lg) {
                    // Title & Price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(artwork.title)
                                .font(AFFont.displaySmall)
                                .foregroundColor(.afTextPrimary)

                            Text(artwork.medium.rawValue + " · " + String(artwork.year))
                                .font(AFFont.bodySmall)
                                .foregroundColor(.afTextSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(Int(artwork.price))")
                                .font(AFFont.priceLarge)
                                .foregroundStyle(AFGradient.primaryGold)

                            if let original = artwork.originalPrice {
                                Text("$\(Int(original))")
                                    .font(AFFont.bodySmall)
                                    .foregroundColor(.afTextTertiary)
                                    .strikethrough()
                            }
                        }
                    }

                    // Stats row
                    HStack(spacing: AFSpacing.lg) {
                        StatBadge(icon: "eye", value: "\(artwork.viewsCount)", label: "views")
                        StatBadge(icon: "heart", value: "\(artwork.likesCount)", label: "likes")
                        StatBadge(icon: "ruler", value: artwork.dimensions.displayString, label: "size")
                    }

                    Divider().background(Color.afBorder)

                    // Artist info
                    Button {
                        showArtistProfile = true
                    } label: {
                        HStack(spacing: AFSpacing.md) {
                            Circle()
                                .fill(Color.afSurface2)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Text(artwork.artistName.prefix(1))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.afAccent)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(artwork.artistName)
                                    .font(AFFont.headlineSmall)
                                    .foregroundColor(.afTextPrimary)
                                Text("View profile")
                                    .font(AFFont.caption)
                                    .foregroundColor(.afTextSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.afTextTertiary)
                        }
                    }

                    Divider().background(Color.afBorder)

                    // Description
                    VStack(alignment: .leading, spacing: AFSpacing.xs) {
                        Text("About this piece")
                            .font(AFFont.headlineSmall)
                            .foregroundColor(.afTextPrimary)

                        Text(artwork.description)
                            .font(AFFont.bodyMedium)
                            .foregroundColor(.afTextSecondary)
                            .lineSpacing(4)
                    }

                    // Details table
                    ArtworkDetailsTable(artwork: artwork)

                    // Tags
                    if !artwork.tags.isEmpty {
                        VStack(alignment: .leading, spacing: AFSpacing.xs) {
                            Text("Tags")
                                .font(AFFont.headlineSmall)
                                .foregroundColor(.afTextPrimary)

                            FlowLayout(spacing: AFSpacing.xs) {
                                ForEach(artwork.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(AFFont.labelMedium)
                                        .foregroundColor(.afAccent)
                                        .padding(.horizontal, AFSpacing.sm)
                                        .padding(.vertical, AFSpacing.xxs)
                                        .background(Color.afAccent.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Color palette
                    if !artwork.colorPalette.isEmpty {
                        VStack(alignment: .leading, spacing: AFSpacing.xs) {
                            Text("Color Palette")
                                .font(AFFont.headlineSmall)
                                .foregroundColor(.afTextPrimary)

                            HStack(spacing: AFSpacing.xs) {
                                ForEach(artwork.colorPalette, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(Color.afBorder, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AFSpacing.md)
                .padding(.bottom, 120) // room for buy button
            }
        }
        .background(Color.afBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.afTextPrimary)
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Buy / Add to Cart bar
            BuyBar(artwork: artwork, addedToCart: $addedToCart) {
                if artwork.status == .available {
                    showBuySheet = true
                }
            } addToCart: {
                appState.addToCart(artwork)
                withAnimation { addedToCart = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    addedToCart = false
                }
            }
        }
        .sheet(isPresented: $showARPreview) {
            ARPreviewView(artwork: artwork)
        }
        .sheet(isPresented: $showBuySheet) {
            CheckoutView(artwork: artwork)
        }
        .sheet(isPresented: $showCertificate) {
            CertificateView(artwork: artwork)
        }
        .navigationDestination(isPresented: $showArtistProfile) {
            ArtistProfileView(artistId: artwork.artistId)
        }
    }
}

// MARK: - Image Gallery

struct ArtworkImageGallery: View {
    let imageURLs: [String]
    @Binding var selectedIndex: Int
    let colorPalette: [String]

    var body: some View {
        ZStack {
            // Main image
            TabView(selection: $selectedIndex) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    ZStack {
                        // Color placeholder
                        Rectangle()
                            .fill(Color.afSurface)
                            .overlay(
                                LinearGradient(
                                    colors: colorPalette.prefix(2).map { Color(hex: $0) } + [Color.afSurface],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ).opacity(0.7)
                            )

                        Image(systemName: "photo.artframe")
                            .font(.system(size: 60, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 380)

            // Bottom gradient
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.afBackground.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
            }
        }
        .frame(height: 380)

        // Thumbnail strip
        if imageURLs.count > 1 {
            HStack(spacing: AFSpacing.xs) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.afSurface2)
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(index == selectedIndex ? Color.afAccent : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture { selectedIndex = index }
                }
            }
            .padding(.horizontal, AFSpacing.md)
            .padding(.vertical, AFSpacing.sm)
        }
    }
}

// MARK: - Action Chip

struct ActionChip: View {
    let icon: String
    let label: String
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(AFFont.captionBold)
            }
            .foregroundColor(tint ?? .afTextSecondary)
            .padding(.horizontal, AFSpacing.sm)
            .padding(.vertical, AFSpacing.xs)
            .background((tint ?? Color.afTextSecondary).opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.afTextTertiary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(AFFont.captionBold)
                    .foregroundColor(.afTextPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.afTextTertiary)
            }
        }
    }
}

// MARK: - Artwork Details Table

struct ArtworkDetailsTable: View {
    let artwork: Artwork

    var rows: [(String, String)] {
        [
            ("Medium", artwork.medium.rawValue),
            ("Style", artwork.style.rawValue),
            ("Dimensions", artwork.dimensions.displayString),
            ("Year", String(artwork.year)),
            ("Certificate", artwork.hasCertificate ? "Blockchain verified" : "Not included"),
            ("Status", artwork.status.rawValue.capitalized),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .font(AFFont.bodySmall)
                        .foregroundColor(.afTextSecondary)
                    Spacer()
                    Text(row.1)
                        .font(AFFont.bodySmall)
                        .foregroundColor(.afTextPrimary)
                }
                .padding(.vertical, AFSpacing.sm)

                if row.0 != rows.last?.0 {
                    Divider().background(Color.afBorder)
                }
            }
        }
        .padding(AFSpacing.md)
        .background(Color.afSurface)
        .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
    }
}

// MARK: - Buy Bar

struct BuyBar: View {
    let artwork: Artwork
    @Binding var addedToCart: Bool
    let onBuy: () -> Void
    let addToCart: () -> Void

    var body: some View {
        HStack(spacing: AFSpacing.sm) {
            // Add to cart
            Button(action: addToCart) {
                ZStack {
                    Image(systemName: addedToCart ? "checkmark" : "bag.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(addedToCart ? .afSuccess : .afTextPrimary)
                }
                .frame(width: 52, height: 52)
                .background(Color.afSurface)
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AFRadius.md)
                        .stroke(addedToCart ? Color.afSuccess : Color.afBorder, lineWidth: 1)
                )
            }

            // Buy now
            Button(action: onBuy) {
                HStack {
                    Image(systemName: "creditcard")
                        .font(.system(size: 16))
                    Text(artwork.status == .available ? "Buy Now · $\(Int(artwork.price))" : artwork.status.rawValue.capitalized)
                        .font(AFFont.headlineSmall)
                }
                .foregroundColor(artwork.status == .available ? Color.afPrimary : Color.afTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(artwork.status == .available ? AFGradient.primaryGold : LinearGradient(colors: [Color.afSurface], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md))
            }
            .disabled(artwork.status != .available)
        }
        .padding(.horizontal, AFSpacing.md)
        .padding(.vertical, AFSpacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.afSurface.opacity(0.9))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
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
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Certificate View

struct CertificateView: View {
    let artwork: Artwork
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: AFSpacing.lg) {
            HStack {
                Text("Certificate of Authenticity")
                    .font(AFFont.headlineLarge)
                    .foregroundColor(.afTextPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.afTextTertiary)
                }
            }
            .padding(.top, AFSpacing.xl)

            // Certificate card
            VStack(spacing: AFSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AFGradient.primaryGold)

                Text(artwork.title)
                    .font(AFFont.displaySmall)
                    .foregroundColor(.afTextPrimary)
                    .multilineTextAlignment(.center)

                Text("by \(artwork.artistName)")
                    .font(AFFont.bodyMedium)
                    .foregroundColor(.afTextSecondary)

                Divider().background(Color.afBorder)

                if let hash = artwork.certificateHash {
                    VStack(spacing: 4) {
                        Text("Blockchain Hash")
                            .font(AFFont.captionBold)
                            .foregroundColor(.afTextTertiary)
                        Text(hash)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.afAccent)
                            .multilineTextAlignment(.center)
                    }
                }

                Text("This certificate is permanently stored on the blockchain and transfers with the artwork.")
                    .font(AFFont.caption)
                    .foregroundColor(.afTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AFSpacing.xl)
            .background(Color.afSurface)
            .clipShape(RoundedRectangle(cornerRadius: AFRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: AFRadius.xl)
                    .stroke(Color.afAccent.opacity(0.3), lineWidth: 1)
            )

            Spacer()
        }
        .padding(.horizontal, AFSpacing.lg)
        .background(Color.afBackground.ignoresSafeArea())
    }
}

// MARK: - AR Preview View (stub - implement with RealityKit)

struct ARPreviewView: View {
    let artwork: Artwork
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // ARViewContainer() would go here
            // Using RealityKit ARView wrapped in UIViewRepresentable
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .padding()
                    Spacer()
                }
                Spacer()

                VStack(spacing: AFSpacing.sm) {
                    Image(systemName: "arkit")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Point your camera at a wall")
                        .font(AFFont.headlineSmall)
                        .foregroundColor(.white)

                    Text("AR Preview requires a physical device with LiDAR or ARKit support.")
                        .font(AFFont.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AFSpacing.xl)
                }
                .padding(.bottom, AFSpacing.xxxl)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArtworkDetailView(artwork: Artwork.previews[0])
    }
    .environmentObject(AppState())
}

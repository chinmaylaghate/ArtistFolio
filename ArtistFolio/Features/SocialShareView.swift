import LinkPresentation
import SwiftUI
import UIKit

enum ShareFormat: String, CaseIterable, Identifiable {
    case story, post

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .post: return CGSize(width: 1080, height: 1350)
        }
    }

    // Story insets keep content clear of the controls social apps overlay at the top and bottom.
    var insets: EdgeInsets {
        switch self {
        case .story: return EdgeInsets(top: 230, leading: 72, bottom: 290, trailing: 72)
        case .post: return EdgeInsets(top: 64, leading: 64, bottom: 64, trailing: 64)
        }
    }
}

enum ShareSubject {
    case artwork(Artwork, preferredImage: URL?)
    case artist(UserProfile)

    var title: String {
        switch self {
        case .artwork(let artwork, _): return artwork.title
        case .artist(let profile): return profile.displayName
        }
    }
}

enum ShareFormatter {
    static let appStoreLink = "https://apps.apple.com/app/artistfolio/id6838094249"

    /// Opens the piece or profile in the app, or the website (with an App Store link) without it.
    static func link(for subject: ShareSubject) -> URL {
        switch subject {
        case .artwork(let artwork, _): return AppLink.artwork(id: artwork.id).url
        case .artist(let profile): return AppLink.artist(id: profile.id).url
        }
    }

    static func caption(for subject: ShareSubject) -> String {
        switch subject {
        case .artwork(let artwork, _):
            return "\(artwork.title) by \(artwork.artistName) on Artist Folio\n\(link(for: subject).absoluteString)"
        case .artist(let profile):
            return "See \(profile.displayName)'s work on Artist Folio\n\(link(for: subject).absoluteString)"
        }
    }

    static func displayTags(_ tags: [String], limit: Int = 3) -> [String] {
        var seen = Set<String>()
        var output: [String] = []
        for tag in tags {
            let clean = tag.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "#")))
            guard !clean.isEmpty, seen.insert(clean.lowercased()).inserted else { continue }
            output.append(clean)
            if output.count == limit { break }
        }
        return output
    }

    // Instagram and similar extensions reject mixed image and text items, so they receive only the image.
    static func caption(_ caption: String, for activityType: UIActivity.ActivityType?) -> String? {
        guard let activityType, activityType.rawValue.hasPrefix("com.apple.UIKit.activity.") else { return nil }
        return caption
    }
}

private struct ShareCardAssets {
    var hero: UIImage?
    var avatar: UIImage?
    var mosaic: [UIImage] = []
    var artworkCount = 0
}

private final class ShareImageItem: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { image }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

private final class ShareCaptionItem: NSObject, UIActivityItemSource {
    private let caption: String

    init(caption: String) {
        self.caption = caption
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { caption }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        ShareFormatter.caption(caption, for: activityType)
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let title: String
    let caption: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [ShareImageItem(image: image, title: title), ShareCaptionItem(caption: caption)],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in dismiss() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SocialShareSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let subject: ShareSubject

    @State private var format: ShareFormat = .story
    @State private var includePrice = false
    @State private var assets: ShareCardAssets?
    @State private var rendered: UIImage?
    @State private var showActivity = false
    @State private var didFail = false

    /// Price-on-request pieces have no price to show, so the toggle is hidden.
    private var canShowPrice: Bool {
        if case .artwork(let artwork, _) = subject { return !artwork.priceOnRequest }
        return false
    }

    private var renderKey: String {
        "\(format.rawValue)-\(includePrice)-\(assets != nil)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AFSpacing.md) {
                Picker("Format", selection: $format) {
                    ForEach(ShareFormat.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if canShowPrice {
                    Toggle("Show price", isOn: $includePrice)
                }

                shareButton
            }
            .padding(AFSpacing.md)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadAssets() }
        .task(id: renderKey) { render() }
        .sheet(isPresented: $showActivity) {
            if let rendered {
                ActivityShareSheet(image: rendered, title: subject.title, caption: ShareFormatter.caption(for: subject))
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if didFail {
            EmptyStateView(icon: "exclamationmark.triangle", title: "Couldn't Prepare Image", subtitle: "Check your connection and try again.", actionTitle: "Try Again") {
                didFail = false
                Task { await loadAssets() }
            }
        } else if let rendered {
            Image(uiImage: rendered)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: AFRadius.md, style: .continuous))
                .accessibilityLabel("Preview of \(format.label.lowercased()) image for \(subject.title)")
        } else {
            ProgressView("Preparing image")
        }
    }

    private var shareButton: some View {
        Button { showActivity = true } label: {
            Label("Share \(format.label)", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .primaryAction()
        .disabled(rendered == nil)
    }

    private func loadAssets() async {
        switch subject {
        case .artwork(let artwork, let preferredImage):
            var url = preferredImage
            if url == nil {
                url = (try? await appState.backend.fullImages(artworkID: artwork.id))?.first ?? artwork.thumbnailURL
            }
            guard let hero = await Self.image(at: url, maxPixels: 1600) else {
                didFail = true
                return
            }
            assets = ShareCardAssets(hero: hero)
        case .artist(let profile):
            guard let artworks = try? await appState.backend.artworks(ownerID: profile.id) else {
                didFail = true
                return
            }
            var mosaic: [UIImage] = []
            for artwork in artworks.prefix(4) {
                if let image = await Self.image(at: artwork.thumbnailURL, maxPixels: 700) {
                    mosaic.append(image)
                }
            }
            let avatar = await Self.image(at: profile.avatarURL, maxPixels: 400)
            assets = ShareCardAssets(avatar: avatar, mosaic: mosaic, artworkCount: artworks.count)
        }
    }

    private static func image(at url: URL?, maxPixels: Int) async -> UIImage? {
        guard let url else { return nil }
        return await Task.detached(priority: .userInitiated) {
            ImageProcessor.downsample(url, maxPixels: maxPixels)
        }.value
    }

    private func render() {
        guard let assets else { return }
        let renderer = ImageRenderer(content: card(assets)
            .environment(\.colorScheme, .dark)
            .dynamicTypeSize(.large))
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(format.size)

        guard let image = renderer.uiImage else {
            didFail = true
            return
        }
        rendered = image
    }

    @ViewBuilder
    private func card(_ assets: ShareCardAssets) -> some View {
        switch subject {
        case .artwork(let artwork, _):
            if let hero = assets.hero {
                ArtworkShareCard(artwork: artwork, image: hero, format: format, includePrice: includePrice)
            }
        case .artist(let profile):
            ArtistShareCard(profile: profile, avatar: assets.avatar, mosaic: assets.mosaic, artworkCount: assets.artworkCount, format: format)
        }
    }
}

private struct ShareCardBackground: View {
    let image: UIImage?
    let format: ShareFormat

    var body: some View {
        ZStack {
            Color(white: 0.08)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: format.size.width, height: format.size.height)
                    .scaleEffect(1.2)
                    .blur(radius: 48)
                Color.black.opacity(0.62)
            }
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
    }
}

private struct ShareWatermark: View {
    var body: some View {
        Image("LogoMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: 112)
            .foregroundStyle(.white)
    }
}

private struct ArtworkShareCard: View {
    let artwork: Artwork
    let image: UIImage
    let format: ShareFormat
    let includePrice: Bool

    private var statusColor: Color {
        switch artwork.status {
        case .available: return .white
        case .reserved: return Color(hex: "F2C14E")
        case .sold: return Color(hex: "FF8A7A")
        }
    }

    var body: some View {
        ZStack {
            ShareCardBackground(image: image, format: format)
            VStack(alignment: .leading, spacing: 40) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black.opacity(0.5), radius: 28, y: 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                details
            }
            .padding(format.insets)
        }
        .frame(width: format.size.width, height: format.size.height)
        .foregroundStyle(.white)
    }

    private var details: some View {
        HStack(alignment: .bottom, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 18) {
                    Text(artwork.status.label)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(statusColor, in: Capsule())
                    if includePrice && !artwork.priceOnRequest {
                        Text(artwork.priceText).font(.system(size: 38, weight: .semibold))
                    }
                }
                Text(artwork.title)
                    .font(.system(size: 60, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("by \(artwork.artistName)")
                    .font(.system(size: 36, weight: .medium))
                    .lineLimit(1)
                Text("\(artwork.medium.rawValue) · \(String(artwork.year))")
                    .font(.system(size: 30))
                    .lineLimit(1)
                let tags = ShareFormatter.displayTags(artwork.tags)
                if !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.system(size: 30, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ShareWatermark()
        }
    }
}

private struct ArtistShareCard: View {
    let profile: UserProfile
    let avatar: UIImage?
    let mosaic: [UIImage]
    let artworkCount: Int
    let format: ShareFormat

    private var rows: [[UIImage]] {
        stride(from: 0, to: mosaic.count, by: 2).map { Array(mosaic[$0..<min($0 + 2, mosaic.count)]) }
    }

    private var subtitle: String {
        let works = "\(artworkCount) \(artworkCount == 1 ? "artwork" : "artworks")"
        return profile.location.isEmpty ? works : "\(profile.location) · \(works)"
    }

    var body: some View {
        ZStack {
            ShareCardBackground(image: mosaic.first, format: format)
            VStack(alignment: .leading, spacing: 40) {
                header
                if rows.isEmpty {
                    Spacer()
                } else {
                    VStack(spacing: 16) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(spacing: 16) {
                                ForEach(rows[index].indices, id: \.self) { item in
                                    Color.clear
                                        .overlay(Image(uiImage: rows[index][item]).resizable().scaledToFill())
                                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                HStack(alignment: .bottom) {
                    if profile.acceptsCommissions {
                        Text("Open to commissions")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(.white, in: Capsule())
                    }
                    Spacer()
                    ShareWatermark()
                }
            }
            .padding(format.insets)
        }
        .frame(width: format.size.width, height: format.size.height)
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 32) {
            ZStack {
                Circle().fill(Color(white: 0.25))
                if let avatar {
                    Image(uiImage: avatar).resizable().scaledToFill()
                } else {
                    Text(String(profile.displayName.prefix(1)).uppercased())
                        .font(.system(size: 72, weight: .medium, design: .rounded))
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 4))

            VStack(alignment: .leading, spacing: 8) {
                Text(profile.displayName)
                    .font(.system(size: 60, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 32, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

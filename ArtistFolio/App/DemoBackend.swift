import CloudKit
import SwiftUI

final class DemoBackend: ArtBackend {
    private var userID: String?
    private var profiles: [String: UserProfile] = [:]
    private var items: [Artwork] = []
    private var reviewStore: [Review] = []
    private var state = UserLibrary()
    private(set) var reports: [(ReportTarget, String, ReportReason)] = []
    var failsIdentityLoads = false
    var failsProfileLoads = false
    var failsArtworkLoads = false

    init(mode: String) {
        var sofia = UserProfile(id: "artist-sofia", displayName: "Sofia Martinez", bio: "Abstract painter working in acrylic and mixed media.", role: .artist, location: "Barcelona, Spain", website: "example.com", instagramHandle: "sofia.paints", contactEmail: "sofia@example.com", phone: "+34 612 345 678", whatsapp: "+34 612 345 678", acceptsCommissions: true)
        sofia.avatarURL = Self.avatar(initials: "SM", red: 0.72, green: 0.33, blue: 0.18, cacheKey: "demo-avatar-sofia")
        var james = UserProfile(id: "artist-james", displayName: "James Thornton", bio: "Seascapes and quiet countryside in oil and watercolor.", role: .artist, location: "Cornwall, UK", instagramHandle: "james.tides", contactEmail: "james@example.com")
        james.avatarURL = Self.avatar(initials: "JT", red: 0.15, green: 0.42, blue: 0.58, cacheKey: "demo-avatar-james")
        var elena = UserProfile(id: "artist-elena", displayName: "Elena Rossi", bio: "Classical painter inspired by the old masters.", role: .artist, location: "Florence, Italy", instagramHandle: "elena.atelier", contactEmail: "elena@example.com", acceptsCommissions: true)
        elena.avatarURL = Self.avatar(initials: "ER", red: 0.55, green: 0.42, blue: 0.20, cacheKey: "demo-avatar-elena")
        profiles = [sofia.id: sofia, james.id: james, elena.id: elena]
        func cm(_ width: Double, _ height: Double) -> ArtworkDimensions { ArtworkDimensions(width: width, height: height, unit: "cm") }
        items = [
            Self.art("art-2", sofia, "Amber Reflections", 1450, .acrylic, .abstract, cm(60, 90)),
            Self.art("art-10", elena, "Flowers on a Ledge", 3600, .oilOnCanvas, .stillLife, cm(62, 80)),
            Self.art("art-12", james, "Ocean Silence", 850, .acrylic, .minimalism, cm(60, 60)),
            Self.art("art-15", elena, "The Bend in the Road", 2750, .oilOnCanvas, .impressionism, cm(65, 82)),
            Self.art("art-16", sofia, "Blue Horizon Study", 1200, .acrylic, .abstract, cm(122, 80)),
            Self.art("art-7", james, "The Cannon Shot", 2900, .oilOnCanvas, .realism, cm(64, 76)),
            Self.art("art-9", elena, "Summer Garden", 1250, .oilOnCanvas, .impressionism, cm(72, 60)),
            Self.art("art-3", james, "The Village Lane", 2200, .watercolor, .landscape, cm(62, 50)),
            Self.art("art-17", sofia, "Dusk Layers", 2400, .mixedMedia, .abstract, cm(60, 80)),
            Self.art("art-1", elena, "Heavenly Assembly", 0, .oilOnCanvas, .realism, cm(80, 100), priceOnRequest: true),
            Self.art("art-4", james, "Lakeside Morning", 1800, .watercolor, .landscape, cm(92, 70)),
            Self.art("art-13", sofia, "White Gesture", 450, .acrylic, .minimalism, cm(40, 60)),
            Self.art("art-5", elena, "Cathedral Light", 3200, .oilOnCanvas, .realism, cm(90, 70)),
            Self.art("art-8", elena, "Gathering Wildflowers", 980, .watercolor, .impressionism, cm(40, 60)),
            Self.art("art-11", sofia, "Garden Fragments", 780, .acrylic, .contemporary, cm(60, 80)),
            Self.art("art-14", james, "Fantails", 380, .watercolor, .realism, cm(32, 40), status: .sold),
            Self.art("art-6", elena, "The Gothic Porch", 650, .watercolor, .realism, cm(39, 60))
        ]
        if let index = items.firstIndex(where: { $0.id == "art-2" }) {
            items[index].careNote = "Varnished with a UV gloss. Wipe the frame only; the surface needs no cleaning."
        }
        for (id, views, likes) in [("art-2", 1830, 142), ("art-16", 210, 18), ("art-10", 640, 37), ("art-12", 12, 2)] {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].viewCount = views
                items[index].likeCount = likes
            }
        }
        profiles[sofia.id]?.followerCount = 2340
        profiles[elena.id]?.followerCount = 48
        profiles[james.id]?.followerCount = 3
        for id in ["art-2", "art-16", "art-17"] {
            if let index = items.firstIndex(where: { $0.id == id }) { items[index].series = "Autumn Water" }
        }
        func review(_ artist: String, _ name: String, _ rating: Int, _ relationship: ReviewRelationship, _ text: String, daysAgo: Double) -> Review {
            Review(artistID: artist, reviewerID: "reviewer-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))", reviewerName: name, rating: rating, text: text, relationship: relationship, createdAt: Date().addingTimeInterval(-daysAgo * 86_400))
        }
        reviewStore = [
            review(sofia.id, "Daniel Okafor", 5, .bought, "Amber Reflections looks even better in person. Sofia packed it beautifully and kept me updated the whole way.", daysAgo: 3),
            review(sofia.id, "Priya Nair", 5, .commissioned, "I asked for a piece in blues for our hallway. She sent sketches first and the final painting is exactly what we hoped for.", daysAgo: 12),
            review(sofia.id, "Tom Becker", 4, .met, "Lovely to meet her at the Barcelona open studios. Friendly, and happy to talk about her process.", daysAgo: 30),
            review(sofia.id, "Lena Fischer", 5, .bought, "Quick replies, fair price and a beautiful painting.", daysAgo: 45),
            review(elena.id, "Marco Bianchi", 5, .bought, "The still life is stunning. Careful packing and a handwritten note.", daysAgo: 8),
            review(elena.id, "Sarah Lewis", 4, .met, "Met Elena at a fair in Florence. Her technique up close is remarkable.", daysAgo: 20)
        ]
        switch mode {
        case "artist": userID = sofia.id
        case "collector":
            userID = "collector-maya"
            var maya = UserProfile(id: "collector-maya", displayName: "Maya Chen", role: .collector, location: "Toronto, Canada")
            maya.avatarURL = Self.avatar(initials: "MC", red: 0.38, green: 0.22, blue: 0.65, cacheKey: "demo-avatar-maya")
            profiles["collector-maya"] = maya
            state.saved = ["art-2"]
            state.following = [james.id]
        case "new": userID = "new-user"
        default: userID = nil
        }
    }

    private static func art(_ id: String, _ artist: UserProfile, _ title: String, _ price: Double, _ medium: ArtworkMedium, _ style: ArtworkStyle, _ size: ArtworkDimensions, status: ArtworkStatus = .available, priceOnRequest: Bool = false) -> Artwork {
        var artwork = Artwork(id: id, artistId: artist.id, artistName: artist.displayName, title: title, details: "An original work exploring color, light, and texture.", price: price, status: status, medium: medium, style: style, dimensions: size, year: 2026, tags: [style.rawValue.lowercased()], thumbnailURL: image(key: id, aspect: size.aspectRatio))
        artwork.priceOnRequest = priceOnRequest
        if priceOnRequest { artwork.price = 0 }
        return artwork
    }

    /// Renders the bundled painting `demo_art_N` for `art-N`, aspect-filled to the artwork's dimensions.
    private static func image(key: String, aspect: CGFloat) -> URL? {
        let cacheKey = "demo-v4-\(key)"
        if let cached = ImageStore.cachedFile(key: cacheKey) { return cached }
        let name = key.replacingOccurrences(of: "art-", with: "demo_art_")
        guard let src = UIImage(named: name) else { return nil }
        let size = aspect >= 1 ? CGSize(width: 1400, height: 1400 / aspect) : CGSize(width: 1400 * aspect, height: 1400)
        let scale = max(size.width / src.size.width, size.height / src.size.height)
        let drawn = CGSize(width: src.size.width * scale, height: src.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            src.draw(in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2, width: drawn.width, height: drawn.height))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.85), let temp = try? ImageStore.temporaryFile(data) else { return nil }
        defer { try? FileManager.default.removeItem(at: temp) }
        return ImageStore.cacheFile(temp, key: cacheKey)
    }

    private static func avatar(initials: String, red: CGFloat, green: CGFloat, blue: CGFloat, cacheKey: String) -> URL? {
        let size = CGSize(width: 200, height: 200)
        let rendered = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: red, green: green, blue: blue, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 72, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let str = initials as NSString
            let sz = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: (size.width - sz.width) / 2, y: (size.height - sz.height) / 2), withAttributes: attrs)
        }
        guard let data = rendered.jpegData(compressionQuality: 0.9), let temp = try? ImageStore.temporaryFile(data) else { return nil }
        defer { try? FileManager.default.removeItem(at: temp) }
        return ImageStore.cacheFile(temp, key: cacheKey)
    }

    func currentUserID() async throws -> String? {
        if failsIdentityLoads { throw CKError(.networkFailure) }
        return userID
    }

    func resetIdentity() async {}

    func profile(ownerID: String) async throws -> UserProfile? {
        if failsProfileLoads { throw CKError(.networkFailure) }
        return profiles[ownerID]
    }

    func switchAccount(to id: String?) {
        userID = id
        state = UserLibrary()
    }

    func saveProfile(_ profile: UserProfile, avatar: Data?) async throws -> UserProfile {
        guard let userID else { throw AppError.iCloudRequired }
        guard ContentFilter.isAllowed(profile.displayName, profile.bio, profile.location) else { throw AppError.objectionableContent }
        var output = profile
        output.id = userID
        profiles[userID] = output
        return output
    }

    func searchProfiles(text: String) async throws -> [UserProfile] {
        let words = SearchTokens.words(in: text)
        return profiles.values.filter { profile in
            let tokens = SearchTokens.make(from: [profile.displayName, profile.location])
            return profile.role == .artist && !words.isEmpty && words.allSatisfy(tokens.contains)
        }
    }

    func artworks(filters: ArtworkFilters, cursor: CKQueryOperation.Cursor?) async throws -> ArtworkPage {
        if failsArtworkLoads { throw CKError(.networkFailure) }
        let words = SearchTokens.words(in: filters.text)
        var output = items.filter { art in
            let tokens = SearchTokens.make(from: [art.title, art.medium.rawValue, art.style.rawValue, art.series] + art.tags)
            return words.allSatisfy(tokens.contains)
                && (filters.styles.isEmpty || filters.styles.contains(art.style))
                && (filters.mediums.isEmpty || filters.mediums.contains(art.medium))
                && (filters.sizes.isEmpty || filters.sizes.contains(art.dimensions.sizeClass))
                && filters.matchesPrice(art)
        }
        switch filters.sortBy {
        case .newest: break
        case .priceAsc: output.sort { $0.price < $1.price }
        case .priceDesc: output.sort { $0.price > $1.price }
        }
        return ArtworkPage(items: filters.ordered(output), cursor: nil)
    }

    func artworks(ownerID: String) async throws -> [Artwork] { items.filter { $0.artistId == ownerID } }
    func artworks(ids: [String]) async throws -> [Artwork] { items.filter { ids.contains($0.id) } }
    func backfillSizeClasses() async throws -> Int { 0 }
    func recordView(artworkID: String) async throws {}
    func mirrorPublicLibrary(_ library: UserLibrary) async throws {}
    func refreshCounts() async throws {}

    func reviews(artistID: String) async throws -> [Review] {
        reviewStore.filter { $0.artistID == artistID }.sorted { $0.createdAt > $1.createdAt }
    }

    func saveReview(_ review: Review) async throws -> Review {
        guard let userID else { throw AppError.iCloudRequired }
        guard userID != review.artistID else { throw AppError.cannotReviewSelf }
        guard ContentFilter.isAllowed(review.text) else { throw AppError.objectionableContent }
        var saved = review
        saved.reviewerID = userID
        saved.reviewerName = profiles[userID]?.displayName ?? "You"
        saved.text = String(review.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Review.maxTextLength))
        saved.createdAt = Date()
        reviewStore.removeAll { $0.id == saved.id }
        reviewStore.append(saved)
        return saved
    }

    func deleteReview(artistID: String) async throws {
        guard let userID else { throw AppError.iCloudRequired }
        reviewStore.removeAll { $0.reviewerID == userID && $0.artistID == artistID }
    }
    func fullImages(artworkID: String) async throws -> [URL] {
        items.first { $0.id == artworkID }?.thumbnailURL.map { [$0] } ?? []
    }

    func saveArtwork(_ artwork: Artwork, images: [ProcessedImage]?) async throws -> Artwork {
        guard let userID, let profile = profiles[userID] else { throw AppError.iCloudRequired }
        guard ContentFilter.isAllowed([artwork.title, artwork.details, artwork.careNote, artwork.series] + artwork.tags) else { throw AppError.objectionableContent }
        guard artwork.artistId.isEmpty || artwork.artistId == userID else { throw AppError.notOwner }
        var output = artwork
        output.artistId = userID
        output.artistName = profile.displayName
        if let data = images?.first?.thumbnail, let temp = try? ImageStore.temporaryFile(data) {
            output.thumbnailURL = ImageStore.cacheFile(temp, key: "demo-\(artwork.id)-\(UUID().uuidString)")
            try? FileManager.default.removeItem(at: temp)
        }
        if let index = items.firstIndex(where: { $0.id == output.id }) {
            // Counts belong to the server, not the editor, as in CloudKit.
            output.viewCount = items[index].viewCount
            output.likeCount = items[index].likeCount
            items[index] = output
        } else {
            items.insert(output, at: 0)
        }
        return output
    }

    func deleteArtwork(id: String) async throws {
        guard items.first(where: { $0.id == id })?.artistId == userID else { throw AppError.notOwner }
        items.removeAll { $0.id == id }
    }

    func library() async throws -> UserLibrary { state }

    func setLibrary(_ kind: LibraryKind, id: String, included: Bool) async throws {
        switch kind {
        case .saved: if included { state.saved.insert(id) } else { state.saved.remove(id) }
        case .following: if included { state.following.insert(id) } else { state.following.remove(id) }
        case .blocked: if included { state.blocked.insert(id) } else { state.blocked.remove(id) }
        }
    }

    func submitReport(target: ReportTarget, targetID: String, reason: ReportReason, note: String) async throws {
        reports.append((target, targetID, reason))
    }

    func deleteAccount() async throws {
        guard let userID else { throw AppError.iCloudRequired }
        items.removeAll { $0.artistId == userID }
        reviewStore.removeAll { $0.reviewerID == userID || $0.artistID == userID }
        profiles[userID] = nil
        state = UserLibrary()
    }
}

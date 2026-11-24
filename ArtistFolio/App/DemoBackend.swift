import CloudKit
import SwiftUI

final class DemoBackend: ArtBackend {
    private var userID: String?
    private var profiles: [String: UserProfile] = [:]
    private var items: [Artwork] = []
    private var state = UserLibrary()
    private(set) var reports: [(ReportTarget, String, ReportReason)] = []
    var failsIdentityLoads = false
    var failsProfileLoads = false
    var failsArtworkLoads = false

    init(mode: String) {
        var sofia = UserProfile(id: "artist-sofia", displayName: "Sofia Martinez", bio: "Abstract painter working with oil and gold leaf.", role: .artist, location: "Barcelona, Spain", website: "example.com", instagramHandle: "sofia.paints", contactEmail: "sofia@example.com", acceptsCommissions: true)
        sofia.avatarURL = Self.avatar(initials: "SM", red: 0.72, green: 0.33, blue: 0.18, cacheKey: "demo-avatar-sofia")
        var james = UserProfile(id: "artist-james", displayName: "James Thornton", bio: "Quiet seascapes in watercolor.", role: .artist, location: "Cornwall, UK", instagramHandle: "james.tides", contactEmail: "james@example.com")
        james.avatarURL = Self.avatar(initials: "JT", red: 0.15, green: 0.42, blue: 0.58, cacheKey: "demo-avatar-james")
        profiles = [sofia.id: sofia, james.id: james]
        items = [
            Self.art("art-1", sofia, "Crimson Dreams", 1200, .oilOnCanvas, .abstract, ["#C0392B", "#F39C12"]),
            Self.art("art-2", james, "Ocean Silence", 850, .watercolor, .minimalism, ["#2980B9", "#D6EAF8"]),
            Self.art("art-5", james, "Harbor at Dusk", 1650, .acrylic, .landscape, ["#1F3A5F", "#F2A65A"], size: ArtworkDimensions(width: 120, height: 60, unit: "cm")),
            Self.art("art-3", sofia, "Golden Hour", 2400, .mixedMedia, .contemporary, ["#F7DC6F", "#8E44AD"]),
            Self.art("art-4", james, "Tidal Study", 420, .watercolor, .landscape, ["#1ABC9C", "#154360"], status: .sold)
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

    private static func art(_ id: String, _ artist: UserProfile, _ title: String, _ price: Double, _ medium: ArtworkMedium, _ style: ArtworkStyle, _ colors: [String], status: ArtworkStatus = .available, size: ArtworkDimensions = ArtworkDimensions(width: 60, height: 80, unit: "cm")) -> Artwork {
        Artwork(id: id, artistId: artist.id, artistName: artist.displayName, title: title, details: "An original work exploring color, light, and texture.", price: price, status: status, medium: medium, style: style, dimensions: size, year: 2026, tags: [style.rawValue.lowercased()], thumbnailURL: image(key: id, colors: colors, aspect: size.aspectRatio))
    }

    private static func image(key: String, colors: [String], aspect: CGFloat) -> URL? {
        let namedMap = ["art-1": "demo_art_1", "art-2": "demo_art_2", "art-3": "demo_art_3",
                        "art-4": "demo_art_4", "art-5": "demo_art_5"]
        let size = aspect >= 1 ? CGSize(width: 900, height: 900 / aspect) : CGSize(width: 760 * aspect, height: 760)
        let rendered: UIImage
        let cacheKey: String
        if let name = namedMap[key], let src = UIImage(named: name) {
            cacheKey = "demo-v3-\(key)"
            rendered = UIGraphicsImageRenderer(size: size).image { _ in src.draw(in: CGRect(origin: .zero, size: size)) }
        } else {
            cacheKey = "demo-v2-\(key)"
            rendered = UIGraphicsImageRenderer(size: size).image { context in
                let cgColors = colors.map { UIColor(Color(hex: $0)).cgColor } as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) {
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                }
            }
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
            let tokens = SearchTokens.make(from: [art.title, art.medium.rawValue, art.style.rawValue] + art.tags)
            return words.allSatisfy(tokens.contains)
                && (filters.styles.isEmpty || filters.styles.contains(art.style))
                && (filters.mediums.isEmpty || filters.mediums.contains(art.medium))
                && art.price >= filters.minPrice && art.price <= filters.maxPrice
        }
        switch filters.sortBy {
        case .newest: break
        case .priceAsc: output.sort { $0.price < $1.price }
        case .priceDesc: output.sort { $0.price > $1.price }
        }
        return ArtworkPage(items: output, cursor: nil)
    }

    func artworks(ownerID: String) async throws -> [Artwork] { items.filter { $0.artistId == ownerID } }
    func artworks(ids: [String]) async throws -> [Artwork] { items.filter { ids.contains($0.id) } }
    func fullImages(artworkID: String) async throws -> [URL] {
        items.first { $0.id == artworkID }?.thumbnailURL.map { [$0] } ?? []
    }

    func saveArtwork(_ artwork: Artwork, images: [ProcessedImage]?) async throws -> Artwork {
        guard let userID, let profile = profiles[userID] else { throw AppError.iCloudRequired }
        guard ContentFilter.isAllowed([artwork.title, artwork.details] + artwork.tags) else { throw AppError.objectionableContent }
        guard artwork.artistId.isEmpty || artwork.artistId == userID else { throw AppError.notOwner }
        var output = artwork
        output.artistId = userID
        output.artistName = profile.displayName
        if let data = images?.first?.thumbnail, let temp = try? ImageStore.temporaryFile(data) {
            output.thumbnailURL = ImageStore.cacheFile(temp, key: "demo-\(artwork.id)-\(UUID().uuidString)")
            try? FileManager.default.removeItem(at: temp)
        }
        if let index = items.firstIndex(where: { $0.id == output.id }) {
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
        profiles[userID] = nil
        state = UserLibrary()
    }
}

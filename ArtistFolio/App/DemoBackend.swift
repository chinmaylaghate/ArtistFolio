#if DEBUG
import CloudKit
import SwiftUI

final class DemoBackend: ArtBackend {
    private var userID: String?
    private var profiles: [String: UserProfile] = [:]
    private var items: [Artwork] = []
    private var state = UserLibrary()
    private(set) var reports: [(ReportTarget, String, ReportReason)] = []
    private var messages: [Message] = []
    private var commissionRequests: [CommissionRequest] = []

    init(mode: String) {
        let sofia = UserProfile(id: "artist-sofia", displayName: "Sofia Martinez", bio: "Abstract painter working with oil and gold leaf.", role: .artist, location: "Barcelona, Spain", website: "example.com", instagramHandle: "sofia.paints", contactEmail: "sofia@example.com", acceptsCommissions: true)
        let james = UserProfile(id: "artist-james", displayName: "James Thornton", bio: "Quiet seascapes in watercolor.", role: .artist, location: "Cornwall, UK", instagramHandle: "james.tides", contactEmail: "james@example.com")
        profiles = [sofia.id: sofia, james.id: james]
        items = [
            Self.art("art-1", sofia, "Crimson Dreams", 1200, .oilOnCanvas, .abstract, ["#C0392B", "#F39C12"]),
            Self.art("art-2", james, "Ocean Silence", 850, .watercolor, .minimalism, ["#2980B9", "#D6EAF8"]),
            Self.art("art-3", sofia, "Golden Hour", 2400, .mixedMedia, .contemporary, ["#F7DC6F", "#8E44AD"]),
            Self.art("art-4", james, "Tidal Study", 420, .watercolor, .landscape, ["#1ABC9C", "#154360"], status: .sold)
        ]
        switch mode {
        case "artist": userID = sofia.id
        case "collector":
            userID = "collector-maya"
            profiles["collector-maya"] = UserProfile(id: "collector-maya", displayName: "Maya Chen", role: .collector, location: "Toronto, Canada")
            state.saved = ["art-2"]
            state.following = [james.id]
        case "new": userID = "new-user"
        default: userID = nil
        }
    }

    private static func art(_ id: String, _ artist: UserProfile, _ title: String, _ price: Double, _ medium: ArtworkMedium, _ style: ArtworkStyle, _ colors: [String], status: ArtworkStatus = .available) -> Artwork {
        Artwork(id: id, artistId: artist.id, artistName: artist.displayName, title: title, details: "An original work exploring color, light, and texture.", price: price, status: status, medium: medium, style: style, dimensions: ArtworkDimensions(width: 60, height: 80, unit: "cm"), year: 2026, tags: [style.rawValue.lowercased()], thumbnailURL: image(key: id, colors: colors))
    }

    private static func image(key: String, colors: [String]) -> URL? {
        let size = CGSize(width: 600, height: 760)
        let rendered = UIGraphicsImageRenderer(size: size).image { context in
            let cgColors = colors.map { UIColor(Color(hex: $0)).cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
        }
        guard let data = rendered.jpegData(compressionQuality: 0.8), let temp = try? ImageStore.temporaryFile(data) else { return nil }
        defer { try? FileManager.default.removeItem(at: temp) }
        return ImageStore.cacheFile(temp, key: "demo-\(key)")
    }

    func currentUserID() async throws -> String? { userID }
    func resetIdentity() async {}
    func profile(ownerID: String) async throws -> UserProfile? { profiles[ownerID] }

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

    func conversations() async throws -> [Conversation] {
        guard let me = userID else { return [] }
        var latestByConv: [String: Message] = [:]
        for msg in messages where msg.conversationID.contains(me) {
            if let existing = latestByConv[msg.conversationID] {
                if msg.date > existing.date { latestByConv[msg.conversationID] = msg }
            } else {
                latestByConv[msg.conversationID] = msg
            }
        }
        return latestByConv.values.compactMap { msg -> Conversation? in
            let parts = msg.conversationID.split(separator: "_").map(String.init)
            guard parts.count == 2 else { return nil }
            let otherID = parts[0] == me ? parts[1] : parts[0]
            let other = profiles[otherID]
            return Conversation(
                id: msg.conversationID,
                otherUserID: otherID,
                otherName: other?.displayName ?? "Unknown",
                otherAvatarURL: other?.avatarURL,
                lastMessage: msg.text,
                lastDate: msg.date
            )
        }.sorted { $0.lastDate > $1.lastDate }
    }

    func messages(conversationID: String) async throws -> [Message] {
        messages.filter { $0.conversationID == conversationID }.sorted { $0.date < $1.date }
    }

    func sendMessage(to recipientID: String, recipientName: String, text: String) async throws -> Message {
        guard let me = userID else { throw AppError.iCloudRequired }
        let myName = profiles[me]?.displayName ?? "Me"
        let convID = Conversation.conversationID(me, recipientID)
        let msg = Message(id: UUID().uuidString, conversationID: convID, senderID: me, senderName: myName, text: text, date: Date())
        messages.append(msg)
        return msg
    }

    func commissionRequests() async throws -> [CommissionRequest] {
        guard let me = userID else { return [] }
        return commissionRequests.filter { $0.artistID == me || $0.collectorID == me }
            .sorted { $0.date > $1.date }
    }

    func sendCommissionRequest(artistID: String, artistName: String, description: String, budget: Double, styles: [ArtworkStyle]) async throws -> CommissionRequest {
        guard let me = userID else { throw AppError.iCloudRequired }
        let myName = profiles[me]?.displayName ?? "Collector"
        let req = CommissionRequest(
            id: UUID().uuidString,
            artistID: artistID,
            artistName: artistName,
            collectorID: me,
            collectorName: myName,
            description: description,
            budget: budget,
            styles: styles,
            status: .pending,
            date: Date()
        )
        commissionRequests.append(req)
        return req
    }

    func updateCommissionRequest(id: String, status: CommissionStatus) async throws {
        guard let idx = commissionRequests.firstIndex(where: { $0.id == id }) else { return }
        commissionRequests[idx].status = status
    }
}
#endif

import CloudKit
import Foundation

enum UserRole: String, CaseIterable, Identifiable {
    case artist, collector
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct UserProfile: Identifiable, Hashable {
    var id: String
    var recordName: String?
    var displayName: String
    var bio: String = ""
    var role: UserRole
    var location: String = ""
    var website: String = ""
    var instagramHandle: String = ""
    var contactEmail: String = ""
    var acceptsCommissions: Bool = false
    var avatarURL: URL?
    var commissionMinBudget: Double = 0
    var commissionWeeks: String = ""
    var followerCount: Int = 0
    var artworkCount: Int = 0

    var contactOptions: [ContactOption] {
        ContactLinks.options(email: contactEmail, instagram: instagramHandle, website: website)
    }
}

// MARK: - Messaging

struct Conversation: Identifiable, Hashable {
    var id: String
    var otherUserID: String
    var otherName: String
    var otherAvatarURL: URL?
    var lastMessage: String
    var lastDate: Date
    var unreadCount: Int = 0

    static func conversationID(_ a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "_")
    }
}

struct Message: Identifiable, Hashable {
    var id: String
    var conversationID: String
    var senderID: String
    var senderName: String
    var text: String
    var date: Date
}

// MARK: - Commissions

enum CommissionStatus: String, CaseIterable, Identifiable {
    case pending, accepted, declined
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct CommissionRequest: Identifiable, Hashable {
    var id: String
    var artistID: String
    var artistName: String
    var collectorID: String
    var collectorName: String
    var description: String
    var budget: Double
    var styles: [ArtworkStyle]
    var status: CommissionStatus
    var date: Date

    var budgetText: String {
        budget.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

enum ArtworkMedium: String, CaseIterable, Identifiable {
    case oilOnCanvas = "Oil on Canvas"
    case acrylic = "Acrylic"
    case watercolor = "Watercolor"
    case pastel = "Pastel"
    case digital = "Digital"
    case mixedMedia = "Mixed Media"
    case sculpture = "Sculpture"
    case photography = "Photography"
    case printmaking = "Printmaking"
    case drawing = "Drawing"
    var id: String { rawValue }
}

enum ArtworkStyle: String, CaseIterable, Identifiable {
    case abstract = "Abstract"
    case realism = "Realism"
    case impressionism = "Impressionism"
    case expressionism = "Expressionism"
    case surrealism = "Surrealism"
    case minimalism = "Minimalism"
    case contemporary = "Contemporary"
    case landscape = "Landscape"
    case portrait = "Portrait"
    case stillLife = "Still Life"
    var id: String { rawValue }
}

enum ArtworkStatus: String, CaseIterable, Identifiable {
    case available, reserved, sold
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct ArtworkDimensions: Hashable {
    var width: Double
    var height: Double
    var unit: String

    var displayString: String {
        "\(Self.format(width)) x \(Self.format(height)) \(unit)"
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct Artwork: Identifiable, Hashable {
    var id: String
    var artistId: String
    var artistName: String = ""
    var title: String
    var details: String
    var price: Double
    var status: ArtworkStatus
    var medium: ArtworkMedium
    var style: ArtworkStyle
    var dimensions: ArtworkDimensions
    var year: Int
    var tags: [String] = []
    var thumbnailURL: URL?
    var createdAt: Date = Date()

    var priceText: String {
        price.formatted(.currency(code: "USD").precision(.fractionLength(price.rounded() == price ? 0 : 2)))
    }
}

struct ArtworkFilters: Equatable {
    var text: String = ""
    var styles: [ArtworkStyle] = []
    var mediums: [ArtworkMedium] = []
    var minPrice: Double = 0
    var maxPrice: Double = ArtworkFilters.priceCeiling
    var sortBy: SortOption = .newest

    static let priceCeiling: Double = 50000

    var hasRefinements: Bool {
        !styles.isEmpty || !mediums.isEmpty || minPrice > 0 || maxPrice < Self.priceCeiling
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case priceAsc = "Price: Low to High"
        case priceDesc = "Price: High to Low"
        var id: String { rawValue }
    }
}

struct ArtworkPage {
    var items: [Artwork]
    var cursor: CKQueryOperation.Cursor?
}

struct ProcessedImage {
    var full: Data
    var thumbnail: Data
}

struct UserLibrary: Equatable {
    var saved: Set<String> = []
    var following: Set<String> = []
    var blocked: Set<String> = []
}

enum LibraryKind: String, CaseIterable {
    case saved, following, blocked

    var recordType: String {
        switch self {
        case .saved: return "SavedArtwork"
        case .following: return "FollowedArtist"
        case .blocked: return "BlockedArtist"
        }
    }
}

enum ReportTarget: String {
    case artwork, artist
}

enum ReportReason: String, CaseIterable, Identifiable {
    case stolen = "Stolen or copied work"
    case sexual = "Sexual or explicit content"
    case hate = "Hate or harassment"
    case violence = "Violence or dangerous content"
    case scam = "Scam or misleading listing"
    case other = "Something else"
    var id: String { rawValue }
}

enum AppError: LocalizedError {
    case iCloudRequired
    case objectionableContent
    case invalidImage
    case notOwner

    var errorDescription: String? {
        switch self {
        case .iCloudRequired: return "Sign in to iCloud in Settings to continue."
        case .objectionableContent: return "Please remove language that breaks the community guidelines."
        case .invalidImage: return "That photo could not be processed. Try another one."
        case .notOwner: return "You can only change your own work."
        }
    }
}

protocol ArtBackend: AnyObject {
    func currentUserID() async throws -> String?
    func resetIdentity() async
    func profile(ownerID: String) async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile, avatar: Data?) async throws -> UserProfile
    func searchProfiles(text: String) async throws -> [UserProfile]
    func artworks(filters: ArtworkFilters, cursor: CKQueryOperation.Cursor?) async throws -> ArtworkPage
    func artworks(ownerID: String) async throws -> [Artwork]
    func artworks(ids: [String]) async throws -> [Artwork]
    func fullImages(artworkID: String) async throws -> [URL]
    func saveArtwork(_ artwork: Artwork, images: [ProcessedImage]?) async throws -> Artwork
    func deleteArtwork(id: String) async throws
    func library() async throws -> UserLibrary
    func setLibrary(_ kind: LibraryKind, id: String, included: Bool) async throws
    func submitReport(target: ReportTarget, targetID: String, reason: ReportReason, note: String) async throws
    func deleteAccount() async throws
    // Messages
    func conversations() async throws -> [Conversation]
    func messages(conversationID: String) async throws -> [Message]
    func sendMessage(to recipientID: String, recipientName: String, text: String) async throws -> Message
    // Commissions
    func commissionRequests() async throws -> [CommissionRequest]
    func sendCommissionRequest(artistID: String, artistName: String, description: String, budget: Double, styles: [ArtworkStyle]) async throws -> CommissionRequest
    func updateCommissionRequest(id: String, status: CommissionStatus) async throws
}

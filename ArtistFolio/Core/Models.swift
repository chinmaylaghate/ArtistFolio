// MARK: - ArtistFolio Core Models
import Foundation
import SwiftUI

// MARK: - User & Roles

enum UserRole: String, Codable {
    case artist, collector, both
}

struct AppUser: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String
    var avatarURL: String?
    var bio: String?
    var role: UserRole
    var location: String?
    var website: String?
    var instagramHandle: String?
    var isVerified: Bool
    var isPro: Bool
    var followersCount: Int
    var followingCount: Int
    var joinedDate: Date
    var totalSales: Int
    var totalRevenue: Double

    static let preview = AppUser(
        id: "user_001",
        email: "sofia@example.com",
        displayName: "Sofia Martinez",
        avatarURL: nil,
        bio: "Abstract expressionist painter based in Barcelona.",
        role: .artist,
        location: "Barcelona, Spain",
        website: "sofiapaints.com",
        instagramHandle: "@sofiapaints",
        isVerified: true,
        isPro: true,
        followersCount: 4820,
        followingCount: 312,
        joinedDate: Date(),
        totalSales: 47,
        totalRevenue: 18400
    )
}

// MARK: - Artwork

enum ArtworkMedium: String, Codable, CaseIterable {
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
}

enum ArtworkStyle: String, Codable, CaseIterable {
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
}

enum ArtworkStatus: String, Codable {
    case available, sold, reserved, auction
}

struct ArtworkDimensions: Codable, Hashable {
    var width: Double
    var height: Double
    var depth: Double?
    var unit: String // cm or inches

    var displayString: String {
        if let d = depth {
            return "\(Int(width)) x \(Int(height)) x \(Int(d)) \(unit)"
        }
        return "\(Int(width)) x \(Int(height)) \(unit)"
    }
}

struct Artwork: Identifiable, Codable, Hashable {
    var id: String
    var artistId: String
    var artistName: String
    var artistAvatarURL: String?
    var title: String
    var description: String
    var imageURLs: [String]
    var price: Double
    var originalPrice: Double?
    var status: ArtworkStatus
    var medium: ArtworkMedium
    var style: ArtworkStyle
    var dimensions: ArtworkDimensions
    var year: Int
    var tags: [String]
    var colorPalette: [String] // hex colors
    var likesCount: Int
    var viewsCount: Int
    var isLiked: Bool
    var hasCertificate: Bool
    var certificateHash: String?
    var shippingOptions: [ShippingOption]
    var createdAt: Date
    var updatedAt: Date

    var primaryImageURL: String { imageURLs.first ?? "" }

    static let previews: [Artwork] = [
        Artwork(id: "art_001", artistId: "user_001", artistName: "Sofia Martinez", artistAvatarURL: nil,
                title: "Crimson Dreams", description: "A bold abstract exploration of emotion through vivid crimson and gold.", imageURLs: [],
                price: 1200, originalPrice: nil, status: .available, medium: .oilOnCanvas, style: .abstract,
                dimensions: ArtworkDimensions(width: 60, height: 80, unit: "cm"), year: 2024, tags: ["abstract", "red", "bold"],
                colorPalette: ["#C0392B", "#E74C3C", "#F39C12", "#1A1A2E"], likesCount: 234, viewsCount: 1820,
                isLiked: true, hasCertificate: true, certificateHash: "0xabc123", shippingOptions: [], createdAt: Date(), updatedAt: Date()),
        Artwork(id: "art_002", artistId: "user_002", artistName: "James Thornton", artistAvatarURL: nil,
                title: "Ocean Silence", description: "Minimalist seascape capturing the quiet between waves.", imageURLs: [],
                price: 850, originalPrice: 1000, status: .available, medium: .watercolor, style: .minimalism,
                dimensions: ArtworkDimensions(width: 40, height: 50, unit: "cm"), year: 2023, tags: ["ocean", "blue", "calm"],
                colorPalette: ["#2980B9", "#85C1E9", "#D6EAF8", "#1A1A2E"], likesCount: 189, viewsCount: 2100,
                isLiked: false, hasCertificate: false, certificateHash: nil, shippingOptions: [], createdAt: Date(), updatedAt: Date()),
        Artwork(id: "art_003", artistId: "user_003", artistName: "Yuki Tanaka", artistAvatarURL: nil,
                title: "Garden of Words", description: "Impressionist garden scene with delicate brushwork.", imageURLs: [],
                price: 2400, originalPrice: nil, status: .available, medium: .oilOnCanvas, style: .impressionism,
                dimensions: ArtworkDimensions(width: 90, height: 70, unit: "cm"), year: 2024, tags: ["garden", "impressionism", "floral"],
                colorPalette: ["#27AE60", "#A9DFBF", "#F7DC6F", "#EC407A"], likesCount: 412, viewsCount: 3200,
                isLiked: true, hasCertificate: true, certificateHash: "0xdef456", shippingOptions: [], createdAt: Date(), updatedAt: Date()),
    ]
}

// MARK: - Shipping

struct ShippingOption: Identifiable, Codable, Hashable {
    var id: String
    var carrier: String
    var serviceName: String
    var estimatedDays: Int
    var price: Double
    var includesInsurance: Bool
    var trackingAvailable: Bool
}

// MARK: - Order

enum OrderStatus: String, Codable {
    case pending, confirmed, packaged, shipped, delivered, cancelled, refunded
    var displayName: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .blue
        case .packaged: return .purple
        case .shipped: return .indigo
        case .delivered: return .green
        case .cancelled, .refunded: return .red
        }
    }
}

struct Order: Identifiable, Codable {
    var id: String
    var artworkId: String
    var artworkTitle: String
    var artworkImageURL: String
    var buyerId: String
    var sellerId: String
    var artistName: String
    var price: Double
    var commission: Double
    var shippingCost: Double
    var total: Double
    var status: OrderStatus
    var shippingAddress: Address
    var trackingNumber: String?
    var createdAt: Date
    var updatedAt: Date
}

struct Address: Codable {
    var fullName: String
    var street: String
    var city: String
    var state: String
    var postalCode: String
    var country: String

    var displayString: String {
        "\(street), \(city), \(state) \(postalCode), \(country)"
    }
}

// MARK: - Message & Chat

struct Conversation: Identifiable, Codable {
    var id: String
    var participants: [String]
    var otherUserName: String
    var otherUserAvatarURL: String?
    var lastMessage: String
    var lastMessageAt: Date
    var unreadCount: Int
    var artworkId: String?
    var artworkTitle: String?
}

struct Message: Identifiable, Codable {
    var id: String
    var conversationId: String
    var senderId: String
    var text: String
    var imageURL: String?
    var sentAt: Date
    var isRead: Bool
}

// MARK: - Notification

enum NotificationType: String, Codable {
    case sale, like, follow, message, certificate, priceAlert, featured, event
}

struct AppNotification: Identifiable, Codable {
    var id: String
    var userId: String
    var type: NotificationType
    var title: String
    var body: String
    var imageURL: String?
    var relatedId: String?
    var isRead: Bool
    var createdAt: Date
}

// MARK: - Review

struct Review: Identifiable, Codable {
    var id: String
    var reviewerId: String
    var reviewerName: String
    var reviewerAvatarURL: String?
    var targetId: String
    var rating: Int // 1-5
    var comment: String
    var createdAt: Date
}

// MARK: - Cart

struct CartItem: Identifiable, Codable {
    var id: String
    var artwork: Artwork
    var selectedShipping: ShippingOption?
    var addedAt: Date
}

// MARK: - Certificate of Authenticity

struct Certificate: Identifiable, Codable {
    var id: String
    var artworkId: String
    var artworkTitle: String
    var artistId: String
    var artistName: String
    var blockchainHash: String
    var transactionId: String
    var issuedAt: Date
    var currentOwner: String
    var provenance: [ProvenanceRecord]
    var nfcTagId: String?
}

struct ProvenanceRecord: Identifiable, Codable {
    var id: String
    var fromOwner: String
    var toOwner: String
    var price: Double
    var royaltyPaid: Double
    var transactionDate: Date
    var blockchainHash: String
}

// MARK: - AI Pricing Suggestion

struct PricingSuggestion: Codable {
    var suggestedMinPrice: Double
    var suggestedMaxPrice: Double
    var recommendedPrice: Double
    var confidence: Double // 0-1
    var comparables: [ComparableArtwork]
    var factors: [PricingFactor]
}

struct ComparableArtwork: Identifiable, Codable {
    var id: String
    var title: String
    var artistName: String
    var soldPrice: Double
    var soldDate: Date
    var similarity: Double
}

struct PricingFactor: Identifiable, Codable {
    var id: String
    var factor: String
    var impact: String // "positive", "negative", "neutral"
    var description: String
}

// MARK: - Event

struct ArtEvent: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var type: String // "live_sale", "studio_visit", "exhibition"
    var hostId: String
    var hostName: String
    var imageURL: String?
    var startDate: Date
    var endDate: Date
    var location: String?
    var isVirtual: Bool
    var attendeeCount: Int
    var isRegistered: Bool
}

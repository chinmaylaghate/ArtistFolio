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
    var phone: String = ""
    var whatsapp: String = ""
    var acceptsCommissions: Bool = false
    var avatarURL: URL?
    var followerCount: Int = 0
    var artworkCount: Int = 0

    var contactOptions: [ContactOption] {
        ContactLinks.options(email: contactEmail, instagram: instagramHandle, website: website, phone: phone, whatsapp: whatsapp)
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

/// Size band from the longest side, used by the size filter.
enum ArtworkSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small (under 40 cm)"
        case .medium: return "Medium (40\u{2013}100 cm)"
        case .large: return "Large (over 100 cm)"
        }
    }

    init(longestSideCentimeters side: Double) {
        if side < 40 { self = .small } else if side <= 100 { self = .medium } else { self = .large }
    }
}

struct ArtworkDimensions: Hashable {
    var width: Double
    var height: Double
    var unit: String

    var aspectRatio: CGFloat {
        guard width > 0, height > 0 else { return 1 }
        return CGFloat(width / height)
    }

    var isPortrait: Bool { aspectRatio < 0.9 }

    var sizeInCentimeters: CGSize {
        let factor = unit == "in" ? 2.54 : 1
        return CGSize(width: width * factor, height: height * factor)
    }

    func sizeInCentimeters(matching imageAspect: CGFloat?) -> CGSize {
        let size = sizeInCentimeters
        guard let imageAspect, imageAspect > 0 else { return size }
        let longest = max(size.width, size.height)
        return imageAspect >= 1
            ? CGSize(width: longest, height: longest / imageAspect)
            : CGSize(width: longest * imageAspect, height: longest)
    }

    var displayString: String {
        "\(Self.format(width)) x \(Self.format(height)) \(unit)"
    }

    var sizeClass: ArtworkSize {
        let size = sizeInCentimeters
        return ArtworkSize(longestSideCentimeters: max(size.width, size.height))
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
    /// The artist hides the price; buyers ask for it. `price` is stored as 0.
    var priceOnRequest: Bool = false
    /// The artist's own care advice, shown above the standard tips.
    var careNote: String = ""
    /// Whether to show the standard care tips for the medium.
    var showCareTips: Bool = true
    /// Optional name of the series this piece belongs to.
    var series: String = ""

    static let maxSeriesLength = 60

    var priceText: String {
        if priceOnRequest { return "Price on request" }
        return price.formatted(.currency(code: "USD").precision(.fractionLength(price.rounded() == price ? 0 : 2)))
    }
}

struct ArtworkFilters: Hashable {
    var text: String = ""
    var styles: [ArtworkStyle] = []
    var mediums: [ArtworkMedium] = []
    var sizes: [ArtworkSize] = []
    var minPrice: Double = 0
    var maxPrice: Double = ArtworkFilters.priceCeiling
    var sortBy: SortOption = .newest

    static let priceCeiling: Double = 50000

    var hasRefinements: Bool {
        !styles.isEmpty || !mediums.isEmpty || !sizes.isEmpty || hasPriceLimit
    }

    var hasPriceLimit: Bool { minPrice > 0 || maxPrice < Self.priceCeiling }

    /// Price-on-request pieces match only when no price limit is set.
    func matchesPrice(_ artwork: Artwork) -> Bool {
        if artwork.priceOnRequest { return !hasPriceLimit }
        return artwork.price >= minPrice && artwork.price <= maxPrice
    }

    /// For price sorts, moves price-on-request pieces after priced ones, keeping order otherwise.
    func ordered(_ items: [Artwork]) -> [Artwork] {
        guard sortBy != .newest else { return items }
        return items.filter { !$0.priceOnRequest } + items.filter(\.priceOnRequest)
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case priceAsc = "Price: Low to High"
        case priceDesc = "Price: High to Low"
        var id: String { rawValue }
    }
}

struct ArtCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let filters: ArtworkFilters

    private init(_ id: String, _ title: String, _ subtitle: String, styles: [ArtworkStyle] = [], mediums: [ArtworkMedium] = [], maxPrice: Double? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        var filters = ArtworkFilters()
        filters.styles = styles
        filters.mediums = mediums
        if let maxPrice { filters.maxPrice = maxPrice }
        self.filters = filters
    }

    func matches(_ artwork: Artwork) -> Bool {
        (filters.styles.isEmpty || filters.styles.contains(artwork.style))
            && (filters.mediums.isEmpty || filters.mediums.contains(artwork.medium))
            && (filters.sizes.isEmpty || filters.sizes.contains(artwork.dimensions.sizeClass))
            && filters.matchesPrice(artwork)
    }

    static let featured = ArtCollection("abstract", "Abstract Masters", "Bold forms & pure emotion", styles: [.abstract])
    static let upfrontCount = 8

    static let all: [ArtCollection] = [
        featured,
        ArtCollection("under-1000", "Under $1,000", "Originals at an accessible price", maxPrice: 1000),
        ArtCollection("recent", "Recently Added", "The newest work on Artist Folio"),
        ArtCollection("portrait", "Portrait Gallery", "Faces, figures & character", styles: [.portrait]),
        ArtCollection("landscape", "Nature & Landscape", "Scenes from the natural world", styles: [.landscape]),
        ArtCollection("contemporary", "Contemporary", "Art of the moment", styles: [.contemporary]),
        ArtCollection("oil", "Oil Paintings", "Rich color & classic technique", mediums: [.oilOnCanvas]),
        ArtCollection("watercolor", "Watercolors", "Light, fluid & luminous", mediums: [.watercolor]),
        ArtCollection("under-500", "Under $500", "Great first pieces to collect", maxPrice: 500),
        ArtCollection("minimalism", "Minimalism", "Less, but better", styles: [.minimalism]),
        ArtCollection("realism", "Realism", "Life, closely observed", styles: [.realism]),
        ArtCollection("impressionism", "Impressionism", "Light in fleeting moments", styles: [.impressionism]),
        ArtCollection("expressionism", "Expressionism", "Feeling over form", styles: [.expressionism]),
        ArtCollection("surrealism", "Surrealism", "Dreams made visible", styles: [.surrealism]),
        ArtCollection("still-life", "Still Life", "Quiet, everyday objects", styles: [.stillLife]),
        ArtCollection("acrylic", "Acrylics", "Bold, vivid color", mediums: [.acrylic]),
        ArtCollection("mixed-media", "Mixed Media", "Materials in conversation", mediums: [.mixedMedia]),
        ArtCollection("digital", "Digital Art", "Made on screen", mediums: [.digital]),
        ArtCollection("drawing", "Drawings", "The power of line", mediums: [.drawing]),
        ArtCollection("pastel", "Pastels", "Soft, rich texture", mediums: [.pastel]),
        ArtCollection("sculpture", "Sculpture", "Art in three dimensions", mediums: [.sculpture]),
        ArtCollection("photography", "Photography", "Moments in frame", mediums: [.photography]),
        ArtCollection("printmaking", "Prints", "Crafted impressions", mediums: [.printmaking])
    ]
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
    case artwork, artist, review
}

enum ReviewRelationship: String, CaseIterable, Identifiable {
    case bought = "Bought a piece"
    case commissioned = "Commissioned work"
    case met = "Met at a show or studio"
    var id: String { rawValue }
}

/// A collector's review of an artist. One per reviewer per artist: a second review replaces the first.
struct Review: Identifiable, Hashable {
    var artistID: String
    var reviewerID: String
    var reviewerName: String = ""
    var rating: Int
    var text: String
    var relationship: ReviewRelationship
    var createdAt: Date = Date()

    static let maxTextLength = 500
    static let ratingRange = 1...5

    var id: String { Self.recordName(reviewerID: reviewerID, artistID: artistID) }

    static func recordName(reviewerID: String, artistID: String) -> String {
        "review_\(reviewerID)_\(artistID)"
    }
}

/// The rating shown for an artist. The average appears only once there are enough reviews
/// that one unfair review can't define a profile.
struct ReviewSummary: Equatable {
    static let minimumForAverage = 3

    let count: Int
    let average: Double

    init(reviews: [Review]) {
        count = reviews.count
        average = reviews.isEmpty ? 0 : Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    var showsAverage: Bool { count >= Self.minimumForAverage }
    var averageText: String { String(format: "%.1f", average) }
    var countText: String { count == 1 ? "1 review" : "\(count) reviews" }
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
    case accountUnavailable
    case cannotReviewSelf

    var errorDescription: String? {
        switch self {
        case .iCloudRequired: return "Sign in to iCloud in Settings to continue."
        case .objectionableContent: return "Please remove language that breaks the community guidelines."
        case .invalidImage: return "That photo could not be processed. Try another one."
        case .notOwner: return "You can only change your own work."
        case .accountUnavailable: return "We couldn't load your account. Check your connection and try again."
        case .cannotReviewSelf: return "You can't review your own profile."
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
    /// Reviews of an artist, newest first, with reviewer names filled in.
    func reviews(artistID: String) async throws -> [Review]
    /// Creates or replaces the signed-in user's review of an artist.
    func saveReview(_ review: Review) async throws -> Review
    /// Deletes the signed-in user's review of an artist.
    func deleteReview(artistID: String) async throws
    /// Fills in the stored size band on the signed-in artist's older listings. Returns how many were updated.
    func backfillSizeClasses() async throws -> Int
    func fullImages(artworkID: String) async throws -> [URL]
    func saveArtwork(_ artwork: Artwork, images: [ProcessedImage]?) async throws -> Artwork
    func deleteArtwork(id: String) async throws
    func library() async throws -> UserLibrary
    func setLibrary(_ kind: LibraryKind, id: String, included: Bool) async throws
    func submitReport(target: ReportTarget, targetID: String, reason: ReportReason, note: String) async throws
    func deleteAccount() async throws
}

/// Facts for the artist summary card, worked out from the artist's published artworks.
struct ArtistSummary: Equatable {
    struct Stat: Equatable, Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    let stats: [Stat]
    let topMediums: [ArtworkMedium]

    /// The card needs at least two facts to be worth showing.
    var showsCard: Bool { stats.count >= 2 }

    init(artworks: [Artwork]) {
        var stats: [Stat] = []
        if !artworks.isEmpty {
            stats.append(Stat(value: String(artworks.count), label: artworks.count == 1 ? "Work" : "Works"))
        }
        let sold = artworks.filter { $0.status == .sold }.count
        if sold > 0 {
            stats.append(Stat(value: String(sold), label: "Sold"))
        }
        let prices = artworks.filter { $0.status == .available && !$0.priceOnRequest && $0.price > 0 }.map(\.price)
        if let lowest = prices.min() {
            stats.append(Stat(value: Self.compactPrice(lowest), label: "From"))
        }
        self.stats = stats

        var counts: [ArtworkMedium: Int] = [:]
        for artwork in artworks { counts[artwork.medium, default: 0] += 1 }
        topMediums = counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
            .prefix(3)
            .map(\.key)
    }

    /// "$400", "$1.2K", "$15K" — short enough for a stat column.
    static func compactPrice(_ value: Double) -> String {
        if value >= 1000 {
            let thousands = value / 1000
            let text = thousands >= 10 || thousands.rounded() == thousands
                ? String(Int(thousands.rounded()))
                : String(format: "%.1f", thousands)
            return "$\(text)K"
        }
        return "$\(Int(value.rounded()))"
    }
}

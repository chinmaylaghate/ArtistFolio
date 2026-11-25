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

    var priceText: String {
        if priceOnRequest { return "Price on request" }
        return price.formatted(.currency(code: "USD").precision(.fractionLength(price.rounded() == price ? 0 : 2)))
    }
}

struct ArtworkFilters: Hashable {
    var text: String = ""
    var styles: [ArtworkStyle] = []
    var mediums: [ArtworkMedium] = []
    var minPrice: Double = 0
    var maxPrice: Double = ArtworkFilters.priceCeiling
    var sortBy: SortOption = .newest

    static let priceCeiling: Double = 50000

    var hasRefinements: Bool {
        !styles.isEmpty || !mediums.isEmpty || hasPriceLimit
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
    case accountUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudRequired: return "Sign in to iCloud in Settings to continue."
        case .objectionableContent: return "Please remove language that breaks the community guidelines."
        case .invalidImage: return "That photo could not be processed. Try another one."
        case .notOwner: return "You can only change your own work."
        case .accountUnavailable: return "We couldn't load your account. Check your connection and try again."
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

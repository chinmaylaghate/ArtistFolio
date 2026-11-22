// MARK: - ArtistFolio Unit Tests
import XCTest
@testable import ArtistFolio

final class ArtworkModelTests: XCTestCase {

    func testArtworkDimensionsDisplayString() {
        let dims2D = ArtworkDimensions(width: 60, height: 80, unit: "cm")
        XCTAssertEqual(dims2D.displayString, "60 x 80 cm")

        let dims3D = ArtworkDimensions(width: 60, height: 80, depth: 5, unit: "cm")
        XCTAssertEqual(dims3D.displayString, "60 x 80 x 5 cm")
    }

    func testArtworkPreviewNotEmpty() {
        XCTAssertFalse(Artwork.previews.isEmpty)
        XCTAssertEqual(Artwork.previews.count, 3)
    }

    func testArtworkPrimaryImageURL() {
        var artwork = Artwork.previews[0]
        artwork.imageURLs = ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
        XCTAssertEqual(artwork.primaryImageURL, "https://example.com/image1.jpg")
    }

    func testArtworkPrimaryImageURLEmpty() {
        let artwork = Artwork.previews[0] // has empty imageURLs
        XCTAssertEqual(artwork.primaryImageURL, "")
    }

    func testOrderStatusDisplayNames() {
        XCTAssertEqual(OrderStatus.pending.displayName, "Pending")
        XCTAssertEqual(OrderStatus.delivered.displayName, "Delivered")
        XCTAssertEqual(OrderStatus.cancelled.displayName, "Cancelled")
    }
}

final class AppStateTests: XCTestCase {

    @MainActor
    func testCartAddRemove() {
        let state = AppState()
        let artwork = Artwork.previews[0]

        state.addToCart(artwork)
        XCTAssertEqual(state.cartCount, 1)

        // Adding same artwork again should not duplicate
        state.addToCart(artwork)
        XCTAssertEqual(state.cartCount, 1)

        state.removeFromCart(id: state.cartItems[0].id)
        XCTAssertEqual(state.cartCount, 0)
    }

    @MainActor
    func testFavoritesToggle() {
        let state = AppState()
        let artworkId = "art_001"

        XCTAssertFalse(state.isFavorite(artworkId: artworkId))

        state.toggleFavorite(artworkId: artworkId)
        XCTAssertTrue(state.isFavorite(artworkId: artworkId))

        state.toggleFavorite(artworkId: artworkId)
        XCTAssertFalse(state.isFavorite(artworkId: artworkId))
    }

    @MainActor
    func testCartTotal() {
        let state = AppState()
        state.addToCart(Artwork.previews[0]) // $1200
        state.addToCart(Artwork.previews[1]) // $850

        XCTAssertEqual(state.cartTotal, 1200 + 850, accuracy: 0.01)
    }

    @MainActor
    func testClearCart() {
        let state = AppState()
        Artwork.previews.forEach { state.addToCart($0) }
        XCTAssertGreaterThan(state.cartCount, 0)

        state.clearCart()
        XCTAssertEqual(state.cartCount, 0)
    }
}

final class DeepLinkTests: XCTestCase {

    func testArtworkDeepLink() {
        let url = URL(string: "artistfolio://artwork/art_001")!
        let link = DeepLink.from(url: url)
        XCTAssertEqual(link, .artwork(id: "art_001"))
    }

    func testArtistDeepLink() {
        let url = URL(string: "artistfolio://artist/user_001")!
        let link = DeepLink.from(url: url)
        XCTAssertEqual(link, .artist(id: "user_001"))
    }

    func testUniversalLink() {
        let url = URL(string: "https://artistfolio.com/artwork/art_001")!
        let link = DeepLink.from(url: url)
        XCTAssertEqual(link, .artwork(id: "art_001"))
    }

    func testInvalidDeepLink() {
        let url = URL(string: "artistfolio://unknown/path")!
        let link = DeepLink.from(url: url)
        XCTAssertNil(link)
    }
}

final class ArtworkFiltersTests: XCTestCase {

    func testDefaultFiltersHaveNoActiveState() {
        let filters = ArtworkFilters()
        XCTAssertTrue(filters.styles.isEmpty)
        XCTAssertTrue(filters.mediums.isEmpty)
        XCTAssertEqual(filters.minPrice, 0)
        XCTAssertEqual(filters.maxPrice, 50000)
    }

    func testFiltersEquality() {
        let f1 = ArtworkFilters()
        let f2 = ArtworkFilters()
        XCTAssertEqual(f1, f2)
    }
}

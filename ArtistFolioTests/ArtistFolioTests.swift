import CloudKit
import XCTest
@testable import ArtistFolio

final class RecordMappingTests: XCTestCase {
    private func sampleArtwork() -> Artwork {
        Artwork(id: "a1", artistId: "owner", title: "Blue Study", details: "Notes", price: 125.5, status: .reserved, medium: .watercolor, style: .minimalism, dimensions: ArtworkDimensions(width: 30, height: 40.5, unit: "in"), year: 2025, tags: ["ocean"])
    }

    func testArtworkRoundTrip() throws {
        let record = CKRecord(recordType: "Artwork", recordID: CKRecord.ID(recordName: "a1"))
        ArtworkMapper.apply(sampleArtwork(), to: record)
        let mapped = try XCTUnwrap(ArtworkMapper.artwork(from: record, ownerID: "owner", thumbnailURL: nil))
        XCTAssertEqual(mapped.title, "Blue Study")
        XCTAssertEqual(mapped.price, 125.5)
        XCTAssertEqual(mapped.status, .reserved)
        XCTAssertEqual(mapped.medium, .watercolor)
        XCTAssertEqual(mapped.dimensions.displayString, "30 x 40.5 in")
        XCTAssertEqual(mapped.artistId, "owner")
    }

    func testMalformedArtworkIsRejected() {
        let record = CKRecord(recordType: "Artwork")
        ArtworkMapper.apply(sampleArtwork(), to: record)
        record["status"] = "hacked"
        XCTAssertNil(ArtworkMapper.artwork(from: record, ownerID: "owner", thumbnailURL: nil))
        record["status"] = "available"
        record["price"] = -5.0
        XCTAssertNil(ArtworkMapper.artwork(from: record, ownerID: "owner", thumbnailURL: nil))
    }

    func testProfileRoundTrip() throws {
        let record = CKRecord(recordType: "Profile")
        let profile = UserProfile(id: "owner", displayName: "Ana Ruiz", role: .artist, location: "Lima", acceptsCommissions: true)
        ProfileMapper.apply(profile, to: record)
        let mapped = try XCTUnwrap(ProfileMapper.profile(from: record, ownerID: "owner", avatarURL: nil))
        XCTAssertEqual(mapped.displayName, "Ana Ruiz")
        XCTAssertTrue(mapped.acceptsCommissions)
        XCTAssertEqual(record["searchTokens"] as? [String], ["ana", "lima", "ruiz"])
    }
}

final class OwnershipTests: XCTestCase {
    func testCurrentUserPlaceholderResolvesToRealID() {
        let creator = CKRecord.ID(recordName: CKCurrentUserDefaultName)
        XCTAssertEqual(CloudKitService.ownerID(creator: creator, currentUserID: "me"), "me")
    }

    func testOtherCreatorIsPreserved() {
        let creator = CKRecord.ID(recordName: "someone")
        XCTAssertEqual(CloudKitService.ownerID(creator: creator, currentUserID: "me"), "someone")
    }

    func testMissingIdentityHasNoOwner() {
        let creator = CKRecord.ID(recordName: CKCurrentUserDefaultName)
        XCTAssertNil(CloudKitService.ownerID(creator: creator, currentUserID: nil))
        XCTAssertNil(CloudKitService.ownerID(creator: nil, currentUserID: "me"))
    }

    func testCannotEditAnotherArtistsWork() async {
        let backend = DemoBackend(mode: "collector")
        let other = try! await backend.artworks(ownerID: "artist-sofia")[0]
        do {
            _ = try await backend.saveArtwork(other, images: nil)
            XCTFail("Expected ownership failure")
        } catch {
            XCTAssertEqual((error as? AppError)?.errorDescription, AppError.notOwner.errorDescription)
        }
    }

    func testAccountDeletionRemovesPublicRecords() async throws {
        let backend = DemoBackend(mode: "artist")
        try await backend.deleteAccount()
        let works = try await backend.artworks(ownerID: "artist-sofia")
        let profile = try await backend.profile(ownerID: "artist-sofia")
        XCTAssertTrue(works.isEmpty)
        XCTAssertNil(profile)
    }
}

final class SearchTokenTests: XCTestCase {
    func testTokensAreNormalizedAndUnique() {
        XCTAssertEqual(SearchTokens.make(from: ["Café Blue", "blue, OCEAN!"]), ["blue", "cafe", "ocean"])
    }

    func testSingleCharactersAreDropped() {
        XCTAssertEqual(SearchTokens.words(in: "A big sky"), ["big", "sky"])
    }

    func testFilterPredicateIncludesRefinements() {
        var filters = ArtworkFilters()
        XCTAssertEqual(ArtworkMapper.predicate(for: filters), NSPredicate(value: true))
        filters.text = "blue"
        filters.styles = [.abstract]
        filters.minPrice = 100
        let format = ArtworkMapper.predicate(for: filters).predicateFormat
        XCTAssertTrue(format.contains("searchTokens"))
        XCTAssertTrue(format.contains("style"))
        XCTAssertTrue(format.contains("price"))
    }
}

final class ContentRuleTests: XCTestCase {
    func testFilterBlocksTermsRegardlessOfCase() {
        XCTAssertFalse(ContentFilter.isAllowed("Great PORN deal"))
    }

    func testFilterAllowsFineArtLanguage() {
        XCTAssertTrue(ContentFilter.isAllowed("Classical nude study in Essex", "Scunthorpe landscape"))
    }

    func testContactLinksRejectUnsafeValues() {
        XCTAssertNil(ContactLinks.websiteURL("javascript:alert(1)"))
        XCTAssertNil(ContactLinks.websiteURL("http://example.com"))
        XCTAssertNil(ContactLinks.websiteURL("https://user:pass@example.com"))
        XCTAssertNil(ContactLinks.instagramURL("../evil"))
        XCTAssertNil(ContactLinks.mailURL("a@b.com?bcc=x@y.com"))
    }

    func testContactLinksNormalizeValidValues() {
        XCTAssertEqual(ContactLinks.websiteURL("example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(ContactLinks.instagramURL("@ana.paints")?.absoluteString, "https://www.instagram.com/ana.paints/")
        XCTAssertEqual(ContactLinks.mailURL("ana@example.com")?.absoluteString, "mailto:ana@example.com")
    }
}

final class ImagePipelineTests: XCTestCase {
    func testImagesAreResizedForUpload() throws {
        let size = CGSize(width: 4000, height: 3000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let output = try ImageProcessor.process(source)
        let full = try XCTUnwrap(UIImage(data: output.full))
        let thumb = try XCTUnwrap(UIImage(data: output.thumbnail))
        XCTAssertEqual(max(full.size.width, full.size.height) * full.scale, 2048)
        XCTAssertEqual(max(thumb.size.width, thumb.size.height) * thumb.scale, 600)
    }

    func testInvalidImageThrows() {
        XCTAssertThrowsError(try ImageProcessor.process(Data([1, 2, 3])))
    }
}

import CloudKit
import UIKit
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

@MainActor
final class SessionTests: XCTestCase {
    func testProfileFailureKeepsSignedInIdentityAndRecovers() async {
        let backend = DemoBackend(mode: "artist")
        backend.failsProfileLoads = true
        let state = AppState(backend: backend)
        await state.reloadSession()
        XCTAssertEqual(state.session, .profileUnavailable(userID: "artist-sofia"))
        XCTAssertTrue(state.hasICloud)

        backend.failsProfileLoads = false
        await state.reloadSession()
        XCTAssertEqual(state.profile?.id, "artist-sofia")
    }

    func testTransientFailureKeepsCurrentProfile() async {
        let backend = DemoBackend(mode: "artist")
        let state = AppState(backend: backend)
        await state.reloadSession()
        backend.failsProfileLoads = true
        await state.reloadSession()
        XCTAssertEqual(state.profile?.id, "artist-sofia")
    }

    func testAccountSwitchFailureClearsPreviousUser() async {
        let backend = DemoBackend(mode: "collector")
        let state = AppState(backend: backend)
        await state.reloadSession()
        XCTAssertFalse(state.library.saved.isEmpty)

        backend.switchAccount(to: "artist-sofia")
        backend.failsProfileLoads = true
        await state.reloadSession(resetIdentity: true)
        XCTAssertNil(state.profile)
        XCTAssertEqual(state.library, UserLibrary())
        XCTAssertEqual(state.session, .profileUnavailable(userID: "artist-sofia"))
    }

    func testIdentityFailureAfterAccountChangeBecomesGuest() async {
        let backend = DemoBackend(mode: "collector")
        let state = AppState(backend: backend)
        await state.reloadSession()

        backend.failsIdentityLoads = true
        await state.reloadSession(resetIdentity: true)
        XCTAssertEqual(state.session, .guest)
        XCTAssertEqual(state.library, UserLibrary())
    }
}

@MainActor
final class FirstTimeAccountTests: XCTestCase {
    func testCreateAccountSavesProfileAndEntersApp() async throws {
        let state = AppState(backend: DemoBackend(mode: "new"))
        try await state.createAccount(displayName: "Ana Ruiz", role: .artist, contactEmail: "ana@example.com")
        XCTAssertEqual(state.profile?.role, .artist)
        XCTAssertEqual(state.profile?.contactEmail, "ana@example.com")
        XCTAssertTrue(state.showFirstTimeSetup)
        XCTAssertTrue(state.hasEnteredApp)
    }

    func testCreateAccountDoesNotOverwriteExistingProfile() async throws {
        let state = AppState(backend: DemoBackend(mode: "artist"))
        try await state.createAccount(displayName: "Someone Else", role: .collector, contactEmail: "")
        XCTAssertEqual(state.profile?.displayName, "Sofia Martinez")
        XCTAssertFalse(state.showFirstTimeSetup)
    }

    func testSignInWithoutProfileAsksToSignUp() async {
        let state = AppState(backend: DemoBackend(mode: "new"))
        let result = await state.continueWithICloud()
        XCTAssertEqual(result, .needsProfile)
    }

    func testGuestSignInShowsICloudPrompt() async {
        let state = AppState(backend: DemoBackend(mode: "guest"))
        let result = await state.continueWithICloud()
        XCTAssertEqual(result, .noICloud)
        XCTAssertTrue(state.showICloudPrompt)
    }

    func testDemoUnlocksFeaturesWithoutPersistingEntry() async {
        let key = "hasEnteredApp"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.set(false, forKey: key)

        let live = DemoBackend(mode: "guest")
        let state = AppState(backend: live)
        await state.startDemo(as: .artist)
        XCTAssertTrue(state.isDemoMode)
        XCTAssertTrue(state.isArtist)
        XCTAssertTrue(state.hasEnteredApp)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))

        await state.exitDemo()
        XCTAssertFalse(state.isDemoMode)
        XCTAssertTrue(state.backend === live)
        XCTAssertNil(state.profile)
        XCTAssertFalse(state.hasEnteredApp)
    }

    func testDeletingDemoAccountExitsDemo() async {
        let state = AppState(backend: DemoBackend(mode: "guest"))
        await state.startDemo(as: .collector)
        let deleted = await state.deleteAccount()
        XCTAssertTrue(deleted)
        XCTAssertFalse(state.isDemoMode)
        XCTAssertNil(state.profile)
    }
}

final class ArtCollectionTests: XCTestCase {
    func testCollectionIDsAreUnique() {
        XCTAssertEqual(Set(ArtCollection.all.map(\.id)).count, ArtCollection.all.count)
    }

    @MainActor
    func testEmptyCollectionsAreHiddenAndUpfrontRefills() async {
        let thumbnails = CollectionThumbnails()
        await thumbnails.prepare(backend: DemoBackend(mode: "guest"), isVisible: { _ in true })
        let ids = thumbnails.available.map(\.id)
        XCTAssertFalse(ids.contains("portrait"))
        XCTAssertTrue(ids.contains("minimalism"))
        XCTAssertEqual(thumbnails.upfront.count, 8)
        XCTAssertEqual(thumbnails.upfront + thumbnails.more, thumbnails.available)
    }

    @MainActor
    func testBlockedArtistsWorkDoesNotKeepCollectionVisible() async {
        let thumbnails = CollectionThumbnails()
        await thumbnails.prepare(backend: DemoBackend(mode: "guest"), isVisible: { $0.artistId != "artist-sofia" })
        XCTAssertFalse(thumbnails.available.map(\.id).contains("abstract"))
    }

    @MainActor
    func testLoadFailureDoesNotHideCollections() async {
        let backend = DemoBackend(mode: "guest")
        backend.failsArtworkLoads = true
        let thumbnails = CollectionThumbnails()
        await thumbnails.prepare(backend: backend, isVisible: { _ in true })
        XCTAssertEqual(thumbnails.available, ArtCollection.all)
    }

    func testCollectionMatchingAgreesWithBackendFilters() async throws {
        let backend = DemoBackend(mode: "guest")
        let catalog = try await backend.artworks(filters: ArtworkFilters(), cursor: nil).items
        for collection in ArtCollection.all {
            let results = try await backend.artworks(filters: collection.filters, cursor: nil).items
            XCTAssertEqual(Set(results.map(\.id)), Set(catalog.filter(collection.matches).map(\.id)), collection.title)
        }
    }
}

final class ArtworkDimensionTests: XCTestCase {
    func testOrientationComesFromRealDimensions() {
        XCTAssertTrue(ArtworkDimensions(width: 60, height: 80, unit: "cm").isPortrait)
        XCTAssertFalse(ArtworkDimensions(width: 120, height: 60, unit: "cm").isPortrait)
        XCTAssertFalse(ArtworkDimensions(width: 50, height: 50, unit: "cm").isPortrait)
    }

    func testInchesConvertForWallScale() {
        let size = ArtworkDimensions(width: 10, height: 20, unit: "in").sizeInCentimeters
        XCTAssertEqual(size.width, 25.4, accuracy: 0.001)
        XCTAssertEqual(size.height, 50.8, accuracy: 0.001)
    }

    func testInvalidDimensionsDoNotBreakLayout() {
        XCTAssertEqual(ArtworkDimensions(width: 0, height: 0, unit: "cm").aspectRatio, 1)
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

final class ShareFormatterTests: XCTestCase {
    private func artwork() -> Artwork {
        Artwork(id: "a1", artistId: "owner", artistName: "Ana Ruiz", title: "Blue Study", details: "", price: 1250, status: .sold, medium: .watercolor, style: .minimalism, dimensions: ArtworkDimensions(width: 30, height: 40, unit: "in"), year: 2025)
    }

    func testFormatsUseSocialDimensions() {
        XCTAssertEqual(ShareFormat.story.size, CGSize(width: 1080, height: 1920))
        XCTAssertEqual(ShareFormat.post.size, CGSize(width: 1080, height: 1350))
    }

    func testCaptionNamesArtworkWithoutPrice() {
        let caption = ShareFormatter.caption(for: .artwork(artwork(), preferredImage: nil))
        XCTAssertTrue(caption.contains("Blue Study by Ana Ruiz"))
        XCTAssertTrue(caption.contains(ShareFormatter.appStoreLink))
        XCTAssertFalse(caption.contains("1,250"))
    }

    func testProfileCaptionExcludesContactDetails() {
        var profile = UserProfile(id: "owner", displayName: "Ana Ruiz", role: .artist)
        profile.contactEmail = "ana@example.com"
        let caption = ShareFormatter.caption(for: .artist(profile))
        XCTAssertTrue(caption.contains("Ana Ruiz"))
        XCTAssertFalse(caption.contains("ana@example.com"))
    }

    func testDisplayTagsAreCleanedDedupedAndLimited() {
        let tags = ShareFormatter.displayTags(["#Ocean ", "ocean", "", " # ", "calm", "blue", "extra"])
        XCTAssertEqual(tags, ["Ocean", "calm", "blue"])
    }

    func testCaptionIsWithheldFromThirdPartyShareTargets() {
        XCTAssertNil(ShareFormatter.caption("Caption", for: UIActivity.ActivityType("com.burbn.instagram.shareextension")))
        XCTAssertNil(ShareFormatter.caption("Caption", for: nil))
        XCTAssertEqual(ShareFormatter.caption("Caption", for: .message), "Caption")
    }
}

final class PriceOnRequestTests: XCTestCase {
    private func artwork(price: Double, onRequest: Bool = false) -> Artwork {
        var art = Artwork(id: UUID().uuidString, artistId: "owner", title: "Amber Reflections", details: "", price: price, status: .available, medium: .acrylic, style: .abstract, dimensions: ArtworkDimensions(width: 60, height: 90, unit: "cm"), year: 2026)
        art.priceOnRequest = onRequest
        return art
    }

    func testPriceOnRequestRoundTripsAndStoresZero() throws {
        let record = CKRecord(recordType: "Artwork", recordID: CKRecord.ID(recordName: "a1"))
        ArtworkMapper.apply(artwork(price: 900, onRequest: true), to: record)
        XCTAssertEqual(record["price"] as? Double, 0)
        let mapped = try XCTUnwrap(ArtworkMapper.artwork(from: record, ownerID: "owner", thumbnailURL: nil))
        XCTAssertTrue(mapped.priceOnRequest)
        XCTAssertEqual(mapped.priceText, "Price on request")
    }

    func testRecordsWithoutTheFieldArePriced() throws {
        let record = CKRecord(recordType: "Artwork")
        ArtworkMapper.apply(artwork(price: 450), to: record)
        record["priceOnRequest"] = nil
        let mapped = try XCTUnwrap(ArtworkMapper.artwork(from: record, ownerID: "owner", thumbnailURL: nil))
        XCTAssertFalse(mapped.priceOnRequest)
        XCTAssertEqual(mapped.priceText, "$450")
    }

    func testPriceLimitsExcludePriceOnRequest() {
        var filters = ArtworkFilters()
        XCTAssertTrue(filters.matchesPrice(artwork(price: 0, onRequest: true)))
        filters.maxPrice = 1000
        XCTAssertFalse(filters.matchesPrice(artwork(price: 0, onRequest: true)))
        XCTAssertTrue(filters.matchesPrice(artwork(price: 800)))
        XCTAssertTrue(ArtworkMapper.predicate(for: filters).predicateFormat.contains("price > 0"))
    }

    func testPriceSortPutsPriceOnRequestLast() {
        let onRequest = artwork(price: 0, onRequest: true)
        let cheap = artwork(price: 100)
        let dear = artwork(price: 900)
        var filters = ArtworkFilters()
        filters.sortBy = .priceAsc
        XCTAssertEqual(filters.ordered([onRequest, cheap, dear]).map(\.id), [cheap.id, dear.id, onRequest.id])
        filters.sortBy = .newest
        XCTAssertEqual(filters.ordered([onRequest, cheap]).map(\.id), [onRequest.id, cheap.id])
    }
}

final class BuyerMessageTests: XCTestCase {
    private let art = Artwork(id: "a1", artistId: "owner", title: "Amber Reflections", details: "", price: 1450, status: .available, medium: .acrylic, style: .abstract, dimensions: ArtworkDimensions(width: 60, height: 90, unit: "cm"), year: 2026)

    private func decoded(_ url: URL?) throws -> (to: String, subject: String, body: String) {
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(url), resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        return (components.path,
                items.first { $0.name == "subject" }?.value ?? "",
                items.first { $0.name == "body" }?.value ?? "")
    }

    func testOfferEmailNamesAmountListingAndNote() throws {
        let url = BuyerMessage.offerURL(email: "sofia@example.com", artistName: "Sofia Martinez", artwork: art, amount: 1200, note: "Could you ship to Lisbon? A&B")
        let mail = try decoded(url)
        XCTAssertEqual(mail.to, "sofia@example.com")
        XCTAssertEqual(mail.subject, "Offer for \u{201C}Amber Reflections\u{201D}")
        XCTAssertTrue(mail.body.hasPrefix("Hi Sofia,"))
        XCTAssertTrue(mail.body.contains("$1,200"))
        XCTAssertTrue(mail.body.contains("listed on Artist Folio at $1,450"))
        XCTAssertTrue(mail.body.contains("Lisbon? A&B"), "ampersands and question marks must survive encoding")
    }

    func testOfferNoteIsCapped() throws {
        let mail = try decoded(BuyerMessage.offerURL(email: "sofia@example.com", artistName: "Sofia", artwork: art, amount: 100, note: String(repeating: "x", count: 1000)))
        XCTAssertFalse(mail.body.contains(String(repeating: "x", count: BuyerMessage.maxNoteLength + 1)))
    }

    func testPriceEnquiryAndInvalidEmail() throws {
        let mail = try decoded(BuyerMessage.priceEnquiryURL(email: "sofia@example.com", artistName: "Sofia Martinez", artwork: art))
        XCTAssertTrue(mail.body.contains("Could you tell me the price"))
        XCTAssertNil(BuyerMessage.priceEnquiryURL(email: "not-an-email", artistName: "Sofia", artwork: art))
    }

    func testAmountParsing() {
        XCTAssertEqual(BuyerMessage.amount(from: "$1,200"), 1200)
        XCTAssertEqual(BuyerMessage.amount(from: " 950.5 "), 950.5)
        XCTAssertNil(BuyerMessage.amount(from: "0"))
        XCTAssertNil(BuyerMessage.amount(from: "abc"))
    }
}

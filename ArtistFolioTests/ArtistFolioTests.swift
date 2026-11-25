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
        XCTAssertTrue(caption.contains("https://artistfolioapp.com/a/"))
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
        let url = BuyerMessage.offerURL(via: .email("sofia@example.com"), artistName: "Sofia Martinez", artwork: art, amount: 1200, note: "Could you ship to Lisbon? A&B")
        let mail = try decoded(url)
        XCTAssertEqual(mail.to, "sofia@example.com")
        XCTAssertEqual(mail.subject, "Offer for \u{201C}Amber Reflections\u{201D}")
        XCTAssertTrue(mail.body.hasPrefix("Hi Sofia,"))
        XCTAssertTrue(mail.body.contains("$1,200"))
        XCTAssertTrue(mail.body.contains("listed on Artist Folio at $1,450"))
        XCTAssertTrue(mail.body.contains("Lisbon? A&B"), "ampersands and question marks must survive encoding")
    }

    func testOfferNoteIsCapped() throws {
        let mail = try decoded(BuyerMessage.offerURL(via: .email("sofia@example.com"), artistName: "Sofia", artwork: art, amount: 100, note: String(repeating: "x", count: 1000)))
        XCTAssertFalse(mail.body.contains(String(repeating: "x", count: BuyerMessage.maxNoteLength + 1)))
    }

    func testPriceEnquiryAndInvalidEmail() throws {
        let mail = try decoded(BuyerMessage.priceEnquiryURL(via: .email("sofia@example.com"), artistName: "Sofia Martinez", artwork: art))
        XCTAssertTrue(mail.body.contains("Could you tell me the price"))
        XCTAssertNil(BuyerMessage.priceEnquiryURL(via: .email("not-an-email"), artistName: "Sofia", artwork: art))
    }

    func testAmountParsing() {
        XCTAssertEqual(BuyerMessage.amount(from: "$1,200"), 1200)
        XCTAssertEqual(BuyerMessage.amount(from: " 950.5 "), 950.5)
        XCTAssertNil(BuyerMessage.amount(from: "0"))
        XCTAssertNil(BuyerMessage.amount(from: "abc"))
    }
}

final class PhoneContactTests: XCTestCase {
    func testPhoneNumbersNormalize() {
        XCTAssertEqual(ContactLinks.phoneNumber("+34 612-345 678"), "+34612345678")
        XCTAssertEqual(ContactLinks.phoneNumber("(415) 555 0100"), "4155550100")
        XCTAssertNil(ContactLinks.phoneNumber("12345"))
        XCTAssertNil(ContactLinks.phoneNumber("call me maybe"))
        XCTAssertNil(ContactLinks.phoneNumber("+1 555 0100 ext 2"))
    }

    func testCallTextAndWhatsAppLinks() {
        XCTAssertEqual(ContactLinks.callURL("+34 612 345 678")?.absoluteString, "tel:+34612345678")
        XCTAssertEqual(ContactLinks.textURL("+34 612 345 678")?.absoluteString, "sms:+34612345678")
        XCTAssertEqual(ContactLinks.whatsappURL("+34 612 345 678")?.absoluteString, "https://wa.me/34612345678")
        XCTAssertNil(ContactLinks.whatsappURL("612 345 678"), "WhatsApp needs the country code")
    }

    func testProfileOffersPhoneOptionsInOrder() {
        let profile = UserProfile(id: "a", displayName: "Sofia", role: .artist, contactEmail: "sofia@example.com", phone: "+34 612 345 678", whatsapp: "+34 612 345 678")
        XCTAssertEqual(profile.contactOptions.map(\.kind), [.email, .whatsapp, .call, .text])
    }

    func testPhoneFieldsRoundTrip() throws {
        let record = CKRecord(recordType: "Profile")
        let profile = UserProfile(id: "a", displayName: "Sofia", role: .artist, phone: "+34 612 345 678", whatsapp: "+34 612 345 678")
        ProfileMapper.apply(profile, to: record)
        let mapped = try XCTUnwrap(ProfileMapper.profile(from: record, ownerID: "a", avatarURL: nil))
        XCTAssertEqual(mapped.phone, "+34 612 345 678")
        XCTAssertEqual(mapped.whatsapp, "+34 612 345 678")
    }

    func testOfferByWhatsAppCarriesTheMessage() throws {
        let art = Artwork(id: "a1", artistId: "a", title: "Amber Reflections", details: "", price: 1450, status: .available, medium: .acrylic, style: .abstract, dimensions: ArtworkDimensions(width: 60, height: 90, unit: "cm"), year: 2026)
        let url = try XCTUnwrap(BuyerMessage.offerURL(via: .whatsapp("+34 612 345 678"), artistName: "Sofia Martinez", artwork: art, amount: 1200, note: "Is it framed? A&B"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "wa.me")
        XCTAssertEqual(components.path, "/34612345678")
        let text = try XCTUnwrap(components.queryItems?.first { $0.name == "text" }?.value)
        XCTAssertTrue(text.contains("$1,200"))
        XCTAssertTrue(text.contains("Is it framed? A&B"))
    }

    func testChannelsSkipInvalidContacts() {
        let artist = UserProfile(id: "a", displayName: "Sofia", role: .artist, contactEmail: "bad", whatsapp: "+34 612 345 678")
        XCTAssertEqual(BuyerMessage.channels(for: artist), [.whatsapp("+34 612 345 678")])
        XCTAssertTrue(BuyerMessage.channels(for: nil).isEmpty)
    }
}

final class ArtistSummaryTests: XCTestCase {
    private func art(_ price: Double, _ status: ArtworkStatus = .available, medium: ArtworkMedium = .acrylic, onRequest: Bool = false) -> Artwork {
        var art = Artwork(id: UUID().uuidString, artistId: "a", title: "T", details: "", price: price, status: status, medium: medium, style: .abstract, dimensions: ArtworkDimensions(width: 50, height: 50, unit: "cm"), year: 2026)
        art.priceOnRequest = onRequest
        return art
    }

    func testStatsCountWorksSoldAndLowestAvailablePrice() {
        let summary = ArtistSummary(artworks: [art(1450), art(400), art(300, .sold), art(0, onRequest: true), art(250, .reserved)])
        XCTAssertEqual(summary.stats.map(\.label), ["Works", "Sold", "From"])
        XCTAssertEqual(summary.stats.map(\.value), ["5", "1", "$400"])
        XCTAssertTrue(summary.showsCard)
    }

    func testZeroStatsAreHiddenAndCardNeedsTwo() {
        let summary = ArtistSummary(artworks: [art(0, onRequest: true)])
        XCTAssertEqual(summary.stats.map(\.label), ["Work"])
        XCTAssertFalse(summary.showsCard)
        XCTAssertFalse(ArtistSummary(artworks: []).showsCard)
    }

    func testTopMediumsByCount() {
        let summary = ArtistSummary(artworks: [art(1, medium: .oilOnCanvas), art(1, medium: .watercolor), art(1, medium: .watercolor), art(1, medium: .drawing), art(1, medium: .acrylic)])
        XCTAssertEqual(summary.topMediums.first, .watercolor)
        XCTAssertEqual(summary.topMediums.count, 3)
    }

    func testCompactPrice() {
        XCTAssertEqual(ArtistSummary.compactPrice(400), "$400")
        XCTAssertEqual(ArtistSummary.compactPrice(1200), "$1.2K")
        XCTAssertEqual(ArtistSummary.compactPrice(3000), "$3K")
        XCTAssertEqual(ArtistSummary.compactPrice(15500), "$16K")
    }
}

final class CareGuideTests: XCTestCase {
    func testEveryMediumHasFourTips() {
        for medium in ArtworkMedium.allCases {
            let tips = CareGuide.tips(for: medium)
            XCTAssertEqual(tips.count, 4, medium.rawValue)
            XCTAssertEqual(Set(tips.map(\.text)).count, 4, "duplicate tip for \(medium.rawValue)")
        }
    }

    func testCareFieldsRoundTripAndNoteIsCapped() throws {
        var art = Artwork(id: "a1", artistId: "o", title: "T", details: "", price: 10, status: .available, medium: .acrylic, style: .abstract, dimensions: ArtworkDimensions(width: 1, height: 1, unit: "cm"), year: 2026)
        art.careNote = "  " + String(repeating: "v", count: 400) + "  "
        art.showCareTips = false
        let record = CKRecord(recordType: "Artwork")
        ArtworkMapper.apply(art, to: record)
        let mapped = try XCTUnwrap(ArtworkMapper.artwork(from: record, ownerID: "o", thumbnailURL: nil))
        XCTAssertEqual(mapped.careNote.count, CareGuide.maxNoteLength)
        XCTAssertFalse(mapped.showCareTips)
    }

    func testOlderListingsShowStandardTips() throws {
        let art = Artwork(id: "a1", artistId: "o", title: "T", details: "", price: 10, status: .available, medium: .acrylic, style: .abstract, dimensions: ArtworkDimensions(width: 1, height: 1, unit: "cm"), year: 2026)
        let record = CKRecord(recordType: "Artwork")
        ArtworkMapper.apply(art, to: record)
        record["showCareTips"] = nil
        record["careNote"] = nil
        let mapped = try XCTUnwrap(ArtworkMapper.artwork(from: record, ownerID: "o", thumbnailURL: nil))
        XCTAssertTrue(mapped.showCareTips)
        XCTAssertEqual(mapped.careNote, "")
    }
}

final class SeriesAndSizeTests: XCTestCase {
    private func dims(_ w: Double, _ h: Double, _ unit: String = "cm") -> ArtworkDimensions {
        ArtworkDimensions(width: w, height: h, unit: unit)
    }

    func testSizeBandsUseLongestSideInCentimeters() {
        XCTAssertEqual(dims(30, 39).sizeClass, .small)
        XCTAssertEqual(dims(30, 40).sizeClass, .medium)
        XCTAssertEqual(dims(100, 60).sizeClass, .medium)
        XCTAssertEqual(dims(122, 80).sizeClass, .large)
        XCTAssertEqual(dims(16, 20, "in").sizeClass, .medium, "20 in is about 51 cm")
    }

    func testSeriesAndSizeAreSavedAndSearchable() throws {
        var art = Artwork(id: "a1", artistId: "o", title: "Dusk", details: "", price: 10, status: .available, medium: .acrylic, style: .abstract, dimensions: dims(122, 80), year: 2026)
        art.series = "  Autumn Water  "
        let record = CKRecord(recordType: "Artwork")
        ArtworkMapper.apply(art, to: record)
        XCTAssertEqual(record["sizeClass"] as? String, "large")
        XCTAssertEqual(record["series"] as? String, "Autumn Water")
        XCTAssertTrue((record["searchTokens"] as? [String] ?? []).contains("autumn"))
        let mapped = try XCTUnwrap(ArtworkMapper.artwork(from: record, ownerID: "o", thumbnailURL: nil))
        XCTAssertEqual(mapped.series, "Autumn Water")
    }

    func testSizeFilterReachesPredicateAndCollections() {
        var filters = ArtworkFilters()
        filters.sizes = [.small]
        XCTAssertTrue(filters.hasRefinements)
        XCTAssertTrue(ArtworkMapper.predicate(for: filters).predicateFormat.contains("sizeClass"))
    }

    func testDemoSizeFilter() async throws {
        let backend = DemoBackend(mode: "collector")
        var filters = ArtworkFilters()
        filters.sizes = [.large]
        let page = try await backend.artworks(filters: filters, cursor: nil)
        XCTAssertFalse(page.items.isEmpty)
        XCTAssertTrue(page.items.allSatisfy { $0.dimensions.sizeClass == .large })
    }
}

final class AppLinkTests: XCTestCase {
    func testLinksRoundTrip() {
        for link in [AppLink.artwork(id: "6F1C2A9E-0B7D-4E21-9C55-3A1B2C3D4E5F"), .artist(id: "_a1b2c3d4e5f6")] {
            XCTAssertEqual(AppLink(url: link.url), link)
        }
        XCTAssertEqual(AppLink.artwork(id: "abc").url.absoluteString, "https://artistfolioapp.com/a/abc")
    }

    func testParsingAcceptsWwwAndTrailingSlash() {
        XCTAssertEqual(AppLink(url: URL(string: "https://www.artistfolioapp.com/a/abc/")!), .artwork(id: "abc"))
        XCTAssertEqual(AppLink(url: URL(string: "https://ArtistFolioApp.com/artist/_xyz")!), .artist(id: "_xyz"))
    }

    func testParsingRejectsOtherLinks() {
        for text in ["http://artistfolioapp.com/a/abc", "https://evil.com/a/abc", "https://artistfolioapp.com/privacy.html",
                     "https://artistfolioapp.com/a/", "https://artistfolioapp.com/a/abc/extra", "https://artistfolioapp.com/a/ab%20c"] {
            XCTAssertNil(AppLink(url: URL(string: text)!), text)
        }
    }

    func testOpenSetsLinkOnlyForKnownLinks() async {
        let state = await AppState(backend: DemoBackend(mode: "collector"))
        let opened = await state.open(URL(string: "https://artistfolioapp.com/a/art-2")!)
        XCTAssertTrue(opened)
        let link = await state.openedLink
        XCTAssertEqual(link, .artwork(id: "art-2"))
        let ignored = await state.open(URL(string: "https://example.com")!)
        XCTAssertFalse(ignored)
    }

    func testShareCaptionUsesArtistLink() {
        let profile = UserProfile(id: "_abc", displayName: "Ana Ruiz", role: .artist)
        XCTAssertTrue(ShareFormatter.caption(for: .artist(profile)).contains("https://artistfolioapp.com/artist/_abc"))
    }

    func testQRCodeEncodesTheLink() throws {
        let url = AppLink.artwork(id: "art-2").url
        let image = try XCTUnwrap(QRCode.image(for: url))
        XCTAssertGreaterThanOrEqual(image.size.width, 500)
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let features = detector.features(in: try XCTUnwrap(CIImage(image: image))) as? [CIQRCodeFeature]
        XCTAssertEqual(features?.first?.messageString, url.absoluteString)
    }
}

final class ReviewTests: XCTestCase {
    private func review(_ rating: Int, by reviewer: String = UUID().uuidString, of artist: String = "artist-sofia") -> Review {
        Review(artistID: artist, reviewerID: reviewer, rating: rating, text: "Great", relationship: .bought)
    }

    func testAverageNeedsThreeReviews() {
        let two = ReviewSummary(reviews: [review(5), review(1)])
        XCTAssertFalse(two.showsAverage)
        XCTAssertEqual(two.countText, "2 reviews")
        let three = ReviewSummary(reviews: [review(5), review(4), review(4)])
        XCTAssertTrue(three.showsAverage)
        XCTAssertEqual(three.averageText, "4.3")
        XCTAssertEqual(ReviewSummary(reviews: [review(3)]).countText, "1 review")
    }

    func testRecordNameMeansOneReviewPerReviewerPerArtist() {
        XCTAssertEqual(review(5, by: "_me").id, review(2, by: "_me").id)
        XCTAssertNotEqual(review(5, by: "_me").id, review(5, by: "_me", of: "artist-elena").id)
    }

    func testMapperRoundTripsAndRejectsBadRatings() throws {
        var draft = review(4, by: "_me")
        draft.text = "  " + String(repeating: "a", count: 700)
        let record = CKRecord(recordType: "Review")
        ReviewMapper.apply(draft, to: record)
        let mapped = try XCTUnwrap(ReviewMapper.review(from: record, reviewerID: "_me"))
        XCTAssertEqual(mapped.rating, 4)
        XCTAssertEqual(mapped.text.count, Review.maxTextLength)
        record["rating"] = Int64(9)
        XCTAssertNil(ReviewMapper.review(from: record, reviewerID: "_me"))
    }

    func testDemoSavingReplacesAndBlocksSelfReview() async throws {
        let backend = DemoBackend(mode: "collector")
        let before = try await backend.reviews(artistID: "artist-elena").count
        _ = try await backend.saveReview(review(5, by: "ignored", of: "artist-elena"))
        _ = try await backend.saveReview(review(3, by: "ignored", of: "artist-elena"))
        let after = try await backend.reviews(artistID: "artist-elena")
        XCTAssertEqual(after.count, before + 1, "a second review replaces the first")
        XCTAssertEqual(after.first { $0.reviewerID == "collector-maya" }?.rating, 3)
        XCTAssertTrue(ReviewSummary(reviews: after).showsAverage)

        let artist = DemoBackend(mode: "artist")
        do {
            _ = try await artist.saveReview(review(5, of: "artist-sofia"))
            XCTFail("artists can't review themselves")
        } catch AppError.cannotReviewSelf {}
    }

    func testObjectionableReviewIsRejected() async {
        let backend = DemoBackend(mode: "collector")
        var bad = review(1, of: "artist-elena")
        bad.text = "this is shit"
        do {
            _ = try await backend.saveReview(bad)
            XCTFail("filtered text must not save")
        } catch AppError.objectionableContent {} catch { XCTFail("\(error)") }
    }

    @MainActor
    func testBlockedReviewersAreHidden() async {
        let state = AppState(backend: DemoBackend(mode: "collector"))
        await state.reloadSession()
        let model = ReviewsModel(artistID: "artist-sofia")
        await model.load(state)
        let total = model.reviews.count
        XCTAssertGreaterThan(total, 0)
        state.setBlocked("reviewer-daniel-okafor", blocked: true)
        await model.load(state)
        XCTAssertEqual(model.reviews.count, total - 1)
    }
}

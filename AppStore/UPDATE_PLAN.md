# ArtistFolio update plan: 1.1 and 1.2

Source: "Recommended V1 scope" in the research doc [ArtistFolio Competitor Analysis and V1 Plan](https://claude.ai/artifact/P9Tu1P7vhrnNxhJF4D7TZm), checked against the code on 2026-11-24.

**Starting point:** 1.0.0 (build 8) is approved and live on the App Store (as of 2026-11-24).

**Status (2026-11-24):** all of 1.1 (items 1–9) is built on `social-sharing` as version 1.1.0 (9). Release steps are in `RELEASE_1.1.md`. All of 1.2 is built on `universal-links-qr`: universal links, QR labels, reviews, and view, like and follower counts. It is not yet versioned, released or merged.

**1.2 release notes so far:**
- CloudKit: new `Review` record type (see `CloudKit/schema.ckdb`; `___createTime` must be sortable and `___createdBy` queryable). Deploy before release, along with any 1.1 fields not yet deployed.
- Website: universal link files are live (artistfolio-site `aa600fd`). The privacy policy needs a line for reviews before 1.2 ships: "Reviews you write — your rating, text and name, displayed publicly on the artist's profile."
- App Privacy: reviews fall under "Other User Content", already declared. Add them to that row's description.
- CloudKit (counts): new public types `ArtworkLike`, `ArtistFollow`, `ArtworkView` (targetID queryable, `___createdBy` queryable), plus Artwork `viewCount`, `likeCount` and Profile `followerCount`. Saves and follows still live privately; the public copies are written alongside and backfilled once per user. The artist's app recounts at most hourly when Studio opens.
- Privacy policy (counts): add "Views, saves and follows — recorded against your iCloud identifier so artists see totals; individual activity isn't shown in the app." Note that these public records can be read by anyone querying CloudKit directly.
- App Privacy (counts): add **Usage Data: Product Interaction** (linked to user, not tracking, App Functionality).
- Review notes: in Collector Demo, Elena Rossi has 2 reviews (no average); writing one makes the average appear. Report Review is in each review's "..." menu.

**Already built, so not in the plan:** multiple photos per artwork. Upload takes up to 5 photos (`UploadView.maxPhotos`), CloudKit stores them in `Artwork.images`, and the detail page shows a swipe gallery.

## 1.1: selling tools

No website work. All CloudKit changes add fields only.

| # | Feature | CloudKit change | Files | Effort |
|---|---|---|---|---|
| 1 | Price on request | Artwork `priceOnRequest INT64`, price saved as 0 | Models, ArtworkService mapper, UploadView (toggle, skip price check), cards + detail, SearchView | S |
| 2 | Make an Offer | none | ArtworkDetailView: amount + note sheet, then a prefilled email or WhatsApp message. Shown only when the piece is available and the artist has a contact | S |
| 3 | Phone, text, WhatsApp | Profile `phone STRING`, `whatsapp STRING` | ContentRules (`tel:`, `sms:`, `https://wa.me/<digits>`), ProfileEditorView ("shown publicly" warning), ProfileView | S |
| 4 | Series | Artwork `series STRING QUERYABLE` | UploadView field, "More from this series" on detail, series filter on ProfileView | M |
| 5 | Size filter | Artwork `sizeClass STRING QUERYABLE`, set on save | Longest side: under 40 cm small, 40–100 cm medium, over 100 cm large. SearchView chips | M |
| 6 | Listing header refresh | none | ArtworkDetailView info sheet. Our own design (see below) | S |
| 7 | Artwork care | Artwork `careNote STRING`, `showCareTips INT64` | New `CareGuide.swift` (standard tips per `ArtworkMedium`), UploadView "Care" section, ArtworkDetailView "Caring for this piece" under Details, care guide sheet (all mediums) linked from the listing, same guide on `docs/support.html` | M |
| 8 | Publishing footnote | none | UploadView: footnote card above Publish | S |
| 9 | Artist summary card | none | ArtistProfileView header: stats card, commissions card, medium chips. All worked out from the artworks the view already loads | S |

**Listing header refresh.** Rework the top of the detail info sheet so the key facts read at a glance: title, price, status, medium, style, size and year. The user's reference screenshot (title with price, tag chips, an icon stats row) is for inspiration only; do not copy its layout or look. Design it in the ArtistFolio Figma file first, using our own system: `AFSpacing`, `AFRadius`, `afPrimary`, `afTextSecondary`, the `afGlass` style and the existing `StatusBadge`. Leave room for the 1.2 stats row (views, likes, rating), so 1.2 can add it without another redesign.

**Design:** Figma file, Design page, section "1.1 Listing Refresh + Artwork Care". It has the header in three states (available, price on request, sold with the 1.2 stats slot), the care section on the listing, and the New Artwork care step with the publishing footnote.

**Artwork care.**
- **Standard tips:** set per medium in the app, about 4 each, and the artist can turn them off.
- **Artist's note:** up to 300 characters, passed through `ContentRules`, and shown first.
- **Full care guide:** covers every medium, opened from "Read the full care guide" on the listing, with the same text on the support page.

**Publishing footnote copy:** "By publishing, you confirm you created this work and hold its copyright. Selling the piece does not transfer reproduction rights unless you agree that with the buyer. Artist Folio takes no commission and does not handle payment or delivery." Have someone check the wording against the community terms before release.

**Artist summary card.**
- **Stats:** Works · Sold · From $X.
    - "Sold" counts pieces the artist marked sold. The label avoids "Sales", because sales happen outside the app.
    - "From $X" is the lowest available price, skipping price-on-request works.
    - A stat that is 0 is hidden. With fewer than two stats, the card is hidden.
- **Commissions card:** replaces today's one-line label. Its "Ask" button opens the artist's contact options.
- **Medium chips:** the top 3 mediums by artwork count.
- **No verified badge:** we have no way to verify artists.
- **Design:** same Figma section as the listing header.

Notes:
- **Size needs a stored field.** CloudKit can't filter on a value the app calculates. Fill `sizeClass` for existing artworks when they are next edited, or with a one-time backfill in Studio.
- **Price on request, older app:** 1.0 shows these artworks as "$0". That's acceptable while 1.0 has few users.
- **Price on request, filter:** any minimum above 0 hides them, so show them only when no price limit is set.
- **Price on request, sort:** sort them last in "Price: Low to High".
- **Demo mode:** add sample data to `DemoBackend` (one price-on-request piece, one series, an artist with WhatsApp).
- **Tests:** phone and WhatsApp link building, size classes, the offer message text.
- **Privacy:** add phone numbers to `docs/privacy.html` and recheck the App Privacy answers.

## 1.2: offline selling and trust

### Universal links and QR labels

1. **Universal links:**
   - Add the Associated Domains entitlement (`applinks:artistfolioapp.com`).
   - Host `/.well-known/apple-app-site-association` on the site.
   - Add a fallback page at `/a/<id>` that sends visitors without the app to the App Store.
   - Add `onOpenURL` handling that opens the artwork or artist.
2. **QR label screen (new `QRLabelView`):**
   - Make the QR code with `CIFilter.qrCodeGenerator`.
   - The label shows title, size, price (or "Price on request"), artist name and the QR code.
   - Render with `ImageRenderer` at print resolution, then share or print it.
   - Open it from Studio and from the share sheet.
3. **Shared links:** point `SocialShareView` at the artwork link instead of the App Store link.

### Artist reviews and ratings

**Data:** a new `Review` record type in the public database.
- Fields: `artistID STRING QUERYABLE`, `rating INT64` (1–5), `text STRING` (up to 500 characters), `relationship STRING` ("Bought a piece", "Commissioned", "Met at a show").
- Permissions: only the reviewer can write it (`_creator`), anyone can read it (`_world`), and any iCloud user can create one (`_icloud`).
- Record name `review_<reviewerID>_<artistID>`, so each person has one review per artist. A second review updates the first.

**Rules:**
- No reviewing yourself, and no reviewing in demo or guest mode.
- Text goes through the `ContentRules` filter.
- Add a `review` case to `ReportTarget`, with "Report review" in the review's menu. Hide reviews from blocked users.
- Artists can't delete reviews, only report them.
- Show the star average only at **3 or more reviews**. Below that, show "New artist".
- The app works out the average itself, because CloudKit runs no server code. Load at most about 200 reviews per artist.

**Screens:**
- ProfileView: stars and the review count under the name, a reviews section (newest first) and a "Write a review" button.
- ArtworkDetailView: small stars next to the artist's name.
- Share card: show the rating once there are 3 or more reviews.

**App Store:**
- The age rating doesn't change (it already declares user-generated content).
- Add reviews to App Privacy "Other User Content" and to the review notes in `SUBMISSION.md`.
- Add demo reviews to `DemoBackend` so App Review can see them.

**Tests:** the average, the 3-review minimum, blocked-user filtering, the one-review-per-artist record name.

**Effort:** Medium to Large.

### Artist summary card, 1.2 stats

The card becomes **Followers · Sold · Rating**.
- **Followers:** needs a public `ArtistFollow` record named `follow_<userID>_<artistID>`, written alongside the existing private follow. The artist's app counts follows and saves the total to Profile `followerCount INT64`, the same way as artwork view and like counts. Same privacy note as views and likes.
- **Rating:** comes from reviews and shows at 3 or more reviews.

### Artwork view and like counts

**Data:** two new public record types.
- `ArtworkLike`: written alongside the existing private save, named `like_<userID>_<artworkID>` (one per person per artwork). Saves themselves stay in the private database.
- `ArtworkView`: named `view_<userID>_<artworkID>`, so it counts unique signed-in viewers. Guests and demo mode are not counted.

**Counting:** CloudKit has no count query, and only the artist can write the Artwork record.
- The artist's app counts views and likes when Studio opens, at most once an hour.
- It saves the totals to new Artwork fields `viewCount INT64` and `likeCount INT64`.
- Everyone else reads those totals. They can be a few hours old, and stop updating if the artist stops opening the app.

**Display:**
- Stats row in the space the 1.1 header leaves for it.
- Hidden until a piece has at least 25 views or 5 likes. Artists always see their own numbers in Studio.

**Privacy:**
- These records must be readable by anyone, so a CloudKit query could show which (anonymous) accounts viewed or liked which artworks.
- Add App Privacy "Usage Data: Product Interaction", update `docs/privacy.html`, and add a line to the review notes.

**Also:** demo data in `DemoBackend`. Tests for the display minimum and the one-per-person record names.

**Effort:** Medium.

## Listing changes (with 1.1)

- Subtitle that leads with AR, e.g. "See Art on Your Wall in AR".
- Keywords: AR, wall preview, discover artists.
- Update the What's New text and one screenshot that shows Make an Offer.
- Trademark search for the name "ArtistFolio" (needs legal advice).

## Release steps for each version

1. Add the new fields and record types in CloudKit Development and update `CloudKit/schema.ckdb`.
2. Deploy the schema to Production **before** the release goes out.
3. Bump the version (1.1.0, then 1.2.0) and reset the build number.
4. Test on a device with real iCloud accounts and in demo mode.
5. Update the listing and screenshots, then submit.

## Later (V2)

Artist replies to reviews (needs a separate reply record type), enquiry inbox with stages, mailing list, CSV export, Face ID lock on Studio, any paid plan.

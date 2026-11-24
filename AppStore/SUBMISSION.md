# ArtistFolio 1.0.0: App Review Submission Plan

Updated 2026-11-23. Nothing has been changed in App Store Connect or CloudKit Production.

**Status: repo work is done. Five steps need your Apple account or your input (section 1).**

## Beta App Review: Guideline 2.1(a) response

ArtistFolio has no username or password because accounts use iCloud. Build 8 adds the demonstration mode Apple accepts instead.

1. Upload build 8 and select it for the external TestFlight group.
2. In TestFlight → Test Information → Beta App Review Information, leave **Sign-in required unchecked**.
3. Paste the reply below into **Review Notes**, then send the same text as your reply in App Store Connect.

```
Thank you for the review. ArtistFolio uses the device's iCloud account, so it has no username or password to provide. Build 8 adds a demonstration mode that requires no account or iCloud sign-in.

To access it:
1. Launch the app and tap Skip.
2. Tap Explore Demo at the bottom of the screen.
3. Tap Artist Demo or Collector Demo.

Artist Demo includes Home, Search, Studio, publishing, editing listings, sharing, saved art, following, reporting, blocking, and account deletion. Collector Demo includes browsing, saved art, following, contacting artists, reporting, and blocking.

Demo mode uses sample content stored only in memory and does not write to iCloud. To leave it, open Profile and tap Exit Demo. To try AR, open an artwork on a physical device and tap View on Wall.
```

## 1. Remaining steps, in order

1. **Publish the website.** GitHub Pages serves `docs/` from `main`, so the new email and privacy policy are not live until `social-sharing` is merged and pushed.
2. **Check CloudKit Production.** Sign in at [CloudKit Console](https://icloud.developer.apple.com/dashboard/), open `iCloud.com.artistfolio.app`, and confirm Production has the record types Profile, Artwork, Report, SavedArtwork, FollowedArtist and BlockedArtist. If not, use **Deploy Schema Changes**.
3. **Upload build 8.** In Xcode Organizer, select ArtistFolio 1.0.0 (8), then Distribute App → App Store Connect.
4. **Publish the seed artworks.** Complete `Production_Seed/LISTINGS.csv`, move `Production_Seed/selected/` to your iPhone, install build 8 from TestFlight, create your artist profile, and publish them in Studio. TestFlight writes to Production.
5. **Fill in App Store Connect** from sections 2 and 3, attach build 8, and submit.

Test on TestFlight before submitting: guest browsing, sign-up, publish, report, block, AR, share, and account deletion.

## 2. The six App Store Connect errors

### Primary category
- Primary: **Shopping**
- Secondary: **Entertainment**

### Content Rights (App Information)
- Contains third-party content: **Yes**, because artists publish their own work.
- Confirm you have the necessary rights to all art shown in store assets and seed listings.

### 13-inch iPad screenshots
Upload the four 2064 x 2752 images in `AppStore/screenshots-ipad-13in/`.

### iPhone screenshots
Upload from `AppStore/screenshots/` (1290 x 2796): `01-where-art-finds-its-home`, `02-discover-original-art`, `03-your-personal-art-feed`, `04-follow-and-contact-artists`, `05-contact-the-artist`.

Do not upload anything from `AppStore/_to_delete/`. It holds the assets that advertised chat, including preview video 02.

### App Privacy
Data collected: **Yes**. Tracking: **No**. For every type below: Linked to user **Yes**, Used for tracking **No**, Purpose **App Functionality**.

| App Store Connect type | ArtistFolio data |
|---|---|
| Contact Info: Name | Display name |
| Contact Info: Email Address | Artist contact email |
| Contact Info: Other User Contact Info | Website, Instagram handle |
| Identifiers: User ID | CloudKit user record ID |
| User Content: Photos or Videos | Artwork images, profile photo |
| User Content: Other User Content | Bio, location text, listings, report notes |

Do not declare saved art, follows or blocks: they stay in the user's private iCloud database. AR camera frames stay on device. The app has no analytics, ads or tracking SDKs.

### Pricing
- Price: **Free (USD 0)**
- In-app purchases: **None**
- Availability: choose your countries. If you include the EU, complete the **trader status** declaration in App Store Connect.

### Privacy Policy URL
`https://chinmaylaghate.github.io/ArtistFolio/privacy.html`

Support URL: `https://chinmaylaghate.github.io/ArtistFolio/support.html`

## 3. Paste-ready copy

### Description

```
ArtistFolio connects independent artists with collectors who love original art.

Browse paintings, photography, sculpture, and mixed media from independent artists. When something speaks to you, preview it on your own wall with augmented reality.

FOR COLLECTORS
• Discover original works across every medium
• Preview artwork in your room with AR
• Save pieces to your personal library
• Follow your favorite artists
• Contact artists directly by email, Instagram, or their website

FOR ARTISTS
• Publish your portfolio with photos, a title, and a price
• Manage your listings in a clean, focused Studio
• Share your artwork and profile
• Keep 100% of your sale. ArtistFolio takes no commission

PRIVACY FIRST
Browse as a guest with no sign-in. Create a profile using your iCloud account to save art, follow artists, or publish work. Saved art and follows stay in your private iCloud database.

ArtistFolio does not process payments. Buyers and artists arrange payment and delivery directly.

No ads. No trackers.
```

### Notes for App Review

```
ArtistFolio is an art discovery and portfolio app. Guests can browse artwork without signing in.

DEMO MODE: No account is required. Launch the app, tap Skip, tap Explore Demo, then choose Artist Demo or Collector Demo to access all features with sample content. To leave, open Profile and tap Exit Demo.

PAYMENTS: The app sells no digital goods and processes no payments. Listings are physical artworks. Buyers contact artists directly and arrange payment and delivery outside the app.

USER-GENERATED CONTENT: Users must accept the community terms before creating a profile. Text is filtered for objectionable terms. Report and Block are in the "..." menu on every artwork and artist profile. We review submitted reports and remove content that violates the terms.

ACCOUNT DELETION: Profile tab > Delete Account.

AR: Open an artwork and tap View on Wall. This requires a physical device with ARKit world tracking.
```

### Age rating
Answer the live form, because Apple's questionnaire changed in 2025 and 2026:
- User-generated content: **Yes**
- Messaging and chat: **No**
- Advertising: **No**
- Unrestricted web access: **No**
- Social media: **Likely Yes**, because the app has a discovery feed and follows. Read Apple's definition on the form.
- Nudity: if figurative nudes are allowed, do not answer None, because image uploads are not automatically screened.
- Minimum age: set at least **13+**, matching the privacy policy.

## 4. Moderation note

The app no longer promises a 24-hour review or bans. Report and Block remain because App Review Guideline 1.2 requires them for user-generated content, and it also expects timely action on reports. Check Report records in CloudKit Console regularly and remove violating content there.

## Sources

- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Age rating questionnaire social media update](https://developer.apple.com/news/?id=tlur8uvi)

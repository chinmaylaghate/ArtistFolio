# ArtistFolio 1.0.0: App Review Submission Plan

Updated 2026-11-23.

**Status: version 1.0.0 (build 8) is added for review and sits in a draft submission. It is not submitted yet.**

## 1. Remaining steps, in order

1. **Done:** the six staged files below were uploaded on 2026-11-23. They are in `AppStore/Upload_Now/`:

   | File | App Store Connect slot |
   |---|---|
   | `iPad13_01_home.png` to `iPad13_04_studio.png` | Version page → App Previews and Screenshots → iPad 13" display |
   | `iPhone63_04_follow-and-contact-artists.png` | iPhone tab → replace the 4th screenshot ("Follow and talk to artists") |
   | `SearchResults_1920x1280.png` | Header and Search Results → Search Results → replace the "Talk to the artist" asset |

2. **Done:** Add for Review. **Still to do:** click **Submit for Review** in the Draft Submission panel.
3. **Before real users arrive:** confirm CloudKit Production has the record types Profile, Artwork, Report, SavedArtwork, FollowedArtist and BlockedArtist in [CloudKit Console](https://icloud.developer.apple.com/dashboard/). Then publish the seed artworks: complete `Production_Seed/LISTINGS.csv`, install build 8 from TestFlight, create your artist profile, and publish `Production_Seed/selected/` in Studio.

The version is set to **release automatically after approval**. Switch to manual release on the version page if CloudKit Production or the seed artworks are not ready.

## 2. What is set in App Store Connect

| Section | Value |
|---|---|
| Build | 1.0.0 (8) |
| Category | Shopping, secondary Entertainment |
| Content Rights | Contains third-party content, rights held |
| Age rating | 13+ (UGC Yes, social media Yes, messaging No, web access No, age assurance No, nudity None) |
| App Privacy | Published (table below) |
| Privacy Policy URL | `https://artistfolioapp.com/privacy.html` |
| Price | Free (USD 0.00) |
| Availability | 148 countries or regions. The 27 EU countries are excluded until EU trader status is completed |
| Description, review notes | Updated to section 3 |
| Sign-in required | Unchecked (demo mode instead) |

### App Privacy label
Data collected: **Yes**. Tracking: **No**. Every type is Linked to user **Yes**, Used for tracking **No**, Purpose **App Functionality**.

| App Store Connect type | ArtistFolio data |
|---|---|
| Contact Info: Name | Display name |
| Contact Info: Email Address | Artist contact email |
| Contact Info: Other User Contact Info | Website, Instagram handle |
| Identifiers: User ID | CloudKit user record ID |
| User Content: Photos or Videos | Artwork images, profile photo |
| User Content: Other User Content | Bio, location text, listings, report notes |

Saved art, follows and blocks are not declared because they stay in the user's private iCloud database. AR camera frames stay on device.

### Store assets
- iPhone 6.1"/6.3" (1206 x 2622): `Store_Assets/06_Screenshots_Portrait_1206x2622/`, five files.
- iPad 13" (2064 x 2752): `screenshots-ipad-13in/`, four files.
- Search Results (1920 x 1280): `Store_Assets/02_Search_Results/`.
- Header (3840 x 1646): `Store_Assets/01_Header/ArtistFolio_Header_LogoOnly_3840x1646.png`.
- No app preview videos. `_to_delete/` holds the assets that advertised chat. Do not upload them.

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

### Beta App Review reply (TestFlight, Guideline 2.1(a))

Leave **Sign-in required** unchecked in TestFlight → Test Information, and send this as the reply:

```
Thank you for the review. ArtistFolio uses the device's iCloud account, so it has no username or password to provide. Build 8 adds a demonstration mode that requires no account or iCloud sign-in.

To access it:
1. Launch the app and tap Skip.
2. Tap Explore Demo at the bottom of the screen.
3. Tap Artist Demo or Collector Demo.

Artist Demo includes Home, Search, Studio, publishing, editing listings, sharing, saved art, following, reporting, blocking, and account deletion. Collector Demo includes browsing, saved art, following, contacting artists, reporting, and blocking.

Demo mode uses sample content stored only in memory and does not write to iCloud. To leave it, open Profile and tap Exit Demo. To try AR, open an artwork on a physical device and tap View on Wall.
```

## 4. Moderation note

The app does not promise a review time or bans. Report and Block remain because App Review Guideline 1.2 requires them for user-generated content, and Apple expects timely action on reports. Check Report records in CloudKit Console regularly and remove violating content there.

## Sources

- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

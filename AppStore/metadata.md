# ArtistFolio — App Store Connect Metadata

All fields ready to paste into App Store Connect. See `SUBMISSION.md` for the current plan and age rating answers.

---

## Identity

| Field | Value |
|---|---|
| **App Name** | ArtistFolio |
| **Subtitle** | Discover & Collect Original Art |
| **Bundle ID** | com.artistfolio.app |
| **SKU** | ARTISTFOLIO-001 |
| **Primary Language** | English (U.S.) |

---

## Categories

| Field | Value |
|---|---|
| **Primary** | Shopping |
| **Secondary** | Entertainment |

---

## Description (4000 chars max — ~1300 chars)

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

---

## Promotional Text (170 chars max — shown above description, can be updated anytime)

```
Now with AR Preview — point your camera at any wall and see how a painting looks in your space before you buy.
```

---

## Keywords (100 chars max — comma-separated, no spaces after commas)

```
art,paintings,gallery,artists,collect,artwork,discover,original,buy art,wall art
```

> **Tips:**
> - Don't repeat the app name or category words (Apple ignores them)
> - Rotate keywords after launch based on Search Ads data

---

## Support & URLs

| Field | Value |
|---|---|
| **Support URL** | https://chinmaylaghate.github.io/ArtistFolio/support.html |
| **Marketing URL** | https://chinmaylaghate.github.io/ArtistFolio/ *(optional)* |
| **Privacy Policy URL** | https://chinmaylaghate.github.io/ArtistFolio/privacy.html |

> ✅ All three URLs confirmed live as of 2026-11-22.

---

## Version Information

| Field | Value |
|---|---|
| **Version** | 1.0.0 |
| **Build** | 7 |
| **What's New** | *(leave blank for 1.0 — first release has no "what's new")* |

---

## Copyright

```
© 2026 ArtistFolio
```

---

## Age Rating

Fill out the **Age Rating** questionnaire in App Store Connect with these answers:

| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Simulated Gambling | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use | None |
| **Contests** | No |
| **User-Generated Content** | **Yes** *(artists publish artwork)* |
| **Unrestricted Web Access** | No |

**Expected Rating: 4+** (UGC triggers an advisory, but content is artwork only)

---

## App Review Information

### Sign-In Required?
No — reviewers can browse as a guest without an iCloud account.

### Notes for App Review

```
ArtistFolio is an art discovery and portfolio app. Guests can browse artwork without signing in.

ACCOUNTS: The app uses CloudKit, so no demo credentials are required. To test profiles, saving, following, reporting, blocking, publishing, and account deletion, sign in to iCloud on the device and create a profile in the app.

PAYMENTS: The app sells no digital goods and processes no payments. Listings are physical artworks. Buyers contact artists directly and arrange payment and delivery outside the app.

USER-GENERATED CONTENT: Users must accept the community terms before creating a profile. Text is filtered for objectionable terms. Report and Block are in the "..." menu on every artwork and artist profile. We review submitted reports and remove content that violates the terms.

ACCOUNT DELETION: Profile tab > Delete Account.

AR: Open an artwork and tap View on Wall. This requires a physical device with ARKit world tracking.
```

### Demo Account
Not required — guest browsing is fully functional.

---

## App Store Screenshots

See `AppStore/screenshots-spec.md` for required sizes, content, and production notes.

Required sets:
- **6.7" iPhone** (iPhone 16 Plus / 15 Plus) — 1290 × 2796 px — **REQUIRED**
- **5.5" iPhone** (iPhone 8 Plus) — 1242 × 2208 px — required only if supporting iOS below 11 *(skip — min iOS 17)*

Optional but strongly recommended:
- **6.9" iPhone** (iPhone 16 Pro Max) — 1320 × 2868 px
- **13" iPad** — 2064 × 2752 px — **REQUIRED** (see `AppStore/screenshots-ipad-13in/`)

Minimum: **3 screenshots**. Recommended: **6–8**.

---

## In-App Purchases

None — declare "No" in App Store Connect.

---

## Pre-Submission Checklist

- [ ] Archive built in Xcode with **Release** scheme, **Any iOS Device** destination
- [ ] Upload via **Xcode Organizer → Distribute → App Store Connect**
- [ ] Screenshots uploaded (see spec)
- [ ] Privacy Policy URL live and accessible
- [ ] Support URL live (even a mailto: works)
- [ ] CloudKit container `iCloud.com.artistfolio.app` created in [developer.apple.com](https://developer.apple.com) → Certificates → iCloud Containers
- [ ] CloudKit schema deployed to Production (not just Development) via CloudKit Console
- [ ] All metadata fields filled in App Store Connect
- [ ] Age Rating questionnaire completed
- [ ] App Review notes added
- [ ] Content rights confirmed (you own all artwork used in screenshots)

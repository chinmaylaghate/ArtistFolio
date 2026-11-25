# ArtistFolio 1.1.0: Release Checklist

Build: **1.1.0 (9)**. Branch: `social-sharing`. 1.0.0 (8) is live. Scope and design notes are in `UPDATE_PLAN.md`.

## 1. Before you archive

1. **Deploy the CloudKit schema to Production.** In [CloudKit Console](https://icloud.developer.apple.com/dashboard/) → container `iCloud.com.artistfolio.app`, the Development schema must already have these fields. Saving one artwork and one profile from a Debug build creates them. Then use **Deploy Schema Changes** to push them to Production. Do this **before** 1.1 goes live, or 1.1 cannot save them.

   | Record type | New field | Type | Index |
   |---|---|---|---|
   | Artwork | `priceOnRequest` | INT64 | none |
   | Artwork | `careNote` | STRING | none |
   | Artwork | `showCareTips` | INT64 | none |
   | Artwork | `series` | STRING | Queryable |
   | Artwork | `sizeClass` | STRING | Queryable |
   | Profile | `phone` | STRING | none |
   | Profile | `whatsapp` | STRING | none |

   `CloudKit/schema.ckdb` holds the full schema. CloudKit can add fields but never remove them, so check the names before deploying.

2. **Update the live website.** artistfolioapp.com is served from the separate `artistfolio-site` repo (GitHub Pages, `main` branch, root folder), not from this repo's `docs/`. Copy the 1.1 additions into its `privacy.html` (the phone and WhatsApp line) and `support.html` (the "Caring for Your Artwork" section), then push. App Review may open both. This repo's `docs/` folder is only a reference copy and has drifted (older colours and header).

3. **Test on a real iPhone with your iCloud account** (the simulator has no Mail or WhatsApp):
   - Make an Offer and Ask for Price open Mail and WhatsApp with the message filled in.
   - Call and Text open the phone app.
   - Publish a piece with Price on request, a series, a care note, and the standard tips turned off. Then edit it and check every field kept its value.
   - Open Studio once, then use Search → Filters → Size. Older listings should appear in the right size.
   - Check Home's "Under $500" and "Under $1,000" collections leave out price-on-request pieces.
   - Run through Artist Demo and Collector Demo once.

## 2. App Store Connect changes

### App Privacy label (update before submitting)
Add one data type. Artists can now publish phone and WhatsApp numbers.

| App Store Connect type | ArtistFolio data | Linked | Tracking | Purpose |
|---|---|---|---|---|
| Contact Info: Phone Number | Artist phone and WhatsApp numbers (optional) | Yes | No | App Functionality |

The age rating does not change. Messaging stays **No**, because offers open the user's own Mail or WhatsApp and the app sends nothing itself.

### What's New in This Version

```
Selling tools for artists, and easier ways for collectors to buy.

• Make an Offer: send the artist an offer by email or WhatsApp, right from the artwork.
• Price on request: artists can hide a price and let buyers ask.
• Call, text or WhatsApp: artists can add a phone or WhatsApp number to their profile.
• Artwork care: every listing shows how to look after the piece, with the artist's own advice first and a full care guide.
• Series: see more from the same series, and filter an artist's work by series.
• Size filter: find work that fits your wall, small, medium or large.
• Artist pages now show a summary of their work, commissions, and the mediums they use.
• A cleaner artwork page with the key details at a glance.
```

### Description: replace these lines

In **FOR COLLECTORS**, replace the contact bullet with:
```
• Make an offer or ask for the price by email or WhatsApp
• Call, text or message artists directly
• Filter by style, medium, price and size
• Care advice for every piece
```

In **FOR ARTISTS**, add:
```
• Hide your price with Price on request
• Group work into series
• Add your own care notes
```

### Notes for App Review: add this paragraph

```
NEW IN 1.1: In Collector Demo, open "Flowers on a Ledge" and tap Make an Offer, or open "Heavenly Assembly" (Price on request) and tap Ask for Price. Both open the device's Mail or WhatsApp with a pre-filled message; the app sends nothing itself. "Amber Reflections" shows the series, care note and More from this series. Sofia Martinez's profile shows the summary card, commissions card and Call, Text and WhatsApp options. Demo contact details are examples and reach no one.
```

### Optional: subtitle and keywords (your call)
The research doc suggests leading with AR, to stand apart from the other "ArtistFolio":
- Subtitle today: `Discover and Collect Original Art`. Option: `See Art on Your Wall in AR` (26 of 30 characters).
- Keywords to consider adding: `AR, wall preview, art offer, price on request, art care`.

Changing the subtitle affects search ranking. Leave it if 1.0 search traffic looks good.

## 3. Screenshots
Raw 1.1 simulator captures are in `screenshots-1.1/raw/` (iPhone 17 Pro, 1206 x 2622). They need the same Figma frame treatment as the 1.0 set before upload. The best one to add is the artwork page with **Make an Offer**.

## 4. Submit
1. Archive 1.1.0 (9) in Xcode and upload it.
2. Add the build to version 1.1.0, then update What's New, the description, review notes and the privacy label.
3. Submit for review. Consider **manual release**, so you can confirm the CloudKit Production deploy before users get the update.

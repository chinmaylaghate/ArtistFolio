# ArtistFolio 1.2.0: Release Checklist

Build: **1.2.0 (10)**. Branch: `universal-links-qr`, which also contains all of 1.1 (`social-sharing`, PR #2). Scope is in `UPDATE_PLAN.md`.

**Order of releases.** 1.1 (build 9) is not submitted yet. Either:
- **Ship 1.1 first** (merge PR #2, follow `RELEASE_1.1.md`), then 1.2 as a follow-up. Smaller review, smaller risk. Recommended.
- **Skip straight to 1.2.** Then do every 1.1 step below as well, because 1.2 includes all 1.1 changes.

## 1. Before you archive

1. **Deploy the CloudKit schema to Production.** In [CloudKit Console](https://icloud.developer.apple.com/dashboard/) → `iCloud.com.artistfolio.app`, create these in Development (running a Debug build and using each feature creates them), check the indexes, then **Deploy Schema Changes**. Do this **before** release. Without it, reviews, counts and account deletion cleanup silently do nothing.

   | Record type | Field | Type | Index |
   |---|---|---|---|
   | Review (new) | `artistID` | STRING | Queryable |
   | Review | `rating`, `text`, `relationship` | INT64, STRING, STRING | none |
   | Review | `___createTime` / `___createdBy` | system | Sortable / Queryable |
   | ArtworkLike (new) | `targetID` | STRING | Queryable |
   | ArtistFollow (new) | `targetID` | STRING | Queryable |
   | ArtworkView (new) | `targetID` | STRING | Queryable |
   | ArtworkLike, ArtistFollow, ArtworkView | `___createdBy` | system | Queryable |
   | Artwork | `viewCount`, `likeCount` | INT64 | none |
   | Profile | `followerCount` | INT64 | none |

   Security roles for the four new types: **World** read, **Authenticated** create, **Creator** write. If 1.1 hasn't shipped, deploy its fields too (`RELEASE_1.1.md`). `CloudKit/schema.ckdb` has the full schema.

2. **Update the privacy policy** on artistfolioapp.com (`artistfolio-site` repo, `privacy.html`, "What We Collect" list). Add:
   ```html
   <li><strong>Reviews you write</strong> — your rating, how you know the artist, your text and your name, displayed publicly on the artist's profile</li>
   <li><strong>Saves, follows and artwork views</strong> — recorded against your app-specific iCloud identifier so artists see total counts. The app shows only totals, never who saved, followed or viewed</li>
   ```
   The universal link files are already live (artistfolio-site `aa600fd`).

3. **Test on a real iPhone with your iCloud account:**
   - **Links:** tap an `artistfolioapp.com/a/<id>` link in Notes or Messages. It should open the app on that artwork. Then try an `/artist/<id>` link.
   - **QR label:** print or share a label, scan it with the Camera app, and check it opens the artwork.
   - **Reviews:** using a second iCloud account, write, edit and delete a review. Then report one, and block the reviewer to check their review disappears.
   - **Counts:** with the second account, save and view a piece and follow the artist. Then open Studio on the artist account: after the hourly refresh, the counts should appear. To force an early refresh, delete and reinstall the app.
   - **Account deletion:** delete the second account. Its reviews and public activity should disappear.

## 2. App Store Connect changes

### App Privacy
- **Add:** Usage Data → **Product Interaction**. Linked to user: Yes, Tracking: No, Purpose: App Functionality. This covers saves, follows and views counted for artists.
- **Update:** the "User Content: Other User Content" description to include reviews.
- The age rating does not change. User-generated content is already declared, and reviews have Report and Block.

### What's New in This Version
```
• Share links that open in the app: send an artwork or artist and it opens right in ArtistFolio, or on the App Store for friends who don't have it yet.
• QR wall labels: print a label for any piece. At fairs and open studios, visitors scan it to see the work, try it on their wall in AR, and contact you.
• Reviews: rate artists you've bought from or met, and read what other collectors say.
• See how your work is doing: views, saves and followers, right in Studio.
```

### Description: add
In **FOR COLLECTORS**:
```
• Read and write reviews of artists
```
In **FOR ARTISTS**:
```
• Print QR labels for exhibitions and fairs
• See views, saves and followers for your work
```

### Notes for App Review: add
```
NEW IN 1.2: In Collector Demo, open Elena Rossi's profile. She has 2 reviews, so no average shows; tap Write a Review and post one to see the rating appear. Each review's "..." menu has Report Review. In Artist Demo, open "Amber Reflections" and tap the QR button for a printable label; the artwork page and Studio show views and saves. Shared artwork links (https://artistfolioapp.com/a/...) open in the app via universal links.
```

## 3. Screenshots
Raw simulator captures (iPhone 17 Pro, 1206 x 2622) are in `screenshots-1.2/raw/`:
- `01_reviews.png`: an artist page with rating, followers and reviews
- `02_qr-label.png`: the QR label sheet
- `03_artwork-stats.png`: an artwork with views and saves

They need the same Figma framing as the earlier sets.

## 4. Submit
1. Archive 1.2.0 (10) and upload it. Automatic signing adds the Associated Domains capability to the App ID.
2. Update App Privacy, What's New, the description and review notes.
3. Submit with **manual release**, and release only after confirming the CloudKit Production deploy.

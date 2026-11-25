# Website files for 1.2 universal links

artistfolioapp.com is served by GitHub Pages from the separate **`chinmaylaghate/artistfolio-site`** repo (`main` branch, root folder). This folder only stages the files that repo needs. Nothing here goes live until it is copied there and pushed.

## Copy into `artistfolio-site` (repo root)

| File here | Path in `artistfolio-site` | Why |
|---|---|---|
| `.well-known/apple-app-site-association` | `.well-known/apple-app-site-association` | Tells iOS the app may open `/a/*` and `/artist/*` links. No file extension. |
| `.nojekyll` | `.nojekyll` | The site uses the legacy Jekyll build, which skips folders starting with `.`. Without this file, `.well-known` is not published. |
| `404.html` | `404.html` | GitHub Pages serves it for any unknown path. Shared links like `/a/<id>` land here when the app isn't installed, and the page points to the App Store. |

The site has no `404.html` today, so nothing is overwritten.

## Check after pushing

1. `curl -I https://artistfolioapp.com/.well-known/apple-app-site-association` should return `200`. GitHub Pages serves it as `application/octet-stream`. Apple's CDN accepts that, but if links don't open the app, this is the first thing to check.
2. Apple caches the file through its CDN. To see what Apple has, open `https://app-site-association.cdn-apple.com/a/v1/artistfolioapp.com`. It can take up to a day to refresh.
3. Open `https://artistfolioapp.com/a/test` in Safari on a Mac. It should show the "View this artwork" page.
4. On an iPhone with a 1.2 build installed, tap an artwork link in Notes or Messages. It should open the app on that artwork, not Safari.

## App side (already in this repo)

- Entitlement `applinks:artistfolioapp.com` in `ArtistFolio/ArtistFolio.entitlements`. Xcode's automatic signing adds the Associated Domains capability to the App ID on the next archive.
- `AppLink` parses and builds the links. `RootView.onOpenURL` opens them over the current tab.
- The team ID in the association file is `346UJ76346`, the same `DEVELOPMENT_TEAM` the project signs with.

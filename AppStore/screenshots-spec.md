# ArtistFolio — Screenshot Specification

## Required Sizes

| Device | Resolution | Required? |
|---|---|---|
| iPhone 6.7" (iPhone 16 Plus / 15 Plus) | 1290 × 2796 px | ✅ Required |
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868 px | Recommended |
| iPad Pro 12.9" (M4) | 2064 × 2752 px | Only if iPad layout differs |

> Apple requires at least the **6.7"** set. If you only shoot one size, shoot 6.7".
> Minimum 3, maximum 10 per device.

---

## Screenshot Plan (6 screens, recommended order)

### 1 — Hero / Discovery (collectors first impression)
**Screen**: Home feed, scrolled slightly to show the artwork grid  
**Overlay text**: "Discover original art from independent artists"  
**Notes**: Show 6–8 diverse artwork thumbnails. Warm, inviting.

### 2 — AR Preview
**Screen**: ARPaintingView with a painting placed on a real wall  
**Overlay text**: "See it in your space before you buy"  
**Notes**: This is a strong differentiator. Shoot in a nicely lit room.

### 3 — Artwork Detail
**Screen**: ArtworkDetailView for a compelling painting  
**Overlay text**: "Every detail — price, dimensions, artist contact"  
**Notes**: Show title, price, medium, dimensions panel, AR button.

### 4 — Artist Profile
**Screen**: ProfileView of a fictional artist with 3–4 artworks shown  
**Overlay text**: "Follow artists you love"  
**Notes**: Shows the follow button, artwork grid, artist bio.

### 5 — Studio (for artists)
**Screen**: StudioView with 3–4 published artworks  
**Overlay text**: "Artists: publish your work in minutes"  
**Notes**: Demonstrates the artist value prop.

### 6 — Search / Browse
**Screen**: SearchView with results, or Home with filter selected  
**Overlay text**: "Filter by medium, style, and price"  
**Notes**: Shows discoverability.

---

## Production Notes

### Shooting
- Use **iPhone 16 Plus** (or any 6.7" device) in **Portrait** orientation
- Use **Simulator** for clean, repeatable screenshots:
  - Xcode → Open Simulator → target device: iPhone 16 Plus
  - `xcrun simctl io booted screenshot screenshot.png`
- Disable status bar clock/carrier clutter: in Simulator, **Status Bar → Set Status Bar** to 9:41 AM, full signal/battery

### Framing Options
1. **Device frame**: wrap in a device mockup using tools like [Rottenwood](https://rottenwood.app) or Sketch/Figma with Apple's device frames
2. **No frame**: flat screenshot with a colored background strip and overlay text
3. **Canva / Figma template**: compose the overlay text and background separately

### Text Overlays
Keep headline text ≤ 4 words, large (60–80pt equivalent), top or bottom of frame.  
Use app's brand blue `#3F73D3` for accent text. Background: white or dark (`#0F0F12`).

### Localization
For 1.0, English only is fine. Add localized screenshot sets if you expand to other markets.

---

## App Preview Video (Optional)

A 15–30 second video dramatically improves conversion.  
Recommended flow: Home feed → tap artwork → AR preview places on wall → back to feed → Studio upload  
Export at 1080 × 1920 (or 886 × 1920 for older format), H.264, ≤ 500 MB.

---

## Quick Screenshot Checklist

- [ ] Home feed — artwork grid visible
- [ ] AR preview — painting on wall
- [ ] Artwork detail — price + dimensions + AR button
- [ ] Artist profile — grid + follow
- [ ] Studio — artist's listings
- [ ] Search or filter view
- [ ] All shots at 1290 × 2796 (or cropped to it)
- [ ] No personal data, real email addresses, or placeholder content visible
- [ ] Status bar shows 9:41 AM, full signal, full battery

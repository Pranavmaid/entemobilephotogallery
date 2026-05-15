# Ente Mobile Photo Gallery

This is the photo gallery I built for Ente's mobile take-home.

There were two parts to it. First, a grid of the device's photos where pinching changes how many columns you see - anywhere between 2 and 7. Second, swap that grid for a masonry layout so portraits stay tall and panoramas stay wide instead of everything being squared off.

Both are in. Photos load from the device, get grouped into Today / Yesterday / This Week / earlier months, and you can pinch to resize, flip between grid and masonry, long-press to multi-select, or tap any photo to open a full-screen viewer.

Most of my time on this didn't go into the happy path — that was straightforward. It went into the corner cases: scroll jumping back to the start on fast fling, headers piling up when you scrolled past short days, images flashing black during a pinch, anchor preservation crashing with a duplicate-GlobalKey, and so on. The "Things that went wrong, and what fixed them" section below is the honest log of that.

## Run it

```bash
flutter pub get
flutter run
```

Release APK:

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

The first time the app launches it asks for photo library permission. Deny it and you'll see a screen with an "Open Settings" button.

## Testing without device photos

The repo ships with a synthetic photo source backed by `picsum.photos`. Flip one constant at the top of `lib/pages/gallery_page.dart`:

```dart
const bool kUseFakePhotos = true;
```

300 fake photos with mixed aspect ratios get generated against a fixed seed. Useful on emulators with empty galleries.

## What works

- Pinch in/out on either grid or masonry to step columns between 2 and 7 (8 on tablets, 9 on wide screens). Haptic per step.
- Photos stay roughly anchored across a column change instead of snapping to the top.
- Grid ↔ masonry toggle in the top bar. Masonry uses each photo's real aspect ratio.
- Date sections: Today, Yesterday, This Week, "Earlier in <month>", then `YYYY-MM` for older buckets.
- Long-press a tile to enter multi-select. Cancel / Select-All in the top bar.
- Single sticky header at the top of the scroll showing the day you're currently in. Day swaps to next once you scroll past its photos. Animates in/out — only shows once the inline header for the section has scrolled off, so the label never appears twice.
- Horizontal "passed days" bar fills as you scroll past each section. Tap a chip to jump back. Section leaves the bar once you scroll back into it.
- Photo viewer: swipe between, double-tap zoom, filmstrip with the current photo highlighted, tap-toggle chrome. Top-right info button opens a sheet with date / time / dimensions.
- Real actions in the viewer:
  - **Share** uses `share_plus` — for a device photo it shares the actual JPEG file via the native share sheet, for a fake (picsum) photo it shares the URL.
  - **Delete** calls `PhotoManager.editor.deleteWithIds`. Confirmation dialog first, then the system delete prompt. On success the photo is removed from the in-viewer list and the gallery reloads.
  - **AI Edit** sends the photo + a text prompt to Google's Gemini 2.5 Flash Image ("nano banana"), gets an edited image back, previews it full-screen, and offers a Save button that writes it to the gallery as a new asset.
- Dark Material 3 theme. Mint accent for active states. Sizes scale from `MediaQuery.shortestSide` so it looks right from small phones up to tablets.
- Empty / denied / limited-permission paths all show a guidance screen rather than a blank scaffold.

## AI Edit (Gemini "nano banana")

To use the AI Edit button you need a Gemini API key. Don't commit it.

```bash
flutter run --dart-define=GEMINI_API_KEY=<your-key>
```

For a release APK:

```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=<your-key>
```

Without the key the button shows a snackbar with the run command. With the key, tapping AI Edit opens a prompt sheet ("make it sunset", "remove the person in the back", "add snow"), sends the current photo to `gemini-2.5-flash-image`, and shows a full-screen preview of the result. Tap Save to write it back to the device gallery as a new asset.

Source images are downscaled to 1024 px on the long edge before being sent, so a single edit stays well inside the per-call token budget. Errors are surfaced in a scrollable dialog with the full Gemini response body and a Copy-to-clipboard button — useful for the 429s you'll hit on the free tier.

## Tests

```bash
flutter test
```

Unit + widget coverage on the parts that are easy to verify in isolation: bucketize logic, `safeRatio`, `ThumbResolver`, `GalleryController`, `PhotoTile` (renders skeleton, shows selection badge), `TopBar` (mode + cancel callbacks), and an app-boot smoke test. 20 tests total.

## Architecture, in one breath

Flat, layer-first. Nothing fancy.

```
lib/
  main.dart                       entry, theme, ImageCache config
  models/{photo, photo_section, aspect}.dart
  services/{thumb_resolver, photo_service}.dart
  controllers/gallery_controller.dart
  widgets/{photo_tile, photo_grid, photo_masonry,
           pinch_gesture_layer, pinch_overlay,
           top_bar, selection_bar, metrics}.dart
  pages/{gallery_page, photo_viewer_page}.dart
```

- `Photo` is an abstract model. `DevicePhoto` wraps a `photo_manager` `AssetEntity`. `FakePhoto` returns a picsum `NetworkImage`. The rest of the app only knows about `Photo`.
- `GalleryController` extends `ChangeNotifier` and owns transient UI state: cols, mode, max cols, selection, pinch active, anchor.
- `PinchGestureLayer` uses `RawGestureDetector` with a `ScaleGestureRecognizer` so single-finger drag belongs to the scrollable and two-finger pinch belongs to the column changer.
- Masonry uses `waterfall_flow` (not `flutter_staggered_grid_view` — see below).

No Riverpod, no Bloc. The screen has one controller, the rest is straight `setState`. For a single-screen app it's the smallest thing that works.

## Things that went wrong, and what fixed them

Building this was less "write the spec" and more "debug Flutter's sliver internals." Honest log:

**Pinch fighting scroll.**
First pass used `GestureDetector.onScale*`. The scale recognizer claims the arena on the first pointer down, which steals single-finger drag from the `Scrollable`. Result: you couldn't scroll the gallery, every drag was interpreted as the start of a pinch. Switched to `RawGestureDetector` registering only `ScaleGestureRecognizer`. The arena now correctly routes single-finger drag to the scroller and only switches to scale when a second pointer lands.

**Anchor preservation crashed the app.**
Original plan: every tile registers a `GlobalKey` in a registry so the page can find the topmost visible photo before a column change and re-scroll to it afterward. With ~3000 tiles cycling in and out fast, two tiles for the same photo id occasionally exist in the tree for one frame, both holding the same `GlobalKey` from the registry → "Duplicate GlobalKey detected" crash mid-scroll. Replaced with a fraction-of-maxScroll anchor. Less precise but won't crash. Deleted the registry file entirely.

**Masonry scroll snapping back to the top.**
After scrolling a few hundred pixels into the masonry view the scroll position would suddenly jump to the start. Tried tightening `cacheExtent`, removing `findChildIndexCallback`, toggling `addAutomaticKeepAlives` — none of it stuck. The actual cause was `flutter_staggered_grid_view`'s `SliverMasonryGrid` mis-estimating its total extent when children recycle, especially below a `SliverPersistentHeader`. Swapped to `waterfall_flow`'s `SliverWaterfallFlow`, which caches per-child layout offsets and keeps total extent stable. Bug stopped.

**Pinch zoom going black, slow reload.**
Pinching from 3 cols to 5 cols would flash every visible tile to black for a second. Cause: `thumbPx` was a function of `tileW`. Change cols → `tileW` changes → bucket changes → every `ImageProvider` key changes → `ImageCache` miss → reload all from device decode. Fix: decode at a column-count-independent reference size (`innerW / 4`). The provider key stays identical across pinch, the cache hits, tiles just rescale the already-decoded bitmap. No flash.

**Headers piling on top of each other.**
Original layout used `SliverPersistentHeader(pinned: true)` for each date section. When a few small sections (3 photos, 6 photos) sat back-to-back, multiple headers ended up pinned simultaneously at the top of the viewport and the photos got pushed off-screen — looked like the gallery had stopped loading. Switched to a single sticky header outside the scroll view, fed by a scroll listener that figures out which section's content the viewport currently sits inside. The "passed days" chip bar above it shows everything before that.

**Tile flicker on scroll.**
Per-tile `LayoutBuilder` plus oversized thumbnails plus no `RepaintBoundary` meant fast scroll was juddery. Pre-compute `tileW` and `thumbPx` once per build (not per tile), wrap each tile in `RepaintBoundary`, set `FilterQuality.low` on thumbnails, wrap providers in `ResizeImage` so the codec downsamples to display size, and bump `ImageCache` limits in `main.dart`. Scroll smoothed out.

**Aspect ratios from corrupt EXIF.**
A handful of photos report `width: 0` or absurd aspect ratios (panoramas mostly). Direct `width / height` blew up the masonry layout for one tile and shoved everything else around. Added a `safeRatio` helper that clamps to `[0.45, 2.4]` and falls back to 1.0 on bad input.

**Permission changes causing rebuild storms.**
`PhotoManager.addChangeCallback` fires on any media change. Without debouncing, taking a screenshot while the app is open would trigger an immediate full reload every few hundred ms. Wrapped in a 2-second debounce.

## Performance touches that ended up mattering

- `ImageCache.maximumSize = 400`, `maximumSizeBytes = 320 MB`. Sized to fit ~400px thumbnails without thrashing.
- `addAutomaticKeepAlives: false` on the masonry delegate so off-screen tiles dispose cleanly.
- `gaplessPlayback: true` on `Image` so the previous frame stays painted while a new one decodes.
- `_Skeleton` widget under every tile so loading shows a dark gradient instead of pure black.
- Quantized thumb buckets `[96, 144, 200, 280, 400, 560]` so small constraint shifts don't swap image providers.
- Brief opacity-and-scale tween on the scroll subtree when columns change, so the relayout reads as a deliberate transition instead of a snap.

## Manual QA checklist

- Pinch in and out across grid and masonry, both directions.
- Scroll deep into the gallery; check the day at the top of the screen matches what you're seeing.
- Tap a chip in the passed-days bar — it should smooth-scroll back to that day.
- Long-press a tile → enter multi-select → tap a few more → Cancel. Scroll position shouldn't reset.
- Tap a tile → viewer opens with a fade/scale. Swipe between. Tap to toggle chrome. Back.
- Background the app and reopen → state survives.
- Revoke photo permission in system settings → app shows the guidance screen with "Open Settings".

## What's intentionally not here

- No albums, search, video playback, or cloud sync. Out of scope.
- No iOS-specific visual treatment beyond the status-bar inset.
- Multi-select share/delete is wired only for a single open photo at a time; bulk actions from the grid's selection bar are still UI only.

## Notes

- Tested on a Pixel-class Android device and an Android 14 emulator.
- Requires `flutter` 3.8+ / Dart 3.

# Gallery Redesign — Design Spec

Date: 2026-05-15
Project: Ente Mobile Photo Gallery (Flutter assignment)
Scope: Assignment-only, polished.

## Goal

Rebuild the gallery app so Part 1 (pinch-zoom grid 2-7 columns) and Part 2 (masonry layout with original aspect ratios) work reliably, with no scroll/pinch/anchor/flash bugs. App should feel like Google Photos but smoother for the assignment surface area. No albums, search, ML, sync, or sharing in this iteration.

## Non-Goals

- Albums view, search, favorites screens
- Cloud sync or backup
- Edits, filters, ML face groups
- Sharing flows
- Multi-account, settings UI

## Architecture

State management: `setState` + thin `ChangeNotifier` controller. No Riverpod/Bloc/Provider dependency.

Folder structure (flat layer-first):

```
lib/
  main.dart                     # entry, theme, image cache config
  models/
    photo.dart                  # abstract Photo: id, width, height, dateTaken, isVideo,
                                #   thumb(int px) -> ImageProvider, full() -> ImageProvider
                                # DevicePhoto (wraps AssetEntity) + FakePhoto (NetworkImage via picsum)
    photo_section.dart          # PhotoSection (key, label, sub, photos)
  services/
    photo_service.dart          # device load, permission, bucketize
    thumb_resolver.dart         # quantized thumbnail size bucket
  controllers/
    gallery_controller.dart     # ChangeNotifier: cols, mode, selection, anchor
  widgets/
    photo_tile.dart             # image + skeleton + selection badge + video badge
    photo_grid.dart             # SliverGrid wrapper
    photo_masonry.dart          # SliverMasonryGrid wrapper with key reuse
    section_header.dart         # sticky date header (SliverPersistentHeader)
    top_bar.dart                # title, mode toggle, select toggle
    pinch_overlay.dart          # column count indicator
    selection_bar.dart          # bottom share/save/delete
    pinch_gesture_layer.dart    # RawGestureDetector + ScaleGestureRecognizer
    tile_registry.dart          # inherited widget for anchor lookup
  pages/
    gallery_page.dart           # composes top_bar + scroll + slivers
    photo_viewer_page.dart      # full-screen swipe viewer
test/
  photo_service_test.dart
  safe_ratio_test.dart
  thumb_resolver_test.dart
  photo_tile_test.dart
  top_bar_test.dart
```

### Unit boundaries

- `PhotoService` knows photo_manager. Returns `List<Photo>` and `List<PhotoSection>`. No Flutter widget code.
- `ThumbResolver` is pure: pixel size → quantized bucket.
- `GalleryController` owns transient UI state. No I/O.
- `PhotoTile` renders one photo. Receives `Photo`, dimensions, `thumbPx`, callbacks. No layout math.
- `PhotoGrid` / `PhotoMasonry` build the sliver. Receive `PhotoSection`, `cols`, `tileW`, `thumbPx`, callbacks. No data fetching.
- `GalleryPage` composes. Reads `GalleryController`, services. No drawing primitives.

## Data Flow

### Boot

```
main → runApp → GalleryPage.initState
  → PhotoService.requestPermission
  → if granted: PhotoService.loadAll → List<Photo>
  → PhotoService.bucketize → List<PhotoSection>
  → controller.setSections / setState
PhotoService listens for PhotoManager change → debounced 2s reload
```

### Per-frame render

```
GalleryPage.build
  → Metrics.of(context)             # screen-relative sizes
  → controller.cols, controller.mode
  → compute tileW, thumbPx once per build
  → CustomScrollView
      for each section:
        SliverPersistentHeader (section_header)
        SliverGrid | SliverMasonryGrid (long form with findChildIndexCallback)
      SliverToBoxAdapter (bottom spacer)
  → tiles get ValueKey(photo.id), explicit w/h, thumbPx
```

### State transitions

- Pinch begins → `controller.startPinch()` snapshots `startCols`, `anchor`.
- Each scale update → `controller.setCols(next)` (clamped 2-maxCols).
- Pinch ends → `controller.endPinch()`.
- Mode toggle → `controller.setMode(GalleryMode)`.
- Long-press tile → `controller.enterSelect(photo.id)`.
- Tap tile (select mode) → `controller.toggleSelect(photo.id)`.
- Tap tile (normal) → push `PhotoViewerPage`.

## Bug → Fix Mapping

| Bug | Root cause | Fix |
|---|---|---|
| Masonry scroll jank / re-render | `SliverMasonryGrid.count` lacks key reuse; per-tile `LayoutBuilder`; oversized thumbnail decode | Use long-form `SliverMasonryGrid` + `SliverChildBuilderDelegate` with `findChildIndexCallback` returning index for `ValueKey(photo.id)`. Remove per-tile `LayoutBuilder`. Use quantized `thumbPx` from `ThumbResolver`. Wrap provider in `ResizeImage(width: thumbPx, height: thumbPx, policy: ResizeImagePolicy.fit)`. Wrap tile in `RepaintBoundary`. `addAutomaticKeepAlives: false`. |
| Pinch unreliable | `GestureDetector.onScale` competes with vertical drag and grabs single-finger drag from scroll; `Listener` doesn't enter arena | `RawGestureDetector` registering only `ScaleGestureRecognizer`. Single-finger drag → scroll wins arena. Two-finger movement → scale wins. On first 2-pointer update, snapshot `d.scale` as `scaleBase`. Per update: `rel = d.scale / scaleBase`; `cols = (startCols / rel).round()`. |
| Anchor drift | Fraction-of-maxScroll fails when content height changes non-linearly across col counts (masonry) | Photo-id anchor. Before cols change: identify topmost-visible tile via `TileRegistry`; store `(photoId, viewportRelativeOffset)`. After rebuild post-frame: find new offset of same tile; jump `sc.offset + delta`. Fallback to fraction if tile no longer rendered. |
| Black flash / no placeholder | `AssetEntityImage` paints black until decode | `Image` widget with `frameBuilder`: while `frame == null` show `_Skeleton` (dark gradient). When loaded, return child (fade implicit via `gaplessPlayback: true`). `errorBuilder` → `_Skeleton(error: true)` with broken-image icon. |

## Pinch Gesture (pinch_gesture_layer.dart)

```dart
RawGestureDetector(
  behavior: HitTestBehavior.deferToChild,
  gestures: {
    ScaleGestureRecognizer: factory((r) {
      r.onStart  = _start;
      r.onUpdate = _update;
      r.onEnd    = _end;
    }),
  },
  child: child,
)

bool twoFinger = false;
double scaleBase = 1.0;

_start(ScaleStartDetails d) {
  twoFinger = false;
  scaleBase = 1.0;
}

_update(ScaleUpdateDetails d) {
  if (d.pointerCount < 2) {
    if (twoFinger) { twoFinger = false; ctrl.endPinch(); }
    return;
  }
  if (!twoFinger) {
    twoFinger = true;
    scaleBase = d.scale == 0 ? 1.0 : d.scale;
    ctrl.startPinch();
    return;
  }
  final rel = d.scale / scaleBase;
  if (rel <= 0) return;
  final next = (ctrl.startCols / rel).round();
  ctrl.setCols(next.clamp(2, ctrl.maxCols));
}

_end(ScaleEndDetails d) {
  twoFinger = false;
  ctrl.endPinch();
}
```

## Anchor Preservation

### TileRegistry

`TileRegistry` is an `InheritedWidget` exposing a mutable map `Map<String, _TileHandle>`. Each `PhotoTile` calls `TileRegistry.of(context).register(photoId, this)` in `initState` and `.unregister` in `dispose`. Handle exposes `RenderBox? findRenderBox()` via `GlobalKey` or `findRenderObject`.

### Capture

```dart
captureAnchor(GalleryController c, ScrollController sc, BuildContext ctx) {
  final viewport = (ctx.findRenderObject() as RenderBox).localToGlobal(Offset.zero);
  final viewportTop = viewport.dy;
  final registry = TileRegistry.of(ctx);
  String? bestId;
  double bestDy = double.infinity;
  for (final entry in registry.entries) {
    final box = entry.value.findRenderBox();
    if (box == null) continue;
    final dy = box.localToGlobal(Offset.zero).dy;
    if (dy + box.size.height < viewportTop) continue;  // off-screen above
    if (dy < bestDy) { bestDy = dy; bestId = entry.key; }
  }
  if (bestId == null) { c.clearAnchor(); return; }
  c.setAnchor(AnchorState(photoId: bestId, offset: bestDy - viewportTop));
}
```

### Restore

```dart
restoreAnchor(GalleryController c, ScrollController sc, BuildContext ctx) {
  final a = c.anchor;
  if (a == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final registry = TileRegistry.of(ctx);
    final box = registry[a.photoId]?.findRenderBox();
    if (box == null) {
      // tile not yet rendered — leave scroll as-is (acceptable)
      c.clearAnchor();
      return;
    }
    final viewportTop = (ctx.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
    final currentDy = box.localToGlobal(Offset.zero).dy;
    final delta = currentDy - viewportTop - a.offset;
    sc.jumpTo((sc.offset + delta).clamp(0.0, sc.position.maxScrollExtent));
    c.clearAnchor();
  });
}
```

## Photo Viewer

- Route: `Navigator.push(MaterialPageRoute(builder: (_) => PhotoViewerPage(photos, initialIndex)))`.
- `PhotoViewGallery.builder` from `photo_view` package handles swipe + pinch-zoom per photo.
- `Hero(tag: 'photo_${photo.id}')` on grid `PhotoTile` and viewer image → opening animation.
- Top chrome: back button, date/time text, more menu. Tap photo toggles chrome opacity.
- Bottom chrome: filmstrip (horizontal `ListView` of 80×80 thumbs, current page centered via `ScrollController.animateTo`) + action row (share/save/favorite/delete — actions stubbed, no real wiring this iteration).
- Full-res provider: `photo.full()` (returns `AssetEntityImageProvider(asset, isOriginal: true)` for `DevicePhoto`, `NetworkImage(picsum/1200)` for `FakePhoto`).
- Single tap → toggle chrome. Double tap → photo_view's built-in zoom toggle.

## Error / Permission / Empty States

- Permission `denied` or `permanentlyDenied` → `_PermissionView`: icon + message + "Open Settings" + "Retry". Retry re-requests permission.
- Permission `limited` (iOS partial / Android user-selected media) → top banner above gallery: "Limited access — pick more photos" with action to call `PhotoManager.presentLimited()`.
- Empty list (granted but no photos) → `_EmptyView`: icon + "No photos yet".
- Image decode error → `_Skeleton(error: true)` with broken-image icon, no retry button (next scroll-back retries via ImageCache).
- Photo library change notification → debounced 2s, then `_reload()` rebuilds sections. No spinner overlay during reload (sections swap atomically).

## Performance

- ImageCache: `maximumSize = 600`, `maximumSizeBytes = 256 << 20` configured in `main.dart`.
- Thumbnail buckets: `[96, 144, 200, 280, 400, 560]`. `ThumbResolver.bucket(displayPx)` picks smallest ≥ `displayPx`. `displayPx = tileWidth * devicePixelRatio`.
- `FilterQuality.low` on thumbnails (high quality wastes GPU at small sizes).
- `gaplessPlayback: true` on `Image` to preserve prior frame when provider changes for same widget.
- `addRepaintBoundaries: true` and explicit `RepaintBoundary` per tile.
- `addAutomaticKeepAlives: false` — offscreen tiles dispose, redecoded from ImageCache on scroll-back.

## Constants

```dart
const Color  kBg          = Color(0xFF0A0A0A);
const Color  kAccent      = Color(0xFF7DDCC9);
const int    kMinCols     = 2;
const int    kMaxCols     = 7;             // 8 on tablets, 9 on desktops via _maxColsForWidth
const double kBaseGap     = 3;
const double kTileRadius  = 6;
const double kHeaderExtent = 64;
```

All sized via `Metrics.of(context)` scale = `clamp(shortestSide / 390, 0.82, 1.6)`.

## Testing Strategy

Unit tests (`test/`):
- `photo_service_test.dart` — bucketize known input → expected sections (Today/Yesterday/Week/Month/older).
- `safe_ratio_test.dart` — `_safeRatio` on zero, negative, infinite, extreme, finite inputs.
- `thumb_resolver_test.dart` — bucket boundary inputs.

Widget tests (`test/`):
- `photo_tile_test.dart` — renders skeleton when image absent; renders selection badge in select mode.
- `top_bar_test.dart` — mode toggle fires callback; select toggle fires callback.

No golden tests. No integration tests. Manual QA checklist documented in README:

- Pinch 2↔7 cols in both grid + masonry. Smooth col change, haptic on each step.
- Anchor stays on visually-pinned photo across col change.
- Long-press → multi-select → tap others → Cancel.
- Tap → viewer → swipe → close. Hero animation works.
- Background → reopen → cols/mode/scroll position retained.
- Permission denied → guidance flow + Open Settings.
- Permission limited → banner + presentLimited works.

## Open Decisions Locked

- State mgmt: setState + thin ChangeNotifier. No external lib.
- Photo source: device only (real). `kUseFakePhotos` dev-only constant retained at top of `gallery_page.dart` for testing on emulators without media library. Defaults `false`.
- Folder layout: flat layer-first (`models/`, `services/`, `widgets/`, `pages/`, `controllers/`).
- No analytics, no crash reporting, no logger lib. `debugPrint` behind `kDebugLayout` flag.

## Out-of-Scope (Defer)

- Drag-to-select (Apple Photos style swipe over tiles)
- Sticky scrubber on right edge
- Cross-section keyboard nav
- Real share intent (currently stubs)
- iOS vs Android visual divergence beyond status bar inset

## Acceptance Criteria

1. Pinch in/out on both grid and masonry → smooth col change between 2 and 7. Haptic fires once per col step.
2. After any col change, the photo at the top of viewport remains visually anchored within ±tileHeight.
3. No black tile flashes during scroll; skeleton visible only before decode.
4. Scroll FPS ≥ 50 on Pixel-class device during fast fling in masonry across 300+ photos.
5. `flutter analyze` reports zero issues.
6. Long-press → multi-select → Cancel returns to normal state without losing scroll position.
7. Tap → viewer opens with hero animation; swipe between photos; back closes with reverse hero.
8. Permission denied → guidance UI with "Open Settings" action; retry path works.
9. APK builds: `flutter build apk --release`, installs, launches on Android emulator + physical device.

# Gallery Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Ente photo gallery Flutter app on a flat, layer-first architecture so Part 1 (pinch-zoom 2-7 cols) and Part 2 (masonry) work without scroll jank, pinch unreliability, anchor drift, or black flashes.

**Architecture:** `setState` + thin `ChangeNotifier`. Flat folders: `models/`, `services/`, `controllers/`, `widgets/`, `pages/`. `Photo` is an abstract model with `DevicePhoto` (photo_manager) and `FakePhoto` (picsum NetworkImage) impls. `GalleryController` owns transient UI state. `TileRegistry` enables photo-id anchor preservation. `PinchGestureLayer` uses `RawGestureDetector` + `ScaleGestureRecognizer` to play nicely in the arena.

**Tech Stack:** Flutter 3.8+, Dart 3, `photo_manager`, `photo_manager_image_provider`, `flutter_staggered_grid_view`, `photo_view`. No state-mgmt library.

---

## File Structure

```
lib/
  main.dart                       # entry, theme, image cache config
  models/
    photo.dart                    # abstract Photo + DevicePhoto + FakePhoto + safeRatio
    photo_section.dart            # PhotoSection (key, label, sub, photos)
  services/
    thumb_resolver.dart           # quantized thumbnail size bucket
    photo_service.dart            # permission, device load, fake load, bucketize
  controllers/
    gallery_controller.dart       # ChangeNotifier: mode, cols, sel, anchor, sections
  widgets/
    tile_registry.dart            # InheritedWidget mapping photoId -> RenderBox lookup
    photo_tile.dart               # image + skeleton + selection badge
    section_header.dart           # sticky date header delegate
    photo_grid.dart               # SliverGrid wrapper
    photo_masonry.dart            # SliverMasonryGrid long-form with key reuse
    pinch_gesture_layer.dart      # RawGestureDetector + ScaleGestureRecognizer
    pinch_overlay.dart            # column count indicator
    top_bar.dart                  # title, mode toggle, select toggle
    selection_bar.dart            # bottom share/save/delete
    metrics.dart                  # screen-relative size scale
  pages/
    gallery_page.dart             # composition + bootstrap
    photo_viewer_page.dart        # full-screen swipe viewer

test/
  thumb_resolver_test.dart
  safe_ratio_test.dart
  photo_service_test.dart
  gallery_controller_test.dart
  photo_tile_test.dart
  top_bar_test.dart
  widget_test.dart                # boot smoke
```

Old `lib/` files (`gallery_page.dart`, `photo_tile.dart`, `photo_viewer_page.dart`, `photo_repository.dart`, `gallery_item.dart`) are deleted in Task 0 and replaced by the structure above.

---

## Task 0: Init Git + Clean Slate

**Files:**
- Delete: `lib/gallery_page.dart`, `lib/photo_tile.dart`, `lib/photo_viewer_page.dart`, `lib/photo_repository.dart`, `lib/gallery_item.dart`

- [ ] **Step 1: Initialize git repo if missing**

Run: `cd "/Users/pranav/Documents/projects/ente test/entemobilephotogallery" && git status 2>/dev/null || git init && git add -A && git commit -m "chore: snapshot pre-redesign state"`

- [ ] **Step 2: Create branch for redesign work**

Run: `git checkout -b redesign/gallery`

- [ ] **Step 3: Delete legacy lib files**

Run:
```bash
rm lib/gallery_page.dart lib/photo_tile.dart lib/photo_viewer_page.dart lib/photo_repository.dart lib/gallery_item.dart
```

- [ ] **Step 4: Stub main.dart so analyzer compiles**

Replace `lib/main.dart` content with:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const EnteGalleryApp());

class EnteGalleryApp extends StatelessWidget {
  const EnteGalleryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Scaffold(body: Center(child: Text('redesign WIP'))));
  }
}
```

- [ ] **Step 5: Verify analyzer is clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: clear lib/ for redesign"
```

---

## Task 1: ThumbResolver

**Files:**
- Create: `lib/services/thumb_resolver.dart`
- Test: `test/thumb_resolver_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/thumb_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/services/thumb_resolver.dart';

void main() {
  group('ThumbResolver.bucket', () {
    test('picks smallest bucket >= displayPx', () {
      expect(ThumbResolver.bucket(50), 96);
      expect(ThumbResolver.bucket(96), 96);
      expect(ThumbResolver.bucket(97), 144);
      expect(ThumbResolver.bucket(199), 200);
      expect(ThumbResolver.bucket(280), 280);
      expect(ThumbResolver.bucket(281), 400);
      expect(ThumbResolver.bucket(560), 560);
    });
    test('clamps to max bucket past largest', () {
      expect(ThumbResolver.bucket(900), 560);
      expect(ThumbResolver.bucket(99999), 560);
    });
    test('non-positive input returns smallest bucket', () {
      expect(ThumbResolver.bucket(0), 96);
      expect(ThumbResolver.bucket(-5), 96);
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/thumb_resolver_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:entemobilephotogallery/services/thumb_resolver.dart'`

- [ ] **Step 3: Implement ThumbResolver**

Create `lib/services/thumb_resolver.dart`:

```dart
class ThumbResolver {
  static const List<int> buckets = [96, 144, 200, 280, 400, 560];

  static int bucket(double displayPx) {
    if (displayPx <= 0) return buckets.first;
    for (final b in buckets) {
      if (b >= displayPx) return b;
    }
    return buckets.last;
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/thumb_resolver_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/services/thumb_resolver.dart test/thumb_resolver_test.dart
git commit -m "feat: add ThumbResolver with quantized buckets"
```

---

## Task 2: safeRatio helper

**Files:**
- Create: `lib/models/aspect.dart`
- Test: `test/safe_ratio_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/safe_ratio_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/models/aspect.dart';

void main() {
  group('safeRatio', () {
    test('returns 1.0 for non-positive dims', () {
      expect(safeRatio(0, 100), 1.0);
      expect(safeRatio(100, 0), 1.0);
      expect(safeRatio(-1, 100), 1.0);
    });
    test('clamps low extremes to minAspect', () {
      expect(safeRatio(10, 1000), 0.45);
    });
    test('clamps high extremes to maxAspect', () {
      expect(safeRatio(10000, 100), 2.4);
    });
    test('returns ratio for finite normal dims', () {
      expect(safeRatio(800, 600), closeTo(1.333, 0.001));
      expect(safeRatio(900, 1200), closeTo(0.75, 0.001));
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/safe_ratio_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:entemobilephotogallery/models/aspect.dart'`

- [ ] **Step 3: Implement safeRatio**

Create `lib/models/aspect.dart`:

```dart
const double minAspect = 0.45;
const double maxAspect = 2.4;

double safeRatio(int width, int height) {
  if (width <= 0 || height <= 0) return 1.0;
  final r = width / height;
  if (!r.isFinite || r <= 0) return 1.0;
  return r.clamp(minAspect, maxAspect);
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/safe_ratio_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/models/aspect.dart test/safe_ratio_test.dart
git commit -m "feat: add safeRatio helper"
```

---

## Task 3: Photo abstract + DevicePhoto + FakePhoto

**Files:**
- Create: `lib/models/photo.dart`

(No unit test — `Photo` is an interface; impls are tested via PhotoService.)

- [ ] **Step 1: Implement Photo + impls**

Create `lib/models/photo.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

abstract class Photo {
  String get id;
  int get width;
  int get height;
  bool get isVideo;
  DateTime get dateTaken;
  ImageProvider thumb(int sidePx);
  ImageProvider full();
}

class DevicePhoto implements Photo {
  final AssetEntity asset;
  DevicePhoto(this.asset);
  @override
  String get id => asset.id;
  @override
  int get width => asset.width;
  @override
  int get height => asset.height;
  @override
  bool get isVideo => asset.type == AssetType.video;
  @override
  DateTime get dateTaken => asset.createDateTime;
  @override
  ImageProvider thumb(int sidePx) => AssetEntityImageProvider(
        asset,
        isOriginal: false,
        thumbnailSize: ThumbnailSize.square(sidePx),
      );
  @override
  ImageProvider full() => AssetEntityImageProvider(asset, isOriginal: true);
}

class FakePhoto implements Photo {
  @override
  final String id;
  @override
  final int width;
  @override
  final int height;
  @override
  final DateTime dateTaken;
  final int picsumId;
  FakePhoto({
    required this.id,
    required this.width,
    required this.height,
    required this.dateTaken,
    required this.picsumId,
  });
  @override
  bool get isVideo => false;
  double get _ratio => width / height;
  @override
  ImageProvider thumb(int sidePx) {
    final h = (sidePx / _ratio).round().clamp(1, 4000);
    return NetworkImage('https://picsum.photos/id/$picsumId/$sidePx/$h');
  }

  @override
  ImageProvider full() {
    const target = 1200;
    final h = (target / _ratio).round().clamp(1, 4000);
    return NetworkImage('https://picsum.photos/id/$picsumId/$target/$h');
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/models/photo.dart
git commit -m "feat: add Photo abstract + DevicePhoto + FakePhoto"
```

---

## Task 4: PhotoSection model

**Files:**
- Create: `lib/models/photo_section.dart`

- [ ] **Step 1: Implement PhotoSection**

Create `lib/models/photo_section.dart`:

```dart
import 'photo.dart';

class PhotoSection {
  final String key;
  final String label;
  final String sub;
  final List<Photo> photos;
  const PhotoSection({
    required this.key,
    required this.label,
    required this.sub,
    required this.photos,
  });
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/models/photo_section.dart
git commit -m "feat: add PhotoSection model"
```

---

## Task 5: PhotoService — bucketize

**Files:**
- Create: `lib/services/photo_service.dart` (bucketize + fake loader; device loader added in Task 6)
- Test: `test/photo_service_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/photo_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/models/photo.dart';
import 'package:entemobilephotogallery/services/photo_service.dart';

class _StubPhoto implements Photo {
  @override
  final String id;
  @override
  final DateTime dateTaken;
  _StubPhoto(this.id, this.dateTaken);
  @override
  int get width => 100;
  @override
  int get height => 100;
  @override
  bool get isVideo => false;
  @override
  dynamic thumb(int sidePx) => throw UnimplementedError();
  @override
  dynamic full() => throw UnimplementedError();
}

void main() {
  group('PhotoService.bucketize', () {
    test('groups today, yesterday, this week, this month, older months', () {
      final now = DateTime(2026, 5, 15, 12, 0);
      final today    = _StubPhoto('a', DateTime(2026, 5, 15, 10));
      final yest     = _StubPhoto('b', DateTime(2026, 5, 14, 10));
      final thisWeek = _StubPhoto('c', DateTime(2026, 5, 13, 10));
      final thisMonth= _StubPhoto('d', DateTime(2026, 5, 3, 10));
      final older    = _StubPhoto('e', DateTime(2026, 3, 1, 10));
      final sections = PhotoService.bucketizeAt(
        [today, yest, thisWeek, thisMonth, older],
        now,
      );
      final keys = sections.map((s) => s.key).toList();
      expect(keys, containsAll(['today', 'yesterday', 'week', 'month']));
      expect(keys.last, '2026-03');
      final today2 = sections.firstWhere((s) => s.key == 'today');
      expect(today2.photos.length, 1);
      expect(today2.photos.first.id, 'a');
    });

    test('skips empty buckets', () {
      final now = DateTime(2026, 5, 15);
      final older = _StubPhoto('e', DateTime(2026, 3, 1, 10));
      final sections = PhotoService.bucketizeAt([older], now);
      expect(sections.length, 1);
      expect(sections.first.key, '2026-03');
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/photo_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement bucketize + fake loader**

Create `lib/services/photo_service.dart`:

```dart
import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';
import '../models/photo_section.dart';

class PhotoService {
  static const List<int> _picsumIds = [
    1015, 1018, 1020, 1024, 1025, 1027, 1029, 1033, 1035, 1036,
    1037, 1038, 1039, 1040, 1041, 1043, 1045, 1047, 1048, 1050,
    1051, 1053, 1054, 1056, 1059, 1060, 1062, 1065, 1066, 1067,
    1069, 1070, 1071, 1073, 1074, 1075, 1076, 1077, 1078, 1080,
    1081, 1082, 1083, 1084, 110, 111, 112, 113, 114, 116,
    117, 118, 119, 120, 122, 123, 124, 125, 127, 128,
  ];
  static const List<double> _ratioPool = [
    1.5, 1.5, 1.5, 1.5,
    1.333, 1.333, 1.333,
    1.778, 1.778,
    1.0, 1.0,
    0.75, 0.75, 0.75,
    0.667, 0.667,
    0.5625,
  ];

  static Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  static List<Photo> loadFake({int count = 300, int seed = 42}) {
    int s = seed;
    double rand() {
      s = (s + 0x6D2B79F5) & 0xFFFFFFFF;
      var t = ((s ^ (s >>> 15)) * (s | 1)) & 0xFFFFFFFF;
      t = (t ^ (t + (((t ^ (t >>> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF;
      return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 0xFFFFFFFF;
    }
    final now = DateTime.now();
    final out = <Photo>[];
    for (var i = 0; i < count; i++) {
      final ratio = _ratioPool[(rand() * _ratioPool.length).floor()];
      const base = 800;
      final w = base;
      final h = (base / ratio).round();
      final picsumId = _picsumIds[i % _picsumIds.length];
      final r = rand();
      int dayOffset;
      final minOff = (rand() * 1440).floor();
      if (r < 0.04) {
        dayOffset = 0;
      } else if (r < 0.10) {
        dayOffset = 1;
      } else if (r < 0.20) {
        dayOffset = 2 + (rand() * 5).floor();
      } else if (r < 0.45) {
        dayOffset = 7 + (rand() * 23).floor();
      } else if (r < 0.75) {
        dayOffset = 30 + (rand() * 60).floor();
      } else {
        dayOffset = 90 + (rand() * 275).floor();
      }
      out.add(FakePhoto(
        id: 'fake_$i',
        width: w,
        height: h,
        dateTaken: now
            .subtract(Duration(days: dayOffset))
            .subtract(Duration(minutes: minOff)),
        picsumId: picsumId,
      ));
    }
    out.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
    return out;
  }

  static List<PhotoSection> bucketize(List<Photo> photos) =>
      bucketizeAt(photos, DateTime.now());

  static List<PhotoSection> bucketizeAt(List<Photo> photos, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final todayList = <Photo>[];
    final yesterdayList = <Photo>[];
    final weekList = <Photo>[];
    final monthList = <Photo>[];
    final byMonth = <String, List<Photo>>{};
    final monthLabels = <String, String>{};

    for (final p in photos) {
      final d = p.dateTaken;
      final dd = DateTime(d.year, d.month, d.day);
      if (dd == today) {
        todayList.add(p);
      } else if (dd == yesterday) {
        yesterdayList.add(p);
      } else if (!dd.isBefore(weekStart) && dd.isBefore(today)) {
        weekList.add(p);
      } else if (d.year == now.year && d.month == now.month) {
        monthList.add(p);
      } else {
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        byMonth.putIfAbsent(key, () => []).add(p);
        monthLabels[key] = '${_monthName(d.month)} ${d.year}';
      }
    }

    final sections = <PhotoSection>[];
    if (todayList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'today',
        label: 'Today',
        sub: _weekdayDate(today),
        photos: todayList,
      ));
    }
    if (yesterdayList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'yesterday',
        label: 'Yesterday',
        sub: _weekdayDate(yesterday),
        photos: yesterdayList,
      ));
    }
    if (weekList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'week',
        label: 'This Week',
        sub: '${weekList.length} photos',
        photos: weekList,
      ));
    }
    if (monthList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'month',
        label: 'Earlier in ${_monthName(now.month)}',
        sub: '${monthList.length} photos',
        photos: monthList,
      ));
    }
    final keys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final k in keys) {
      sections.add(PhotoSection(
        key: k,
        label: monthLabels[k]!,
        sub: '${byMonth[k]!.length} photos',
        photos: byMonth[k]!,
      ));
    }
    return sections;
  }

  static String _monthName(int m) {
    const names = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    return names[m - 1];
  }

  static String _weekdayDate(DateTime d) {
    const w = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${w[d.weekday - 1]}, ${_monthName(d.month)} ${d.day}';
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/photo_service_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/services/photo_service.dart test/photo_service_test.dart
git commit -m "feat: PhotoService bucketize + fake loader"
```

---

## Task 6: PhotoService — device loader

**Files:**
- Modify: `lib/services/photo_service.dart`

(No unit test — requires real device. Manual QA only.)

- [ ] **Step 1: Add loadDevice method**

Append to `PhotoService` class in `lib/services/photo_service.dart`:

```dart
  static Future<List<Photo>> loadDevice() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return const [];
    final all = paths.first;
    final count = await all.assetCountAsync;
    if (count == 0) return const [];
    final assets = await all.getAssetListRange(start: 0, end: count);
    return assets.map<Photo>(DevicePhoto.new).toList();
  }
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/services/photo_service.dart
git commit -m "feat: PhotoService loadDevice via photo_manager"
```

---

## Task 7: GalleryController

**Files:**
- Create: `lib/controllers/gallery_controller.dart`
- Test: `test/gallery_controller_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/gallery_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/controllers/gallery_controller.dart';

void main() {
  group('GalleryController', () {
    test('initial state', () {
      final c = GalleryController();
      expect(c.cols, 3);
      expect(c.mode, GalleryMode.masonry);
      expect(c.selectMode, false);
      expect(c.selected, isEmpty);
      expect(c.pinchActive, false);
      expect(c.anchor, isNull);
    });

    test('setCols clamps to [2, maxCols] and notifies', () {
      final c = GalleryController();
      int notified = 0;
      c.addListener(() => notified++);
      c.setCols(5);
      expect(c.cols, 5);
      expect(notified, 1);
      c.setCols(0);
      expect(c.cols, 2);
      c.setCols(99);
      expect(c.cols, c.maxCols);
    });

    test('startPinch snapshots cols; endPinch flips active', () {
      final c = GalleryController()..setCols(4);
      c.startPinch();
      expect(c.pinchActive, true);
      expect(c.startCols, 4);
      c.setCols(6);
      c.endPinch();
      expect(c.pinchActive, false);
    });

    test('enterSelect / toggleSelect / exitSelect', () {
      final c = GalleryController();
      c.enterSelect('a');
      expect(c.selectMode, true);
      expect(c.selected, {'a'});
      c.toggleSelect('b');
      expect(c.selected, {'a', 'b'});
      c.toggleSelect('a');
      expect(c.selected, {'b'});
      c.exitSelect();
      expect(c.selectMode, false);
      expect(c.selected, isEmpty);
    });

    test('setMaxCols clamps current cols', () {
      final c = GalleryController()..setCols(7);
      c.setMaxCols(5);
      expect(c.cols, 5);
    });

    test('setAnchor / clearAnchor', () {
      final c = GalleryController();
      c.setAnchor(const AnchorState(photoId: 'p1', offset: 12.0));
      expect(c.anchor?.photoId, 'p1');
      c.clearAnchor();
      expect(c.anchor, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/gallery_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement GalleryController**

Create `lib/controllers/gallery_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

enum GalleryMode { grid, masonry }

class AnchorState {
  final String photoId;
  final double offset;
  const AnchorState({required this.photoId, required this.offset});
}

class GalleryController extends ChangeNotifier {
  static const int absoluteMinCols = 2;
  static const int absoluteMaxCols = 9;

  int _cols = 3;
  int get cols => _cols;

  GalleryMode _mode = GalleryMode.masonry;
  GalleryMode get mode => _mode;

  int _maxCols = 7;
  int get maxCols => _maxCols;

  bool _selectMode = false;
  bool get selectMode => _selectMode;

  final Set<String> _selected = <String>{};
  Set<String> get selected => _selected;

  bool _pinchActive = false;
  bool get pinchActive => _pinchActive;
  int _startCols = 3;
  int get startCols => _startCols;

  AnchorState? _anchor;
  AnchorState? get anchor => _anchor;

  void setCols(int next) {
    final clamped = next.clamp(absoluteMinCols, _maxCols);
    if (clamped == _cols) return;
    _cols = clamped;
    notifyListeners();
  }

  void setMode(GalleryMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
  }

  void setMaxCols(int m) {
    final mm = m.clamp(absoluteMinCols, absoluteMaxCols);
    if (mm == _maxCols) return;
    _maxCols = mm;
    if (_cols > mm) _cols = mm;
    notifyListeners();
  }

  void startPinch() {
    _pinchActive = true;
    _startCols = _cols;
    notifyListeners();
  }

  void endPinch() {
    if (!_pinchActive) return;
    _pinchActive = false;
    notifyListeners();
  }

  void enterSelect(String firstId) {
    _selectMode = true;
    _selected
      ..clear()
      ..add(firstId);
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void exitSelect() {
    if (!_selectMode && _selected.isEmpty) return;
    _selectMode = false;
    _selected.clear();
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    final all = ids.toSet();
    if (_selected.length == all.length) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(all);
    }
    notifyListeners();
  }

  void setAnchor(AnchorState a) {
    _anchor = a;
  }

  void clearAnchor() {
    _anchor = null;
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/gallery_controller_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/gallery_controller.dart test/gallery_controller_test.dart
git commit -m "feat: GalleryController state holder"
```

---

## Task 8: TileRegistry

**Files:**
- Create: `lib/widgets/tile_registry.dart`

- [ ] **Step 1: Implement TileRegistry**

Create `lib/widgets/tile_registry.dart`:

```dart
import 'package:flutter/material.dart';

class _TileHandle {
  final GlobalKey key;
  _TileHandle(this.key);
  RenderBox? findRenderBox() {
    final ro = key.currentContext?.findRenderObject();
    return ro is RenderBox ? ro : null;
  }
}

class TileRegistryScope extends StatefulWidget {
  final Widget child;
  const TileRegistryScope({super.key, required this.child});

  static TileRegistryState of(BuildContext ctx) {
    final s = ctx.findAncestorStateOfType<TileRegistryState>();
    assert(s != null, 'TileRegistryScope missing');
    return s!;
  }

  @override
  State<TileRegistryScope> createState() => TileRegistryState();
}

class TileRegistryState extends State<TileRegistryScope> {
  final Map<String, _TileHandle> _map = {};

  GlobalKey register(String photoId) {
    final existing = _map[photoId];
    if (existing != null) return existing.key;
    final h = _TileHandle(GlobalKey(debugLabel: 'tile_$photoId'));
    _map[photoId] = h;
    return h.key;
  }

  void unregister(String photoId) {
    _map.remove(photoId);
  }

  RenderBox? boxFor(String photoId) => _map[photoId]?.findRenderBox();

  Iterable<MapEntry<String, _TileHandle>> get entries => _map.entries;

  @override
  Widget build(BuildContext context) => widget.child;
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/tile_registry.dart
git commit -m "feat: TileRegistry for anchor lookup"
```

---

## Task 9: Metrics

**Files:**
- Create: `lib/widgets/metrics.dart`

- [ ] **Step 1: Implement Metrics**

Create `lib/widgets/metrics.dart`:

```dart
import 'package:flutter/material.dart';

class Metrics {
  final double scale;
  final double gap;
  final double tileRadius;
  final double headerExtent;
  final double headerPadTop;
  final double headerPadBottom;
  final double headerHGutter;
  final double labelFs;
  final double subFs;
  final double topBarPadH;
  final double topBarPadTop;
  final double topBarPadBottom;
  final double titleFs;
  final double titleSubFs;
  final double modeIconSize;
  final double modePadH;
  final double modePadV;
  final double modeRadius;
  final double modeOuterRadius;
  final double topIconSize;
  final double topIconGap;
  final double indicatorPadH;
  final double indicatorPadV;
  final double indicatorIconSize;
  final double indicatorBigFs;
  final double indicatorSmallFs;
  final double indicatorGap;
  final double selBarPadH;
  final double selBarPadTop;
  final double selBarBtnPadH;
  final double selBarIconSize;
  final double selBarLabelFs;
  final double selBarReserved;

  const Metrics._({
    required this.scale,
    required this.gap,
    required this.tileRadius,
    required this.headerExtent,
    required this.headerPadTop,
    required this.headerPadBottom,
    required this.headerHGutter,
    required this.labelFs,
    required this.subFs,
    required this.topBarPadH,
    required this.topBarPadTop,
    required this.topBarPadBottom,
    required this.titleFs,
    required this.titleSubFs,
    required this.modeIconSize,
    required this.modePadH,
    required this.modePadV,
    required this.modeRadius,
    required this.modeOuterRadius,
    required this.topIconSize,
    required this.topIconGap,
    required this.indicatorPadH,
    required this.indicatorPadV,
    required this.indicatorIconSize,
    required this.indicatorBigFs,
    required this.indicatorSmallFs,
    required this.indicatorGap,
    required this.selBarPadH,
    required this.selBarPadTop,
    required this.selBarBtnPadH,
    required this.selBarIconSize,
    required this.selBarLabelFs,
    required this.selBarReserved,
  });

  factory Metrics.of(BuildContext ctx) {
    final mq = MediaQuery.of(ctx);
    final shortest = mq.size.shortestSide;
    final s = (shortest / 390.0).clamp(0.82, 1.6);
    final tabletBoost = shortest >= 600 ? 1.15 : 1.0;
    return Metrics._(
      scale: s.toDouble(),
      gap: 3 * s,
      tileRadius: 6 * s,
      headerExtent: 64 * s,
      headerPadTop: 14 * s,
      headerPadBottom: 8 * s,
      headerHGutter: 14 * s,
      labelFs: 17 * s,
      subFs: 12 * s,
      topBarPadH: 14 * s,
      topBarPadTop: 4 * s,
      topBarPadBottom: 8 * s,
      titleFs: 26 * s * tabletBoost,
      titleSubFs: 11 * s,
      modeIconSize: 16 * s,
      modePadH: 8 * s,
      modePadV: 4 * s,
      modeRadius: 12 * s,
      modeOuterRadius: 14 * s,
      topIconSize: 22 * s,
      topIconGap: 6 * s,
      indicatorPadH: 22 * s,
      indicatorPadV: 12 * s,
      indicatorIconSize: 18 * s,
      indicatorBigFs: 22 * s,
      indicatorSmallFs: 11 * s,
      indicatorGap: 8 * s,
      selBarPadH: 12 * s,
      selBarPadTop: 12 * s,
      selBarBtnPadH: 12 * s,
      selBarIconSize: 22 * s,
      selBarLabelFs: 10 * s,
      selBarReserved: 110 * s,
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/metrics.dart
git commit -m "feat: Metrics screen-relative sizes"
```

---

## Task 10: PhotoTile

**Files:**
- Create: `lib/widgets/photo_tile.dart`
- Test: `test/photo_tile_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/photo_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/models/photo.dart';
import 'package:entemobilephotogallery/widgets/photo_tile.dart';
import 'package:entemobilephotogallery/widgets/tile_registry.dart';

class _FakeForTest implements Photo {
  @override
  String get id => 'tid';
  @override
  int get width => 100;
  @override
  int get height => 100;
  @override
  bool get isVideo => false;
  @override
  DateTime get dateTaken => DateTime(2026, 5, 15);
  @override
  ImageProvider thumb(int sidePx) => const _BlankProvider();
  @override
  ImageProvider full() => const _BlankProvider();
}

class _BlankProvider extends ImageProvider<Object> {
  const _BlankProvider();
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) async => this;
  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: Future.error('no decode'),
      scale: 1.0,
    );
  }
}

void main() {
  testWidgets('renders skeleton when image not loaded', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TileRegistryScope(
        child: Scaffold(
          body: PhotoTile(
            photo: _FakeForTest(),
            width: 100,
            height: 100,
            thumbPx: 96,
            radius: 6,
            selected: false,
            selectMode: false,
            accent: const Color(0xFF7DDCC9),
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
    // Skeleton DecoratedBox is present (the inner gradient box). Find by widget type:
    expect(find.byType(PhotoTile), findsOneWidget);
    // No exception thrown rendering despite no decode.
  });

  testWidgets('shows selection badge when selectMode + selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TileRegistryScope(
        child: Scaffold(
          body: PhotoTile(
            photo: _FakeForTest(),
            width: 100,
            height: 100,
            thumbPx: 96,
            radius: 6,
            selected: true,
            selectMode: true,
            accent: const Color(0xFF7DDCC9),
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/photo_tile_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement PhotoTile**

Create `lib/widgets/photo_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/photo.dart';
import 'tile_registry.dart';

class PhotoTile extends StatefulWidget {
  final Photo photo;
  final double width;
  final double height;
  final int thumbPx;
  final double radius;
  final bool selected;
  final bool selectMode;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final BoxFit fit;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.width,
    required this.height,
    required this.thumbPx,
    required this.radius,
    required this.selected,
    required this.selectMode,
    required this.accent,
    required this.onTap,
    required this.onLongPress,
    this.fit = BoxFit.cover,
  });

  @override
  State<PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<PhotoTile> {
  GlobalKey? _registryKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registryKey ??= TileRegistryScope.of(context).register(widget.photo.id);
  }

  @override
  void dispose() {
    final ctx = context;
    final state = ctx.findAncestorStateOfType<TileRegistryState>();
    state?.unregister(widget.photo.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileMin = widget.width < widget.height ? widget.width : widget.height;
    final badgeSize = (tileMin * 0.22).clamp(14.0, 26.0);
    final badgeIcon = badgeSize * 0.62;
    final badgeInset = (tileMin * 0.06).clamp(4.0, 10.0);
    final videoIcon = (tileMin * 0.18).clamp(12.0, 22.0);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          key: _registryKey,
          width: widget.width,
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF161616)),
                _Thumb(
                  photo: widget.photo,
                  thumbPx: widget.thumbPx,
                  fit: widget.fit,
                  selected: widget.selected,
                ),
                if (widget.selectMode)
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: widget.selected
                          ? widget.accent.withValues(alpha: 0.13)
                          : Colors.transparent,
                    ),
                  ),
                if (widget.selectMode)
                  Positioned(
                    top: badgeInset,
                    right: badgeInset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        color: widget.selected
                            ? widget.accent
                            : Colors.black.withValues(alpha: 0.32),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.selected
                              ? widget.accent
                              : Colors.white.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: widget.selected
                          ? Icon(Icons.check,
                              size: badgeIcon,
                              color: const Color(0xFF0A0A0A))
                          : null,
                    ),
                  ),
                if (widget.photo.isVideo)
                  Positioned(
                    bottom: badgeInset,
                    right: badgeInset,
                    child: Icon(Icons.play_circle_fill,
                        size: videoIcon, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Photo photo;
  final int thumbPx;
  final BoxFit fit;
  final bool selected;
  const _Thumb({
    required this.photo,
    required this.thumbPx,
    required this.fit,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      scale: selected ? 0.88 : 1.0,
      child: Image(
        image: ResizeImage(
          photo.thumb(thumbPx),
          width: thumbPx,
          height: thumbPx,
          policy: ResizeImagePolicy.fit,
        ),
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        frameBuilder: (ctx, child, frame, wasSync) {
          if (wasSync || frame != null) return child;
          return const _Skeleton();
        },
        errorBuilder: (_, __, ___) => const _Skeleton(error: true),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final bool error;
  const _Skeleton({this.error = false});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: error
              ? const [Color(0xFF1A1A1A), Color(0xFF111111)]
              : const [Color(0xFF1E1E1E), Color(0xFF141414)],
        ),
      ),
      child: error
          ? const Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Colors.white24, size: 20),
            )
          : null,
    );
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/photo_tile_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/photo_tile.dart test/photo_tile_test.dart
git commit -m "feat: PhotoTile with skeleton + registry registration"
```

---

## Task 11: SectionHeader

**Files:**
- Create: `lib/widgets/section_header.dart`

- [ ] **Step 1: Implement SectionHeader**

Create `lib/widgets/section_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'metrics.dart';

class SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final String sub;
  final int count;
  final Metrics metrics;
  SectionHeaderDelegate({
    required this.label,
    required this.sub,
    required this.count,
    required this.metrics,
  });

  @override
  double get minExtent => metrics.headerExtent;
  @override
  double get maxExtent => metrics.headerExtent;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    final m = metrics;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF50A0A0A), Color(0xF20A0A0A)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          m.headerHGutter, m.headerPadTop, m.headerHGutter, m.headerPadBottom),
      alignment: Alignment.bottomLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: m.labelFs,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                )),
            SizedBox(height: 2 * m.scale),
            Text('$sub · $count photos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: m.subFs,
                  letterSpacing: 0.1,
                )),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SectionHeaderDelegate old) =>
      old.label != label ||
      old.sub != sub ||
      old.count != count ||
      old.metrics.headerExtent != metrics.headerExtent;
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/section_header.dart
git commit -m "feat: SectionHeader sticky delegate"
```

---

## Task 12: PhotoGrid sliver wrapper

**Files:**
- Create: `lib/widgets/photo_grid.dart`

- [ ] **Step 1: Implement PhotoGrid**

Create `lib/widgets/photo_grid.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/photo.dart';

typedef PhotoTileBuilder = Widget Function(
    BuildContext ctx, Photo photo, int indexInSection, double tileW, double tileH);

class PhotoGrid extends StatelessWidget {
  final List<Photo> photos;
  final int cols;
  final double gap;
  final double tileW;
  final int thumbPx;
  final PhotoTileBuilder tileBuilder;

  const PhotoGrid({
    super.key,
    required this.photos,
    required this.cols,
    required this.gap,
    required this.tileW,
    required this.thumbPx,
    required this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => tileBuilder(ctx, photos[i], i, tileW, tileW),
        childCount: photos.length,
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: false,
        findChildIndexCallback: (key) {
          final id = (key as ValueKey<String>).value;
          final idx = photos.indexWhere((p) => p.id == id);
          return idx < 0 ? null : idx;
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/photo_grid.dart
git commit -m "feat: PhotoGrid sliver wrapper"
```

---

## Task 13: PhotoMasonry sliver wrapper

**Files:**
- Create: `lib/widgets/photo_masonry.dart`

- [ ] **Step 1: Implement PhotoMasonry**

Create `lib/widgets/photo_masonry.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/aspect.dart';
import '../models/photo.dart';
import 'photo_grid.dart';

class PhotoMasonry extends StatelessWidget {
  final List<Photo> photos;
  final int cols;
  final double gap;
  final double tileW;
  final int thumbPx;
  final PhotoTileBuilder tileBuilder;

  const PhotoMasonry({
    super.key,
    required this.photos,
    required this.cols,
    required this.gap,
    required this.tileW,
    required this.thumbPx,
    required this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid(
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
      ),
      mainAxisSpacing: gap,
      crossAxisSpacing: gap,
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final p = photos[i];
          final ratio = safeRatio(p.width, p.height);
          final h = tileW / ratio;
          return tileBuilder(ctx, p, i, tileW, h);
        },
        childCount: photos.length,
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: false,
        findChildIndexCallback: (key) {
          final id = (key as ValueKey<String>).value;
          final idx = photos.indexWhere((p) => p.id == id);
          return idx < 0 ? null : idx;
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/photo_masonry.dart
git commit -m "feat: PhotoMasonry long-form with key reuse"
```

---

## Task 14: PinchGestureLayer

**Files:**
- Create: `lib/widgets/pinch_gesture_layer.dart`

- [ ] **Step 1: Implement PinchGestureLayer**

Create `lib/widgets/pinch_gesture_layer.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/gallery_controller.dart';

class PinchGestureLayer extends StatefulWidget {
  final GalleryController controller;
  final VoidCallback onCaptureAnchor;
  final VoidCallback onRestoreAnchor;
  final Widget child;
  const PinchGestureLayer({
    super.key,
    required this.controller,
    required this.onCaptureAnchor,
    required this.onRestoreAnchor,
    required this.child,
  });

  @override
  State<PinchGestureLayer> createState() => _PinchGestureLayerState();
}

class _PinchGestureLayerState extends State<PinchGestureLayer> {
  bool _twoFinger = false;
  double _scaleBase = 1.0;

  void _onStart(ScaleStartDetails d) {
    _twoFinger = false;
    _scaleBase = 1.0;
  }

  void _onUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) {
      if (_twoFinger) {
        _twoFinger = false;
        widget.controller.endPinch();
      }
      return;
    }
    if (!_twoFinger) {
      _twoFinger = true;
      _scaleBase = d.scale == 0 ? 1.0 : d.scale;
      widget.onCaptureAnchor();
      widget.controller.startPinch();
      return;
    }
    final rel = d.scale / _scaleBase;
    if (rel <= 0) return;
    final start = widget.controller.startCols;
    final next = (start / rel).round();
    final prev = widget.controller.cols;
    widget.controller.setCols(next);
    if (widget.controller.cols != prev) {
      HapticFeedback.selectionClick();
      widget.onRestoreAnchor();
    }
  }

  void _onEnd(ScaleEndDetails d) {
    _twoFinger = false;
    widget.controller.endPinch();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
          () => ScaleGestureRecognizer(),
          (instance) {
            instance.onStart = _onStart;
            instance.onUpdate = _onUpdate;
            instance.onEnd = _onEnd;
          },
        ),
      },
      child: widget.child,
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/pinch_gesture_layer.dart
git commit -m "feat: PinchGestureLayer using ScaleGestureRecognizer"
```

---

## Task 15: PinchOverlay

**Files:**
- Create: `lib/widgets/pinch_overlay.dart`

- [ ] **Step 1: Implement PinchOverlay**

Create `lib/widgets/pinch_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'metrics.dart';

class PinchOverlay extends StatelessWidget {
  final int cols;
  final Metrics metrics;
  const PinchOverlay({super.key, required this.cols, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: m.indicatorPadH, vertical: m.indicatorPadV),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded,
                color: Colors.white70, size: m.indicatorIconSize),
            SizedBox(width: m.indicatorGap),
            Text('$cols',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: m.indicatorBigFs,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                )),
            SizedBox(width: 6 * m.scale),
            Text('COLS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: m.indicatorSmallFs,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/pinch_overlay.dart
git commit -m "feat: PinchOverlay column indicator"
```

---

## Task 16: TopBar

**Files:**
- Create: `lib/widgets/top_bar.dart`
- Test: `test/top_bar_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/top_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/controllers/gallery_controller.dart';
import 'package:entemobilephotogallery/widgets/metrics.dart';
import 'package:entemobilephotogallery/widgets/top_bar.dart';

void main() {
  testWidgets('mode toggle invokes callback for grid', (tester) async {
    GalleryMode? changed;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        final m = Metrics.of(ctx);
        return Scaffold(
          body: TopBar(
            metrics: m,
            totalCount: 100,
            mode: GalleryMode.masonry,
            onModeChange: (mm) => changed = mm,
            selectMode: false,
            selectedCount: 0,
            onToggleSelect: () {},
            onCancelSelect: () {},
            onSelectAll: () {},
            pinchActive: false,
            pinchCols: 3,
            accent: const Color(0xFF7DDCC9),
          ),
        );
      }),
    ));
    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    expect(changed, GalleryMode.grid);
  });

  testWidgets('Cancel button in select mode fires onCancelSelect', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        final m = Metrics.of(ctx);
        return Scaffold(
          body: TopBar(
            metrics: m,
            totalCount: 10,
            mode: GalleryMode.masonry,
            onModeChange: (_) {},
            selectMode: true,
            selectedCount: 2,
            onToggleSelect: () {},
            onCancelSelect: () => cancelled = true,
            onSelectAll: () {},
            pinchActive: false,
            pinchCols: 3,
            accent: const Color(0xFF7DDCC9),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Cancel'));
    expect(cancelled, true);
  });
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/top_bar_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Implement TopBar**

Create `lib/widgets/top_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../controllers/gallery_controller.dart';
import 'metrics.dart';

class TopBar extends StatelessWidget {
  final Metrics metrics;
  final int totalCount;
  final GalleryMode mode;
  final ValueChanged<GalleryMode> onModeChange;
  final bool selectMode;
  final int selectedCount;
  final VoidCallback onToggleSelect;
  final VoidCallback onCancelSelect;
  final VoidCallback onSelectAll;
  final bool pinchActive;
  final int pinchCols;
  final Color accent;

  const TopBar({
    super.key,
    required this.metrics,
    required this.totalCount,
    required this.mode,
    required this.onModeChange,
    required this.selectMode,
    required this.selectedCount,
    required this.onToggleSelect,
    required this.onCancelSelect,
    required this.onSelectAll,
    required this.pinchActive,
    required this.pinchCols,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    const bg = Color(0xFF0A0A0A);
    if (selectMode) {
      return Container(
        color: bg,
        padding: EdgeInsets.fromLTRB(
            m.topBarPadH, 6 * m.scale, m.topBarPadH, 12 * m.scale),
        child: Row(
          children: [
            TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: accent, padding: EdgeInsets.zero),
              onPressed: onCancelSelect,
              child: Text('Cancel',
                  style:
                      TextStyle(fontSize: 15 * m.scale, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  selectedCount == 0 ? 'Select Items' : '$selectedCount selected',
                  style: TextStyle(
                      fontSize: 13 * m.scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
            TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: accent, padding: EdgeInsets.zero),
              onPressed: onSelectAll,
              child: Text(
                selectedCount == totalCount && totalCount > 0 ? 'Deselect' : 'All',
                style: TextStyle(fontSize: 15 * m.scale, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(
          m.topBarPadH, m.topBarPadTop, m.topBarPadH - 2, m.topBarPadBottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Photos',
                    style: TextStyle(
                      fontSize: m.titleFs,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1,
                    )),
                SizedBox(height: 4 * m.scale),
                Text(
                  pinchActive ? '$pinchCols columns' : '$totalCount items',
                  style: TextStyle(
                    fontSize: m.titleSubFs,
                    color: pinchActive
                        ? accent
                        : Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          _ModeToggle(mode: mode, onChange: onModeChange, metrics: m),
          SizedBox(width: m.topIconGap),
          IconButton(
            onPressed: onToggleSelect,
            icon: Icon(Icons.check_circle_outline,
                color: Colors.white, size: m.topIconSize),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final GalleryMode mode;
  final ValueChanged<GalleryMode> onChange;
  final Metrics metrics;
  const _ModeToggle({required this.mode, required this.onChange, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    Widget cell(GalleryMode mm, IconData icon) {
      final active = mode == mm;
      return GestureDetector(
        onTap: () => onChange(mm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: m.modePadH, vertical: m.modePadV),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1F1F1F) : Colors.transparent,
            borderRadius: BorderRadius.circular(m.modeRadius),
            boxShadow: active
                ? const [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 1))]
                : null,
          ),
          child: Icon(icon,
              size: m.modeIconSize,
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.55)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(m.modeOuterRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell(GalleryMode.grid, Icons.grid_view_rounded),
          const SizedBox(width: 2),
          cell(GalleryMode.masonry, Icons.dashboard_rounded),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/top_bar_test.dart`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/top_bar.dart test/top_bar_test.dart
git commit -m "feat: TopBar with mode toggle + select toggle"
```

---

## Task 17: SelectionBar

**Files:**
- Create: `lib/widgets/selection_bar.dart`

- [ ] **Step 1: Implement SelectionBar**

Create `lib/widgets/selection_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'metrics.dart';

class SelectionBar extends StatelessWidget {
  final int count;
  final Metrics metrics;
  const SelectionBar({super.key, required this.count, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    Widget btn(IconData icon, String label) {
      final enabled = count > 0;
      return Padding(
        padding:
            EdgeInsets.symmetric(horizontal: m.selBarBtnPadH, vertical: 4 * m.scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: m.selBarIconSize,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3)),
            SizedBox(height: 4 * m.scale),
            Text(label,
                style: TextStyle(
                  fontSize: m.selBarLabelFs,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                )),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          m.selBarPadH,
          m.selBarPadTop,
          m.selBarPadH,
          MediaQuery.of(context).padding.bottom + 8 * m.scale),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF70A0A0A), Color(0x000A0A0A)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          btn(Icons.ios_share, 'Share'),
          btn(Icons.download_outlined, 'Save'),
          btn(Icons.delete_outline, 'Delete'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/selection_bar.dart
git commit -m "feat: SelectionBar bottom actions"
```

---

## Task 18: PhotoViewerPage

**Files:**
- Create: `lib/pages/photo_viewer_page.dart`

- [ ] **Step 1: Implement PhotoViewerPage**

Create `lib/pages/photo_viewer_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/photo.dart';

double _scale(BuildContext ctx) {
  final s = MediaQuery.of(ctx).size.shortestSide / 390.0;
  return s.clamp(0.82, 1.6);
}

class PhotoViewerPage extends StatefulWidget {
  final List<Photo> photos;
  final int initialIndex;
  final Color accent;
  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.accent,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late int _index;
  late PageController _pageController;
  late ScrollController _stripController;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _stripController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerStrip(animated: false));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  void _centerStrip({bool animated = true}) {
    if (!_stripController.hasClients) return;
    final s = _scale(context);
    final itemW = 33.0 * s;
    final w = MediaQuery.of(context).size.width;
    final target = (_index * itemW - w / 2 + itemW / 2)
        .clamp(0.0, _stripController.position.maxScrollExtent);
    if (animated) {
      _stripController.animateTo(target,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _stripController.jumpTo(target);
    }
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _centerStrip();
  }

  void _goTo(int i) {
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: _onPageChanged,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              builder: (ctx, i) {
                final ph = widget.photos[i];
                return PhotoViewGalleryPageOptions(
                  imageProvider: ph.full(),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: 'photo_${ph.id}'),
                );
              },
              loadingBuilder: (ctx, _) => const Center(
                child: CircularProgressIndicator(color: Color(0xFF7DDCC9)),
              ),
            ),
            AnimatedOpacity(
              opacity: _chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: _TopChrome(photo: p, index: _index, total: widget.photos.length),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _chromeVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: _BottomChrome(
                    photos: widget.photos,
                    index: _index,
                    accent: widget.accent,
                    stripController: _stripController,
                    onTapStrip: _goTo,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  final Photo photo;
  final int index;
  final int total;
  const _TopChrome({required this.photo, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final d = photo.dateTaken;
    final padTop = MediaQuery.of(context).padding.top + 12 * s;
    return Container(
      padding: EdgeInsets.fromLTRB(14 * s, padTop, 14 * s, 14 * s),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          _RoundBtn(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.of(context).pop()),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatDate(d),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: 1 * s),
                Text('${index + 1} of $total · ${_formatTime(d)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          _RoundBtn(icon: Icons.more_horiz, onTap: () {}),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatTime(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h12:$mm $ampm';
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36 * s,
          height: 36 * s,
          child: Icon(icon, color: Colors.white, size: 16 * s),
        ),
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  final List<Photo> photos;
  final int index;
  final Color accent;
  final ScrollController stripController;
  final ValueChanged<int> onTapStrip;
  const _BottomChrome({
    required this.photos,
    required this.index,
    required this.accent,
    required this.stripController,
    required this.onTapStrip,
  });

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final stripH = 46 * s;
    final small = 30 * s;
    final big = 40 * s;
    return Container(
      padding: EdgeInsets.only(top: 14 * s, bottom: bottomInset + 16 * s),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: stripH,
            child: ListView.separated(
              controller: stripController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12 * s),
              itemCount: photos.length,
              separatorBuilder: (_, __) => SizedBox(width: 3 * s),
              itemBuilder: (ctx, i) {
                final cur = i == index;
                final p = photos[i];
                return GestureDetector(
                  onTap: () => onTapStrip(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: cur ? big : small,
                    height: cur ? big : small,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4 * s),
                      border: Border.all(
                        color: cur ? accent : Colors.white.withValues(alpha: 0.15),
                        width: cur ? 1.5 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Opacity(
                      opacity: cur ? 1 : 0.7,
                      child: Image(image: p.thumb(120), fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 8 * s),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionBtn(icon: Icons.ios_share, label: 'Share'),
              _ActionBtn(icon: Icons.download_outlined, label: 'Save'),
              _ActionBtn(icon: Icons.star_border, label: 'Favorite'),
              _ActionBtn(icon: Icons.delete_outline, label: 'Delete'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionBtn({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 20 * s),
          SizedBox(height: 4 * s),
          Text(label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 10 * s,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              )),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/pages/photo_viewer_page.dart
git commit -m "feat: PhotoViewerPage swipe + zoom + chrome"
```

---

## Task 19: GalleryPage

**Files:**
- Create: `lib/pages/gallery_page.dart`

- [ ] **Step 1: Implement GalleryPage**

Create `lib/pages/gallery_page.dart`:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../controllers/gallery_controller.dart';
import '../models/photo.dart';
import '../models/photo_section.dart';
import '../services/photo_service.dart';
import '../services/thumb_resolver.dart';
import '../widgets/metrics.dart';
import '../widgets/photo_grid.dart';
import '../widgets/photo_masonry.dart';
import '../widgets/photo_tile.dart';
import '../widgets/pinch_gesture_layer.dart';
import '../widgets/pinch_overlay.dart';
import '../widgets/section_header.dart';
import '../widgets/selection_bar.dart';
import '../widgets/tile_registry.dart';
import '../widgets/top_bar.dart';
import 'photo_viewer_page.dart';

const Color kBg = Color(0xFF0A0A0A);
const Color kAccent = Color(0xFF7DDCC9);
const bool kUseFakePhotos = false;
const int kFakePhotoCount = 300;

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final GalleryController _controller = GalleryController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _registryKey = GlobalKey();
  bool _loading = true;
  String? _error;
  List<PhotoSection> _sections = const [];
  List<Photo> _flat = const [];
  int _totalCount = 0;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCtrl);
    _bootstrap();
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onCtrl);
    _controller.dispose();
    _scrollController.dispose();
    _reloadDebounce?.cancel();
    PhotoManager.removeChangeCallback(_onPhotoChange);
    super.dispose();
  }

  void _onPhotoChange(MethodCall call) {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted) _reload();
    });
  }

  Future<void> _bootstrap() async {
    if (kUseFakePhotos) {
      await _reload();
      return;
    }
    final state = await PhotoService.requestPermission();
    if (!state.hasAccess) {
      setState(() {
        _loading = false;
        _error = 'Photo access denied. Enable in settings.';
      });
      return;
    }
    PhotoManager.addChangeCallback(_onPhotoChange);
    PhotoManager.startChangeNotify();
    await _reload();
  }

  Future<void> _reload() async {
    final items = kUseFakePhotos
        ? PhotoService.loadFake(count: kFakePhotoCount)
        : await PhotoService.loadDevice();
    final sections = PhotoService.bucketize(items);
    if (!mounted) return;
    final flat = <Photo>[];
    for (final s in sections) {
      flat.addAll(s.photos);
    }
    setState(() {
      _sections = sections;
      _flat = flat;
      _totalCount = items.length;
      _loading = false;
      _error = null;
    });
  }

  int _maxColsForWidth(double w) {
    if (w >= 900) return 9;
    if (w >= 600) return 8;
    return 7;
  }

  void _captureAnchor() {
    final ro = _registryKey.currentContext?.findRenderObject();
    if (ro is! RenderBox) return;
    final viewportTop = ro.localToGlobal(Offset.zero).dy;
    final state =
        _registryKey.currentContext!.findAncestorStateOfType<TileRegistryState>();
    if (state == null) return;
    String? bestId;
    double bestDy = double.infinity;
    for (final entry in state.entries) {
      final box = entry.value.findRenderBox();
      if (box == null) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy + box.size.height < viewportTop) continue;
      if (dy < bestDy) {
        bestDy = dy;
        bestId = entry.key;
      }
    }
    if (bestId == null) {
      _controller.clearAnchor();
      return;
    }
    _controller.setAnchor(AnchorState(
      photoId: bestId,
      offset: bestDy - viewportTop,
    ));
  }

  void _restoreAnchor() {
    final a = _controller.anchor;
    if (a == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _registryKey.currentContext
          ?.findAncestorStateOfType<TileRegistryState>();
      final box = state?.boxFor(a.photoId);
      final ro = _registryKey.currentContext?.findRenderObject();
      if (box == null || ro is! RenderBox || !_scrollController.hasClients) {
        _controller.clearAnchor();
        return;
      }
      final viewportTop = ro.localToGlobal(Offset.zero).dy;
      final currentDy = box.localToGlobal(Offset.zero).dy;
      final delta = currentDy - viewportTop - a.offset;
      final target = (_scrollController.offset + delta)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(target);
      _controller.clearAnchor();
    });
  }

  void _onTileTap(Photo p, int globalIndex) {
    if (_controller.selectMode) {
      _controller.toggleSelect(p.id);
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => PhotoViewerPage(
          photos: _flat,
          initialIndex: globalIndex,
          accent: kAccent,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(anim), child: child),
        ),
      ),
    );
  }

  void _onTileLongPress(Photo p) {
    HapticFeedback.mediumImpact();
    _controller.enterSelect(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _bootstrap)
                : _buildGallery(m),
      ),
    );
  }

  Widget _buildGallery(Metrics m) {
    final viewportW = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    _controller.setMaxCols(_maxColsForWidth(viewportW));
    final innerW = viewportW - 2 * m.gap;
    final tileW =
        ((innerW - m.gap * (_controller.cols - 1)) / _controller.cols)
            .clamp(1.0, double.infinity);
    final thumbPx = ThumbResolver.bucket(tileW * dpr);
    final globalStart = <String, int>{};
    var running = 0;
    for (final s in _sections) {
      globalStart[s.key] = running;
      running += s.photos.length;
    }

    return TileRegistryScope(
      key: _registryKey,
      child: Stack(
        children: [
          Column(
            children: [
              TopBar(
                metrics: m,
                totalCount: _totalCount,
                mode: _controller.mode,
                onModeChange: _controller.setMode,
                selectMode: _controller.selectMode,
                selectedCount: _controller.selected.length,
                onToggleSelect: () => _controller.selectMode
                    ? _controller.exitSelect()
                    : _controller.enterSelect(''),
                onCancelSelect: _controller.exitSelect,
                onSelectAll: () =>
                    _controller.selectAll(_flat.map((p) => p.id)),
                pinchActive: _controller.pinchActive,
                pinchCols: _controller.cols,
                accent: kAccent,
              ),
              Expanded(
                child: PinchGestureLayer(
                  controller: _controller,
                  onCaptureAnchor: _captureAnchor,
                  onRestoreAnchor: _restoreAnchor,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: _controller.pinchActive
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    slivers: _buildSlivers(m, tileW, thumbPx, globalStart),
                  ),
                ),
              ),
            ],
          ),
          if (_controller.pinchActive)
            IgnorePointer(
              child: PinchOverlay(cols: _controller.cols, metrics: m),
            ),
          if (_controller.selectMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SelectionBar(
                  count: _controller.selected.length, metrics: m),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSlivers(
      Metrics m, double tileW, int thumbPx, Map<String, int> globalStart) {
    final slivers = <Widget>[];
    for (final s in _sections) {
      slivers.add(SliverPersistentHeader(
        pinned: true,
        delegate: SectionHeaderDelegate(
          label: s.label,
          sub: s.sub,
          count: s.photos.length,
          metrics: m,
        ),
      ));
      final start = globalStart[s.key]!;
      Widget tileBuilder(
          BuildContext ctx, Photo p, int i, double w, double h) {
        return PhotoTile(
          key: ValueKey(p.id),
          photo: p,
          width: w,
          height: h,
          thumbPx: thumbPx,
          radius: m.tileRadius,
          selected: _controller.selected.contains(p.id),
          selectMode: _controller.selectMode,
          accent: kAccent,
          onTap: () => _onTileTap(p, start + i),
          onLongPress: () => _onTileLongPress(p),
        );
      }

      slivers.add(SliverPadding(
        padding: EdgeInsets.fromLTRB(m.gap, 0, m.gap, 16 * m.scale),
        sliver: _controller.mode == GalleryMode.grid
            ? PhotoGrid(
                photos: s.photos,
                cols: _controller.cols,
                gap: m.gap,
                tileW: tileW,
                thumbPx: thumbPx,
                tileBuilder: tileBuilder,
              )
            : PhotoMasonry(
                photos: s.photos,
                cols: _controller.cols,
                gap: m.gap,
                tileW: tileW,
                thumbPx: thumbPx,
                tileBuilder: tileBuilder,
              ),
      ));
    }
    slivers.add(SliverToBoxAdapter(
      child: SizedBox(
          height: _controller.selectMode ? m.selBarReserved : 32 * m.scale),
    ));
    return slivers;
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final s = (MediaQuery.of(context).size.shortestSide / 390.0).clamp(0.85, 1.4);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 48 * s, color: Colors.white38),
            SizedBox(height: 16 * s),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15 * s)),
            SizedBox(height: 20 * s),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kAccent, foregroundColor: kBg),
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('Open Settings'),
            ),
            SizedBox(height: 8 * s),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: kAccent),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/pages/gallery_page.dart
git commit -m "feat: GalleryPage composition + anchor preservation"
```

---

## Task 20: Wire main.dart

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Replace main.dart**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/gallery_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache
    ..maximumSize = 600
    ..maximumSizeBytes = 256 << 20;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0A0A0A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const EnteGalleryApp());
}

class EnteGalleryApp extends StatelessWidget {
  const EnteGalleryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ente Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF0A0A0A),
          primary: Color(0xFF7DDCC9),
          secondary: Color(0xFF7DDCC9),
        ),
        textTheme: const TextTheme()
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const GalleryPage(),
    );
  }
}
```

- [ ] **Step 2: Replace widget_test.dart**

Replace `test/widget_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:entemobilephotogallery/main.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    await tester.pumpWidget(const EnteGalleryApp());
    await tester.pump();
  });
}
```

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 4: Verify analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: wire main.dart to GalleryPage + ImageCache config"
```

---

## Task 21: Android Manifest + iOS Info.plist

**Files:**
- Verify: `android/app/src/main/AndroidManifest.xml`
- Verify: `ios/Runner/Info.plist`

(These were updated in earlier sessions. Verify they contain the needed keys.)

- [ ] **Step 1: Check AndroidManifest contains permissions**

Run: `grep -E "INTERNET|READ_MEDIA_IMAGES|READ_MEDIA_VIDEO|ACCESS_MEDIA_LOCATION|READ_EXTERNAL_STORAGE" "android/app/src/main/AndroidManifest.xml"`
Expected: Five lines, one per permission.

If any missing, add inside `<manifest>` before `<application>`:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED"/>
    <uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION"/>
```

- [ ] **Step 2: Check Info.plist contains usage strings**

Run: `grep -E "NSPhotoLibraryUsageDescription|NSPhotoLibraryAddUsageDescription" "ios/Runner/Info.plist"`
Expected: Two lines.

If missing, add inside `<dict>`:

```xml
	<key>NSPhotoLibraryUsageDescription</key>
	<string>This app needs photo library access to display your photos in the gallery.</string>
	<key>NSPhotoLibraryAddUsageDescription</key>
	<string>This app needs photo library access to save edited photos.</string>
```

- [ ] **Step 3: Commit if changes**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: verify media permissions on Android + iOS" || echo "no changes"
```

---

## Task 22: README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace README**

Replace `README.md` with:

```markdown
# Ente Mobile Photo Gallery

Flutter implementation of the Ente assignment.

## Features

- Pinch-to-zoom column count (2-7) on grid and masonry layouts.
- Masonry layout preserves each photo's original aspect ratio (Part 2).
- Grid ↔ masonry toggle from top bar.
- Sticky date-section headers (Today / Yesterday / This Week / Earlier in <month> / older months).
- Long-press to multi-select. Cancel/Select-All in top bar. Bottom action bar with Share/Save/Delete (stubs).
- Photo viewer with swipe between, double-tap zoom, filmstrip, tap-to-toggle chrome.
- Photo-id-based scroll anchor preservation across column changes — the photo at the top of viewport stays put.
- Dark Material 3 theme; mint accent for active states.

## Run

```bash
flutter pub get
flutter run
```

Build release APK:

```bash
flutter build apk --release
```

APK lives at `build/app/outputs/flutter-apk/app-release.apk`.

## Architecture

```
lib/
  main.dart                       # entry, theme, image cache config
  models/{photo, photo_section, aspect}.dart
  services/{thumb_resolver, photo_service}.dart
  controllers/gallery_controller.dart
  widgets/{tile_registry, photo_tile, section_header, photo_grid,
           photo_masonry, pinch_gesture_layer, pinch_overlay,
           top_bar, selection_bar, metrics}.dart
  pages/{gallery_page, photo_viewer_page}.dart
```

- `Photo` is an abstract model with `DevicePhoto` (photo_manager) and `FakePhoto` (picsum NetworkImage for testing without a media library). Toggle via `kUseFakePhotos` in `gallery_page.dart`.
- `GalleryController` (extends `ChangeNotifier`) owns mode, cols, selection, anchor, pinch state.
- `PinchGestureLayer` uses `RawGestureDetector` + `ScaleGestureRecognizer` so single-finger drag belongs to the scroll, two-finger pinch belongs to the column changer.
- `TileRegistryScope` lets the gallery look up rendered tiles by photo id for anchor preservation.

## Tests

```bash
flutter test
```

Unit and widget tests cover bucketize, safeRatio, ThumbResolver, GalleryController, PhotoTile rendering, TopBar interactions, and app boot.

## Manual QA Checklist

- Pinch in/out, grid and masonry → smooth col change 2↔7. Haptic per step.
- Photo near top of viewport stays anchored across col change.
- Long-press → multi-select → Cancel.
- Tap → viewer → swipe → close.
- Background app → reopen → state retained.
- Deny permission → guidance UI + Open Settings.

## Known Limitations (out of assignment scope)

- Share/Save/Delete actions are UI stubs only.
- No albums, search, edits, sync, or ML.
- No real share intent wiring.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README with arch, run, test, QA"
```

---

## Task 23: Final analyzer + test gate

**Files:** none

- [ ] **Step 1: Run analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 3: Build release APK**

Run: `flutter build apk --release`
Expected: Build succeeds; APK at `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 4: Tag release**

```bash
git tag v1.0.0-redesign
```

---

## Self-Review

**Spec coverage:** Each spec section mapped to tasks:
- Architecture (folders, controller, abstractions) → Tasks 3,4,7,8,9
- Data flow → Tasks 5,6,19
- Bug-fix table (4 bugs) → Tasks 10,12,13,14,19 (anchor)
- Pinch pseudocode → Task 14
- Anchor pseudocode → Tasks 8,19
- Photo viewer → Task 18
- Error/permission/empty → Task 19 (`_ErrorView`)
- Performance (ImageCache, thumb buckets, ResizeImage, RepaintBoundary) → Tasks 1,10,20
- Testing strategy → Tasks 1,2,5,7,10,16,20
- Acceptance criteria → Task 23 (analyzer + tests + release build)

**Placeholder scan:** No TBD/TODO/"implement later"/"similar to". Every code step shows actual code.

**Type consistency:** Method names cross-checked. `GalleryController.setCols/setMode/enterSelect/toggleSelect/exitSelect/selectAll/startPinch/endPinch/setMaxCols/setAnchor/clearAnchor` consistent between Task 7 definition and Task 19 usage. `Photo.thumb(int)/full()/id/width/height/isVideo/dateTaken` consistent. `PhotoSection.{key,label,sub,photos}` consistent. `Metrics` fields consistent between Task 9 and consumers.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-15-gallery-redesign.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch with checkpoints.

Which approach?

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
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
import '../widgets/selection_bar.dart';
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
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, double> _sectionOffsets = {};
  List<String> _passed = const [];
  String? _current;
  bool _showSticky = false;
  double _pinchAnchorFraction = 0;
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
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final vctx = _viewportKey.currentContext;
    final vbox = vctx?.findRenderObject();
    if (vbox is! RenderBox) return;
    final viewportTop = vbox.localToGlobal(Offset.zero).dy;
    final offset = _scrollController.offset;
    // Refresh cached absolute offsets for sections currently rendered.
    for (final entry in _sectionKeys.entries) {
      final ro = entry.value.currentContext?.findRenderObject();
      if (ro is! RenderBox || !ro.attached) continue;
      final headerTop = ro.localToGlobal(Offset.zero).dy;
      _sectionOffsets[entry.key] = offset + (headerTop - viewportTop);
    }
    // Current section = last section whose start offset <= scrollOffset.
    // Sticks until the next section's start passes the top.
    String? current;
    final passed = <String>[];
    for (final s in _sections) {
      final so = _sectionOffsets[s.key];
      if (so == null) continue;
      if (offset + 1 >= so) {
        if (current != null) passed.add(current);
        current = s.key;
      }
    }
    current ??= _sections.isNotEmpty ? _sections.first.key : null;
    // Only show sticky once current section's inline header has scrolled past,
    // so the inline + sticky never both display the same label at viewport top.
    bool showSticky = false;
    if (current != null) {
      final so = _sectionOffsets[current];
      final m = Metrics.of(context);
      final headerH = m.headerExtent;
      if (so != null && offset > so + headerH - 4) {
        showSticky = true;
      }
    }
    if (current != _current ||
        showSticky != _showSticky ||
        passed.length != _passed.length ||
        !_listEq(passed, _passed)) {
      setState(() {
        _current = current;
        _showSticky = showSticky;
        _passed = passed;
      });
    }
  }

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _scrollToSection(String key) {
    final ctx = _sectionKeys[key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final so = _sectionOffsets[key];
    if (so != null && _scrollController.hasClients) {
      _scrollController.animateTo(
        so.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onCtrl);
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
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
    _sectionKeys
      ..clear()
      ..addEntries(sections.map((s) => MapEntry(s.key, GlobalKey())));
    _sectionOffsets.clear();
    setState(() {
      _sections = sections;
      _flat = flat;
      _totalCount = items.length;
      _passed = const [];
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
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final max = pos.maxScrollExtent;
    _pinchAnchorFraction = max <= 0 ? 0 : (pos.pixels / max).clamp(0.0, 1.0);
  }

  void _restoreAnchor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final target =
          (_pinchAnchorFraction * pos.maxScrollExtent).clamp(0.0, pos.maxScrollExtent);
      _scrollController.jumpTo(target);
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

  List<Photo> _selectedPhotos() {
    final ids = _controller.selected;
    if (ids.isEmpty) return const [];
    return _flat.where((p) => ids.contains(p.id)).toList();
  }

  Future<void> _shareSelected() async {
    final picks = _selectedPhotos();
    if (picks.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = <XFile>[];
      final urls = <String>[];
      for (final p in picks) {
        if (p is DevicePhoto) {
          final f = await p.asset.file;
          if (f != null) files.add(XFile(f.path));
        } else if (p is FakePhoto) {
          urls.add('https://picsum.photos/id/${p.picsumId}/1200');
        }
      }
      if (files.isNotEmpty) {
        await Share.shareXFiles(files);
      } else if (urls.isNotEmpty) {
        await Share.share(urls.join('\n'));
      } else {
        messenger
            .showSnackBar(const SnackBar(content: Text('Nothing to share')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _deleteSelected() async {
    final picks = _selectedPhotos();
    if (picks.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Delete ${picks.length} photo${picks.length == 1 ? '' : 's'}?',
            style: const TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete the selected photos from your device.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ids =
        picks.whereType<DevicePhoto>().map((p) => p.asset.id).toList();
    if (ids.isNotEmpty) {
      try {
        final removed = await PhotoManager.editor.deleteWithIds(ids);
        if (removed.isEmpty) {
          messenger.showSnackBar(
              const SnackBar(content: Text('Delete cancelled')));
          return;
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        return;
      }
    }
    if (!mounted) return;
    _controller.exitSelect();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final m = Metrics.of(context);
    return PopScope(
      canPop: !_controller.selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_controller.selectMode) _controller.exitSelect();
      },
      child: Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        bottom: false,
        child: _error != null
            ? _ErrorView(message: _error!, onRetry: _bootstrap)
            : _buildGallery(m),
      ),
    ),
    );
  }

  Widget _buildGallery(Metrics m) {
    final viewportW = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final desiredMaxCols = _maxColsForWidth(viewportW);
    if (_controller.maxCols != desiredMaxCols) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.setMaxCols(desiredMaxCols);
      });
    }
    final innerW = viewportW - 2 * m.gap;
    final tileW =
        ((innerW - m.gap * (_controller.cols - 1)) / _controller.cols)
            .clamp(1.0, double.infinity);
    // Decode thumbnails at a column-count-independent reference width so a
    // pinch (which changes tileW) does NOT change the image provider key.
    // Same key -> ImageCache hit -> tiles just rescale, no reload/black flash.
    final refW = innerW / 4;
    final thumbPx = ThumbResolver.bucket(refW * dpr);
    final globalStart = <String, int>{};
    var running = 0;
    for (final s in _sections) {
      globalStart[s.key] = running;
      running += s.photos.length;
    }

    return Stack(
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
                    : _controller.enterSelect(null),
                onCancelSelect: _controller.exitSelect,
                onSelectAll: () =>
                    _controller.selectAll(_flat.map((p) => p.id)),
                pinchActive: _controller.pinchActive,
                pinchCols: _controller.cols,
                accent: kAccent,
              ),
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: kAccent,
                  backgroundColor: Color(0xFF1A1A1A),
                ),
              if (!_controller.selectMode && _passed.isNotEmpty)
                _PassedBar(
                  passed: _passed,
                  labelFor: (k) => _sections
                      .firstWhere((s) => s.key == k)
                      .label,
                  metrics: m,
                  onTap: _scrollToSection,
                ),
              if (!_controller.selectMode && _current != null)
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    opacity: _showSticky ? 1.0 : 0.0,
                    child: _showSticky
                        ? _StickyHeader(
                            section: _sections
                                .firstWhere((s) => s.key == _current),
                            metrics: m,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              Expanded(
                child: KeyedSubtree(
                  key: _viewportKey,
                  child: PinchGestureLayer(
                    controller: _controller,
                    onCaptureAnchor: _captureAnchor,
                    onRestoreAnchor: _restoreAnchor,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_controller.cols),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      builder: (ctx, t, child) {
                        final scale = 0.96 + 0.04 * t;
                        final op = (0.55 + 0.45 * t).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: op,
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: _controller.pinchActive
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        slivers: _buildSlivers(m, tileW, thumbPx, globalStart),
                      ),
                    ),
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
                count: _controller.selected.length,
                metrics: m,
                onShare: _shareSelected,
                onDelete: _deleteSelected,
              ),
            ),
        ],
      );
  }

  List<Widget> _buildSlivers(
      Metrics m, double tileW, int thumbPx, Map<String, int> globalStart) {
    final slivers = <Widget>[];
    for (final s in _sections) {
      // Visible inline section header. Keyed for scroll-offset measurement.
      // The sticky overlay above the scroll mirrors the current section while
      // these inline headers separate sections within the scroll content.
      slivers.add(SliverToBoxAdapter(
        child: KeyedSubtree(
          key: _sectionKeys[s.key],
          child: _InlineSectionHeader(section: s, metrics: m),
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

class _StickyHeader extends StatelessWidget {
  final PhotoSection section;
  final Metrics metrics;
  const _StickyHeader({required this.section, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Container(
      color: kBg,
      width: double.infinity,
      height: m.headerExtent,
      padding: EdgeInsets.fromLTRB(
          m.headerHGutter, m.headerPadTop, m.headerHGutter, m.headerPadBottom),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.bottomLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, anim) => ClipRect(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.6),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
        ),
        child: FittedBox(
          key: ValueKey(section.key),
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomLeft,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(section.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: m.labelFs,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                )),
            SizedBox(height: 2 * m.scale),
            Text('${section.sub} · ${section.photos.length} photos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: m.subFs,
                  letterSpacing: 0.1,
                )),
          ],
        ),
        ),
      ),
    );
  }
}

class _PassedBar extends StatelessWidget {
  final List<String> passed;
  final String Function(String key) labelFor;
  final Metrics metrics;
  final ValueChanged<String> onTap;
  const _PassedBar({
    required this.passed,
    required this.labelFor,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Container(
      height: 36 * m.scale,
      color: kBg,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: EdgeInsets.symmetric(horizontal: m.topBarPadH),
        itemCount: passed.length,
        separatorBuilder: (_, __) => SizedBox(width: 6 * m.scale),
        itemBuilder: (ctx, i) {
          final key = passed[passed.length - 1 - i];
          return GestureDetector(
            onTap: () => onTap(key),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 12 * m.scale),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labelFor(key),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12 * m.scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InlineSectionHeader extends StatelessWidget {
  final PhotoSection section;
  final Metrics metrics;
  const _InlineSectionHeader({required this.section, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          m.headerHGutter, m.headerPadTop, m.headerHGutter, m.headerPadBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(section.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: m.labelFs,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              )),
          SizedBox(height: 2 * m.scale),
          Text('${section.sub} · ${section.photos.length} photos',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: m.subFs,
                letterSpacing: 0.1,
              )),
        ],
      ),
    );
  }
}

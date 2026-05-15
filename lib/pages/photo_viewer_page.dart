import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import '../models/photo.dart';
import '../services/ai_edit_service.dart';

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
  late List<Photo> _photos;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _photos = List<Photo>.from(widget.photos);
    _index = widget.initialIndex.clamp(0, _photos.length - 1);
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

  Future<void> _share() async {
    final p = _photos[_index];
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (p is DevicePhoto) {
        final file = await p.asset.file;
        if (file == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Cannot read file')));
          return;
        }
        await Share.shareXFiles([XFile(file.path)]);
      } else if (p is FakePhoto) {
        await Share.share(
            'https://picsum.photos/id/${p.picsumId}/1200/${(1200 / (p.width / p.height)).round()}');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _aiEdit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!AiEditService.isConfigured) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          'AI edit needs GEMINI_API_KEY. '
          'Run: flutter run --dart-define=GEMINI_API_KEY=<key>',
        ),
      ));
      return;
    }
    final prompt = await _askPrompt();
    if (prompt == null || prompt.trim().isEmpty) return;
    if (!mounted) return;
    final p = _photos[_index];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(),
    );
    AiEditException? aiErr;
    Object? otherErr;
    Uint8List? edited;
    try {
      final src = await p.bytesForEdit();
      if (src == null) {
        throw const AiEditException(
          title: 'Cannot read photo',
          body: 'photo_manager returned no bytes for this asset.',
        );
      }
      edited = await AiEditService.edit(
        imageBytes: src.bytes,
        mimeType: src.mimeType,
        prompt: prompt.trim(),
      );
    } on AiEditException catch (e) {
      aiErr = e;
    } catch (e) {
      otherErr = e;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (edited == null) {
      if (aiErr != null) {
        await _showErrorDialog(aiErr.title, aiErr.body);
      } else {
        await _showErrorDialog('Edit failed', otherErr?.toString() ?? 'Unknown');
      }
      return;
    }
    await _showEditPreview(edited);
  }

  Future<void> _showErrorDialog(String title, String body) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.5,
            maxWidth: 520,
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              body,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamilyFallback: ['monospace'],
                height: 1.35,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$title\n\n$body'));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Copied error to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7DDCC9),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPrompt() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Edit with AI',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. make it sunset, add snow, remove background',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7DDCC9),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditPreview(Uint8List bytes) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(child: Image.memory(bytes)),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundBtn(
                        icon: Icons.close,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7DDCC9),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _saveEdited(bytes);
                        },
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveEdited(Uint8List bytes) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PhotoManager.editor.saveImage(
        bytes,
        filename: 'ai_edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      messenger.showSnackBar(const SnackBar(content: Text('Saved to gallery')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _delete() async {
    final p = _photos[_index];
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete photo?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete the photo from your device.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (p is DevicePhoto) {
      try {
        final removed =
            await PhotoManager.editor.deleteWithIds([p.asset.id]);
        if (removed.isEmpty) {
          messenger.showSnackBar(const SnackBar(content: Text('Delete cancelled')));
          return;
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _photos.removeAt(_index);
      if (_photos.isEmpty) {
        nav.pop();
        return;
      }
      if (_index >= _photos.length) _index = _photos.length - 1;
    });
    if (_photos.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(_index);
    }
  }

  void _showInfo() {
    final p = _photos[_index];
    final d = p.dateTaken;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final s = _scale(ctx);
        Widget row(String k, String v) => Padding(
              padding: EdgeInsets.symmetric(vertical: 6 * s),
              child: Row(
                children: [
                  SizedBox(
                    width: 90 * s,
                    child: Text(k,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13 * s,
                        )),
                  ),
                  Expanded(
                    child: Text(v,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13 * s,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                ],
              ),
            );
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20 * s, 14 * s, 20 * s, 14 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 14 * s),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17 * s,
                      fontWeight: FontWeight.w600,
                    )),
                SizedBox(height: 10 * s),
                row('Date', _TopChrome._formatDate(d)),
                row('Time', _TopChrome._formatTime(d)),
                row('Size', '${p.width} × ${p.height}'),
                row('Type', p.isVideo ? 'Video' : 'Image'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) return const SizedBox.shrink();
    final p = _photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: _photos.length,
              onPageChanged: _onPageChanged,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              builder: (ctx, i) {
                final ph = _photos[i];
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
                child: _TopChrome(
                  photo: p,
                  index: _index,
                  total: _photos.length,
                  onInfo: _showInfo,
                ),
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
                    photos: _photos,
                    index: _index,
                    accent: widget.accent,
                    stripController: _stripController,
                    onTapStrip: _goTo,
                    onShare: _share,
                    onAiEdit: _aiEdit,
                    onDelete: _delete,
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
  final VoidCallback onInfo;
  const _TopChrome({
    required this.photo,
    required this.index,
    required this.total,
    required this.onInfo,
  });

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
          _RoundBtn(icon: Icons.info_outline, onTap: onInfo),
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
  final VoidCallback onShare;
  final VoidCallback onAiEdit;
  final VoidCallback onDelete;
  const _BottomChrome({
    required this.photos,
    required this.index,
    required this.accent,
    required this.stripController,
    required this.onTapStrip,
    required this.onShare,
    required this.onAiEdit,
    required this.onDelete,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionBtn(icon: Icons.ios_share, label: 'Share', onTap: onShare),
              _ActionBtn(
                  icon: Icons.auto_awesome, label: 'AI Edit', onTap: onAiEdit),
              _ActionBtn(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onTap: onDelete,
                  destructive: true),
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
  final VoidCallback onTap;
  final bool destructive;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final color =
        destructive ? const Color(0xFFFF6B6B) : Colors.white.withValues(alpha: 0.92);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 6 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20 * s),
            SizedBox(height: 4 * s),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 10 * s,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                )),
          ],
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: Color(0xFF7DDCC9)),
            ),
            SizedBox(width: 18),
            Text('Editing with AI…',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

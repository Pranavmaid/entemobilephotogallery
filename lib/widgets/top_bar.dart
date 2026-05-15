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
              style: TextButton.styleFrom(
                  foregroundColor: accent, padding: EdgeInsets.zero),
              onPressed: onCancelSelect,
              child: Text('Cancel',
                  style: TextStyle(
                      fontSize: 15 * m.scale, fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  selectedCount == 0
                      ? 'Select Items'
                      : '$selectedCount selected',
                  style: TextStyle(
                      fontSize: 13 * m.scale,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: accent, padding: EdgeInsets.zero),
              onPressed: onSelectAll,
              child: Text(
                selectedCount == totalCount && totalCount > 0 ? 'Deselect' : 'All',
                style: TextStyle(
                    fontSize: 15 * m.scale, fontWeight: FontWeight.w500),
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
          SizedBox(height: 40,),
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
                  pinchActive ? '$pinchCols columns' : '$totalCount images',
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
  const _ModeToggle(
      {required this.mode, required this.onChange, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    Widget cell(GalleryMode mm, IconData icon) {
      final active = mode == mm;
      return GestureDetector(
        onTap: () => onChange(mm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              EdgeInsets.symmetric(horizontal: m.modePadH, vertical: m.modePadV),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1F1F1F) : Colors.transparent,
            borderRadius: BorderRadius.circular(m.modeRadius),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 3,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Icon(icon,
              size: m.modeIconSize,
              color:
                  active ? Colors.white : Colors.white.withValues(alpha: 0.55)),
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

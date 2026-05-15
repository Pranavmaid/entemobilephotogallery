import 'package:flutter/material.dart';
import '../models/photo.dart';

class PhotoTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tileMin = width < height ? width : height;
    final badgeSize = (tileMin * 0.22).clamp(14.0, 26.0);
    final badgeIcon = badgeSize * 0.62;
    final badgeInset = (tileMin * 0.06).clamp(4.0, 10.0);
    final videoIcon = (tileMin * 0.18).clamp(12.0, 22.0);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF161616)),
                Hero(
                  tag: 'photo_${photo.id}',
                  flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
                    return toCtx.widget;
                  },
                  child: _Thumb(
                    photo: photo,
                    thumbPx: thumbPx,
                    fit: fit,
                    selected: selected,
                  ),
                ),
                if (selectMode)
                  IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: selected
                          ? accent.withValues(alpha: 0.13)
                          : Colors.transparent,
                    ),
                  ),
                if (selectMode)
                  Positioned(
                    top: badgeInset,
                    right: badgeInset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent
                            : Colors.black.withValues(alpha: 0.32),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? accent
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
                      child: selected
                          ? Icon(Icons.check,
                              size: badgeIcon,
                              color: const Color(0xFF0A0A0A))
                          : null,
                    ),
                  ),
                if (photo.isVideo)
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

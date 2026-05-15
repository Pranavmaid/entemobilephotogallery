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
          if (key is! ValueKey<String>) return null;
          final id = key.value;
          final idx = photos.indexWhere((p) => p.id == id);
          return idx < 0 ? null : idx;
        },
      ),
    );
  }
}

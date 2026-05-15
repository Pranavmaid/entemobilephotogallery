import 'package:flutter/material.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
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
    return SliverWaterfallFlow(
      gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
      ),
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final p = photos[i];
          final ratio = safeRatio(p.width, p.height);
          return tileBuilder(ctx, p, i, tileW, tileW / ratio);
        },
        childCount: photos.length,
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

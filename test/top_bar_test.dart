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

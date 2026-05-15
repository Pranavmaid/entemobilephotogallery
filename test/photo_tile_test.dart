import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/models/photo.dart';
import 'package:entemobilephotogallery/widgets/photo_tile.dart';

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
  @override
  Future<PhotoBytes?> bytesForEdit() async => null;
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
      home: Scaffold(
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
    ));
    await tester.pump();
    expect(find.byType(PhotoTile), findsOneWidget);
  });

  testWidgets('shows selection badge when selectMode + selected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
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
    ));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

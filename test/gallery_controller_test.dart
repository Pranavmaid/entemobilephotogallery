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

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

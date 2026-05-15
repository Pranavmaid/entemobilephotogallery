import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/services/thumb_resolver.dart';

void main() {
  group('ThumbResolver.bucket', () {
    test('picks smallest bucket >= displayPx', () {
      expect(ThumbResolver.bucket(50), 96);
      expect(ThumbResolver.bucket(96), 96);
      expect(ThumbResolver.bucket(97), 144);
      expect(ThumbResolver.bucket(199), 200);
      expect(ThumbResolver.bucket(280), 280);
      expect(ThumbResolver.bucket(281), 400);
      expect(ThumbResolver.bucket(560), 560);
    });
    test('clamps to max bucket past largest', () {
      expect(ThumbResolver.bucket(900), 560);
      expect(ThumbResolver.bucket(99999), 560);
    });
    test('non-positive input returns smallest bucket', () {
      expect(ThumbResolver.bucket(0), 96);
      expect(ThumbResolver.bucket(-5), 96);
    });
  });
}

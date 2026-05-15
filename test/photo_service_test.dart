import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entemobilephotogallery/models/photo.dart';
import 'package:entemobilephotogallery/services/photo_service.dart';

class _StubPhoto implements Photo {
  @override
  final String id;
  @override
  final DateTime dateTaken;
  _StubPhoto(this.id, this.dateTaken);
  @override
  int get width => 100;
  @override
  int get height => 100;
  @override
  bool get isVideo => false;
  @override
  ImageProvider thumb(int sidePx) => throw UnimplementedError();
  @override
  ImageProvider full() => throw UnimplementedError();
  @override
  Future<PhotoBytes?> bytesForEdit() async => null;
}

void main() {
  group('PhotoService.bucketize', () {
    test('groups today, yesterday, this week, this month, older months', () {
      final now = DateTime(2026, 5, 15, 12, 0);
      final today    = _StubPhoto('a', DateTime(2026, 5, 15, 10));
      final yest     = _StubPhoto('b', DateTime(2026, 5, 14, 10));
      final thisWeek = _StubPhoto('c', DateTime(2026, 5, 13, 10));
      final thisMonth= _StubPhoto('d', DateTime(2026, 5, 3, 10));
      final older    = _StubPhoto('e', DateTime(2026, 3, 1, 10));
      final sections = PhotoService.bucketizeAt(
        [today, yest, thisWeek, thisMonth, older],
        now,
      );
      final keys = sections.map((s) => s.key).toList();
      expect(keys, containsAll(['today', 'yesterday', 'week', 'month']));
      expect(keys.last, '2026-03');
      final today2 = sections.firstWhere((s) => s.key == 'today');
      expect(today2.photos.length, 1);
      expect(today2.photos.first.id, 'a');
    });

    test('skips empty buckets', () {
      final now = DateTime(2026, 5, 15);
      final older = _StubPhoto('e', DateTime(2026, 3, 1, 10));
      final sections = PhotoService.bucketizeAt([older], now);
      expect(sections.length, 1);
      expect(sections.first.key, '2026-03');
    });
  });
}

class ThumbResolver {
  static const List<int> buckets = [96, 144, 200, 280, 400, 560];

  static int bucket(double displayPx) {
    if (displayPx <= 0) return buckets.first;
    for (final b in buckets) {
      if (b >= displayPx) return b;
    }
    return buckets.last;
  }
}

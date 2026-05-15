const double minAspect = 0.45;
const double maxAspect = 2.4;

double safeRatio(int width, int height) {
  if (width <= 0 || height <= 0) return 1.0;
  final r = width / height;
  if (!r.isFinite || r <= 0) return 1.0;
  return r.clamp(minAspect, maxAspect);
}

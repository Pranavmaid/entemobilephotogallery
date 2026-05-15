import 'photo.dart';

class PhotoSection {
  final String key;
  final String label;
  final String sub;
  final List<Photo> photos;
  const PhotoSection({
    required this.key,
    required this.label,
    required this.sub,
    required this.photos,
  });
}

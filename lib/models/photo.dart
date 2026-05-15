import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class PhotoBytes {
  final Uint8List bytes;
  final String mimeType;
  const PhotoBytes(this.bytes, this.mimeType);
}

abstract class Photo {
  String get id;
  int get width;
  int get height;
  bool get isVideo;
  DateTime get dateTaken;
  ImageProvider thumb(int sidePx);
  ImageProvider full();
  Future<PhotoBytes?> bytesForEdit();
}

class DevicePhoto implements Photo {
  final AssetEntity asset;
  DevicePhoto(this.asset);
  @override
  String get id => asset.id;
  @override
  int get width => asset.width;
  @override
  int get height => asset.height;
  @override
  bool get isVideo => asset.type == AssetType.video;
  @override
  DateTime get dateTaken => asset.createDateTime;
  @override
  ImageProvider thumb(int sidePx) => AssetEntityImageProvider(
        asset,
        isOriginal: false,
        thumbnailSize: ThumbnailSize.square(sidePx),
      );
  @override
  ImageProvider full() => AssetEntityImageProvider(asset, isOriginal: true);
  @override
  Future<PhotoBytes?> bytesForEdit() async {
    // Downscaled thumbnail (max 1024 on the long edge) keeps the AI request
    // small enough to stay under per-call token limits while preserving
    // enough detail for an edit. Returns JPEG bytes.
    final bytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(1024, 1024),
      quality: 92,
    );
    if (bytes == null) return null;
    return PhotoBytes(bytes, 'image/jpeg');
  }
}

class FakePhoto implements Photo {
  @override
  final String id;
  @override
  final int width;
  @override
  final int height;
  @override
  final DateTime dateTaken;
  final int picsumId;
  FakePhoto({
    required this.id,
    required this.width,
    required this.height,
    required this.dateTaken,
    required this.picsumId,
  });
  @override
  bool get isVideo => false;
  double get _ratio => width / height;
  @override
  ImageProvider thumb(int sidePx) {
    final h = (sidePx / _ratio).round().clamp(1, 4000);
    return NetworkImage('https://picsum.photos/id/$picsumId/$sidePx/$h');
  }

  @override
  ImageProvider full() {
    const target = 1200;
    final h = (target / _ratio).round().clamp(1, 4000);
    return NetworkImage('https://picsum.photos/id/$picsumId/$target/$h');
  }

  @override
  Future<PhotoBytes?> bytesForEdit() async {
    const target = 1200;
    final h = (target / _ratio).round().clamp(1, 4000);
    final url = Uri.parse('https://picsum.photos/id/$picsumId/$target/$h');
    final res = await http.get(url);
    if (res.statusCode != 200) return null;
    return PhotoBytes(res.bodyBytes, 'image/jpeg');
  }
}

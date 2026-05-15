import 'package:flutter/foundation.dart';

enum GalleryMode { grid, masonry }

class AnchorState {
  final String photoId;
  final double offset;
  const AnchorState({required this.photoId, required this.offset});
}

class GalleryController extends ChangeNotifier {
  static const int absoluteMinCols = 2;
  static const int absoluteMaxCols = 9;

  int _cols = 3;
  int get cols => _cols;

  GalleryMode _mode = GalleryMode.masonry;
  GalleryMode get mode => _mode;

  int _maxCols = 7;
  int get maxCols => _maxCols;

  bool _selectMode = false;
  bool get selectMode => _selectMode;

  final Set<String> _selected = <String>{};
  Set<String> get selected => _selected;

  bool _pinchActive = false;
  bool get pinchActive => _pinchActive;
  int _startCols = 3;
  int get startCols => _startCols;

  AnchorState? _anchor;
  AnchorState? get anchor => _anchor;

  void setCols(int next) {
    final clamped = next.clamp(absoluteMinCols, _maxCols);
    if (clamped == _cols) return;
    _cols = clamped;
    notifyListeners();
  }

  void setMode(GalleryMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
  }

  void setMaxCols(int m) {
    final mm = m.clamp(absoluteMinCols, absoluteMaxCols);
    if (mm == _maxCols) return;
    _maxCols = mm;
    if (_cols > mm) _cols = mm;
    notifyListeners();
  }

  void startPinch() {
    _pinchActive = true;
    _startCols = _cols;
    notifyListeners();
  }

  void endPinch() {
    if (!_pinchActive) return;
    _pinchActive = false;
    notifyListeners();
  }

  void enterSelect(String? firstId) {
    _selectMode = true;
    _selected.clear();
    if (firstId != null && firstId.isNotEmpty) _selected.add(firstId);
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void exitSelect() {
    if (!_selectMode && _selected.isEmpty) return;
    _selectMode = false;
    _selected.clear();
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    final all = ids.toSet();
    if (_selected.length == all.length) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(all);
    }
    notifyListeners();
  }

  void setAnchor(AnchorState a) {
    _anchor = a;
  }

  void clearAnchor() {
    _anchor = null;
  }
}

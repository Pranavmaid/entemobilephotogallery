import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/gallery_controller.dart';

class PinchGestureLayer extends StatefulWidget {
  final GalleryController controller;
  final VoidCallback onCaptureAnchor;
  final VoidCallback onRestoreAnchor;
  final Widget child;
  const PinchGestureLayer({
    super.key,
    required this.controller,
    required this.onCaptureAnchor,
    required this.onRestoreAnchor,
    required this.child,
  });

  @override
  State<PinchGestureLayer> createState() => _PinchGestureLayerState();
}

class _PinchGestureLayerState extends State<PinchGestureLayer> {
  bool _twoFinger = false;
  double _scaleBase = 1.0;

  void _onStart(ScaleStartDetails d) {
    _twoFinger = false;
    _scaleBase = 1.0;
  }

  void _onUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) {
      if (_twoFinger) {
        _twoFinger = false;
        widget.controller.endPinch();
      }
      return;
    }
    if (!_twoFinger) {
      _twoFinger = true;
      _scaleBase = d.scale == 0 ? 1.0 : d.scale;
      widget.onCaptureAnchor();
      widget.controller.startPinch();
      return;
    }
    final rel = d.scale / _scaleBase;
    if (rel <= 0) return;
    final start = widget.controller.startCols;
    final next = (start / rel).round();
    final prev = widget.controller.cols;
    widget.controller.setCols(next);
    if (widget.controller.cols != prev) {
      HapticFeedback.selectionClick();
      widget.onRestoreAnchor();
    }
  }

  void _onEnd(ScaleEndDetails d) {
    _twoFinger = false;
    widget.controller.endPinch();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
          () => ScaleGestureRecognizer(),
          (instance) {
            instance.onStart = _onStart;
            instance.onUpdate = _onUpdate;
            instance.onEnd = _onEnd;
          },
        ),
      },
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';
import 'metrics.dart';

class PinchOverlay extends StatelessWidget {
  final int cols;
  final Metrics metrics;
  const PinchOverlay({super.key, required this.cols, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: m.indicatorPadH, vertical: m.indicatorPadV),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded,
                color: Colors.white70, size: m.indicatorIconSize),
            SizedBox(width: m.indicatorGap),
            Text('$cols',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: m.indicatorBigFs,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                )),
            SizedBox(width: 6 * m.scale),
            Text('COLS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: m.indicatorSmallFs,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }
}

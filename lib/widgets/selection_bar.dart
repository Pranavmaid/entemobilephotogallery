import 'package:flutter/material.dart';
import 'metrics.dart';

class SelectionBar extends StatelessWidget {
  final int count;
  final Metrics metrics;
  const SelectionBar({super.key, required this.count, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    Widget btn(IconData icon, String label) {
      final enabled = count > 0;
      return Padding(
        padding: EdgeInsets.symmetric(
            horizontal: m.selBarBtnPadH, vertical: 4 * m.scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: m.selBarIconSize,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3)),
            SizedBox(height: 4 * m.scale),
            Text(label,
                style: TextStyle(
                  fontSize: m.selBarLabelFs,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                )),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          m.selBarPadH,
          m.selBarPadTop,
          m.selBarPadH,
          MediaQuery.of(context).padding.bottom + 8 * m.scale),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xF70A0A0A), Color(0x000A0A0A)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          btn(Icons.ios_share, 'Share'),
          btn(Icons.download_outlined, 'Save'),
          btn(Icons.delete_outline, 'Delete'),
        ],
      ),
    );
  }
}

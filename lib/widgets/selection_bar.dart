import 'package:flutter/material.dart';
import 'metrics.dart';

class SelectionBar extends StatelessWidget {
  final int count;
  final Metrics metrics;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  const SelectionBar({
    super.key,
    required this.count,
    required this.metrics,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    Widget btn({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool destructive = false,
    }) {
      final enabled = count > 0;
      final color = !enabled
          ? Colors.white.withValues(alpha: 0.3)
          : (destructive ? const Color(0xFFFF6B6B) : Colors.white);
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: m.selBarBtnPadH + 6, vertical: 4 * m.scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: m.selBarIconSize, color: color),
              SizedBox(height: 4 * m.scale),
              Text(label,
                  style: TextStyle(
                    fontSize: m.selBarLabelFs,
                    fontWeight: FontWeight.w500,
                    color: color,
                  )),
            ],
          ),
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
          btn(icon: Icons.ios_share, label: 'Share', onTap: onShare),
          btn(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: onDelete,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

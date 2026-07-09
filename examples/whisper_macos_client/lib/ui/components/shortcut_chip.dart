import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ShortcutChip extends StatelessWidget {
  const ShortcutChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.textMuted,
    this.iconSize = 11,
    this.fontSize = 11,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;
  final double fontSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hp = compact ? 8.0 : 10.0;
    final vp = compact ? 4.0 : 5.0;
    final gap = compact ? 4.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: gap),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

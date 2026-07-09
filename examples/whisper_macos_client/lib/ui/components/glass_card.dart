import 'package:flutter/material.dart';

import '../../core/theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.children,
    this.padding,
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: padding != null
            ? [Padding(padding: padding!, child: Column(children: children))]
            : children,
      ),
    );
  }
}

class GlassSection extends StatelessWidget {
  const GlassSection({
    super.key,
    required this.title,
    required this.children,
    this.spacing = 16,
  });

  final String title;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          children: children
              .expand((w) => [w, SizedBox(height: spacing)])
              .take(children.length * 2 - 1)
              .toList(),
        ),
      ],
    );
  }
}

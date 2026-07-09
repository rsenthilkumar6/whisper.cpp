import 'package:flutter/material.dart';

import '../../core/theme.dart';

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius = 12,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
    this.isLoading = false,
    this.loadingSize = 16,
    this.expanded = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? foregroundColor;
  final bool isLoading;
  final double loadingSize;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final bg = backgroundColor ?? (isDisabled ? AppColors.surfaceAlt : AppColors.accent);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: expanded ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ??
                  (isDisabled ? AppColors.border : AppColors.accent.withValues(alpha: 0.3)),
              width: 1,
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: loadingSize,
                  height: loadingSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      foregroundColor ?? Colors.white,
                    ),
                  ),
                )
              : DefaultTextStyle.merge(
                  style: TextStyle(
                    color: foregroundColor ??
                        (isDisabled ? AppColors.textMuted : Colors.white),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderRadius = 12,
    this.tooltip,
    this.isActive = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderRadius;
  final String? tooltip;
  final bool isActive;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final effectiveActiveColor = activeColor ?? AppColors.accent;
    final effectiveBg = isActive && isEnabled
        ? effectiveActiveColor.withValues(alpha: 0.15)
        : backgroundColor ?? AppColors.surfaceAlt;
    final effectiveFg = isActive && isEnabled
        ? effectiveActiveColor
        : foregroundColor ?? (isEnabled ? AppColors.textPrimary : AppColors.textMuted);
    final effectiveBorder = isActive && isEnabled
        ? effectiveActiveColor.withValues(alpha: 0.3)
        : borderColor ?? AppColors.border;

    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: isEnabled ? onPressed : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: effectiveBorder, width: 1),
          ),
          child: Icon(icon, size: iconSize, color: effectiveFg),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.expanded = false,
    this.backgroundColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final bool expanded;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      onPressed: isLoading ? null : onPressed,
      isLoading: isLoading,
      backgroundColor: backgroundColor ??
          (isPrimary ? AppColors.accent : AppColors.surfaceAlt),
      foregroundColor: isPrimary ? Colors.white : AppColors.textPrimary,
      borderColor: isPrimary ? null : AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      expanded: expanded,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

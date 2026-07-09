import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class IdleWaveform extends StatefulWidget {
  const IdleWaveform({
    super.key,
    this.barCount = 12,
    this.maxHeight = 28,
    this.color = AppColors.textMuted,
    this.active = false,
  });

  final int barCount;
  final double maxHeight;
  final Color color;
  final bool active;

  @override
  State<IdleWaveform> createState() => _IdleWaveformState();
}

class _IdleWaveformState extends State<IdleWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant IdleWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxHeight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.barCount, (i) {
                final phase = i * 0.5;
                // Compute wave value
                double wave;
                if (widget.active) {
                  final sinVal = math.sin(t + i * 0.5);
                  final cosVal = math.cos(t * 0.4 + i * 0.5 * 0.6);
                  wave = 0.15 + 0.85 * (0.5 + 0.5 * math.sin(t + i * 0.5) * cosVal);
                } else {
                  wave = 0.08;
                }
                final h = (widget.maxHeight * wave).clamp(3.0, widget.maxHeight);
                final fraction = i / (widget.barCount - 1);
                final color = Color.lerp(
                  widget.color.withValues(alpha: 0.3),
                  widget.color.withValues(alpha: 0.6),
                  fraction,
                )!;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          color.withValues(alpha: 0.3),
                          color,
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

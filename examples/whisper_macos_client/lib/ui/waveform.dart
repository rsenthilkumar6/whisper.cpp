import 'dart:math' as math;

import 'package:flutter/material.dart';

class EqualizerWaveform extends StatefulWidget {
  const EqualizerWaveform({
    super.key,
    required this.active,
    required this.color,
    this.bars = 9,
    this.maxHeight = 28,
  });

  final bool active;
  final Color color;
  final int bars;
  final double maxHeight;

  @override
  State<EqualizerWaveform> createState() => _EqualizerWaveformState();
}

class _EqualizerWaveformState extends State<EqualizerWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerWaveform oldWidget) {
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
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.bars, (i) {
              final phase = i * 0.6;
              final wave = widget.active
                  ? 0.15 +
                      0.85 *
                          (0.5 +
                              0.5 *
                                  math.sin(t + phase) *
                                  math.cos(t * 0.4 + phase * 0.6))
                  : 0.06;
              final h = (widget.maxHeight * wave).clamp(4.0, widget.maxHeight);

              final fraction = i / (widget.bars - 1);
              final color = Color.lerp(
                widget.color.withValues(alpha: 0.6),
                widget.color,
                fraction,
              )!;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Container(
                  width: 3.5,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        color.withValues(alpha: 0.4),
                        color,
                      ],
                    ),
                    boxShadow: widget.active
                        ? [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.3),
                              blurRadius: 6,
                              spreadRadius: -1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

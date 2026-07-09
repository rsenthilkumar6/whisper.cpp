import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Real-time audio level visualization using RMS values from the audio stream.
/// Expects a stream of RMS values (0.0 to 1.0) from the audio capture.
class AudioWaveform extends StatefulWidget {
  const AudioWaveform({
    super.key,
    required this.levelStream,
    this.barCount = 16,
    this.maxHeight = 40,
    this.activeColor = AppColors.accent,
    this.inactiveColor = AppColors.glassBorder,
    this.barWidth = 3,
    this.spacing = 3,
    this.smoothing = 0.15,
    this.minLevel = 0.02,
  });

  final Stream<double> levelStream;
  final int barCount;
  final double maxHeight;
  final Color activeColor;
  final Color inactiveColor;
  final double barWidth;
  final double spacing;
  final double smoothing;
  final double minLevel;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _barLevels = [];
  StreamSubscription<double>? _subscription;

  @override
  void initState() {
    super.initState();
    _barLevels.addAll(List.filled(widget.barCount, widget.minLevel));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
      lowerBound: 0,
      upperBound: 1,
    )..repeat();
    _subscription = widget.levelStream.listen(_onLevel);
    _controller.addListener(_animateBars);
  }

  @override
  void dispose() {
    _controller.removeListener(_animateBars);
    _controller.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _onLevel(double rms) {
    if (!mounted) return;
    final baseLevel = (rms * 1.5).clamp(0.0, 1.0);
    for (int i = 0; i < widget.barCount; i++) {
      final variance = 0.3 + 0.7 * math.sin(
        DateTime.now().millisecondsSinceEpoch * 0.01 + i * 0.8);
      final target = (baseLevel * variance).clamp(0.0, 1.0);
      _barLevels[i] = _lerp(_barLevels[i], target, widget.smoothing);
      _barLevels[i] = _barLevels[i].clamp(widget.minLevel, 1.0);
    }
  }

  void _animateBars() {
    if (!mounted) return;
    bool anyAboveMin = false;
    for (int i = 0; i < widget.barCount; i++) {
      if (_barLevels[i] > widget.minLevel) {
        _barLevels[i] = (_barLevels[i] * 0.92).clamp(widget.minLevel, 1.0);
        if (_barLevels[i] > widget.minLevel) anyAboveMin = true;
      }
    }
    if (anyAboveMin || _controller.isAnimating) {
      setState(() {});
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxHeight,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (i) {
            final level = _barLevels[i];
            final h = (widget.maxHeight * level).clamp(2.0, widget.maxHeight);
            final fraction = i / (widget.barCount - 1);
            final color = Color.lerp(
              widget.activeColor.withValues(alpha: 0.5),
              widget.activeColor,
              fraction,
            )!;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 40),
                curve: Curves.easeOut,
                width: widget.barWidth,
                height: h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.barWidth / 2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color.withValues(alpha: 0.3),
                      color,
                    ],
                  ),
                  boxShadow: level > widget.minLevel * 2
                      ? [
                          BoxShadow(
                            color: widget.activeColor.withValues(alpha: 0.3 * level),
                            blurRadius: 6,
                            spreadRadius: -1,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

}

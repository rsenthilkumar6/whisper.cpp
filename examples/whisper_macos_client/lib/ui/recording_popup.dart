import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/recording_cubit.dart';
import '../state/recording_state.dart';
import 'waveform.dart';

class RecordingPopup extends StatelessWidget {
  const RecordingPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingCubit, RecordingState>(
      builder: (context, state) {
        final visible = state.status != RecordingStatus.idle;
        return Container(
          color: Colors.transparent,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.88, end: 1.0)
                        .animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    )),
                    child: child,
                  ),
                );
              },
              child: visible
                  ? _PopupCard(state: state, key: const ValueKey('card'))
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),
        );
      },
    );
  }
}

class _PopupCard extends StatefulWidget {
  const _PopupCard({required this.state, super.key});

  final RecordingState state;

  @override
  State<_PopupCard> createState() => _PopupCardState();
}

class _PopupCardState extends State<_PopupCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isError = state.hasError;
    final isConnecting = state.status == RecordingStatus.connecting;
    final isRecording = state.status == RecordingStatus.recording;
    final isFinalizing = state.status == RecordingStatus.finalizing;

    final accent = isError
        ? AppColors.red
        : isConnecting
            ? AppColors.yellow
            : AppColors.accent;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final pulse = (isRecording || isConnecting) ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: pulse,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                width: AppConstants.popupWidth - 32,
                height: AppConstants.popupHeight - 32,
                decoration: BoxDecoration(
                  color: isError
                      ? AppColors.red.withValues(alpha: 0.08)
                      : AppColors.glassFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isError
                        ? AppColors.red.withValues(alpha: 0.35)
                        : isConnecting
                            ? AppColors.yellow.withValues(alpha: 0.25)
                            : AppColors.glassBorder,
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.glassShadow,
                      blurRadius: 60,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [
                              AppColors.glassHighlight,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusBar(
                            accent: accent,
                            state: state,
                            isError: isError,
                            isRecording: isRecording,
                            isConnecting: isConnecting,
                            isFinalizing: isFinalizing,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _TranscriptArea(
                              transcript: isError
                                  ? state.message
                                  : state.transcript,
                              isEmpty: state.transcript.isEmpty &&
                                  (isRecording || isConnecting),
                              isError: isError,
                            ),
                          ),
                          if (isRecording || isConnecting) ...[
                            const SizedBox(height: 10),
                            EqualizerWaveform(
                              active: isRecording,
                              color: accent,
                              bars: 9,
                              maxHeight: 28,
                            ),
                          ],
                          if (isFinalizing && state.transcript.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _FinalizingBar(accent: accent),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.accent,
    required this.state,
    required this.isError,
    required this.isRecording,
    required this.isConnecting,
    required this.isFinalizing,
  });

  final Color accent;
  final RecordingState state;
  final bool isError;
  final bool isRecording;
  final bool isConnecting;
  final bool isFinalizing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusPill(
          accent: accent,
          isError: isError,
          isConnecting: isConnecting,
          isRecording: isRecording,
          isFinalizing: isFinalizing,
          label: state.message.isEmpty ? 'Whisper Bar' : state.message,
        ),
        const Spacer(),
        if (state.status != RecordingStatus.error)
          _ActionButton(
            accent: accent,
            isRecording: isRecording || isConnecting,
            onPressed: () => context.read<RecordingCubit>().stop(),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.accent,
    required this.isError,
    required this.isConnecting,
    required this.isRecording,
    required this.isFinalizing,
    required this.label,
  });

  final Color accent;
  final bool isError;
  final bool isConnecting;
  final bool isRecording;
  final bool isFinalizing;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isError)
            const Icon(Icons.error_outline_rounded,
                size: 14, color: AppColors.red)
          else if (isConnecting)
            _ConnectingSpinner(color: accent)
          else if (isFinalizing)
            Icon(Icons.check_circle_outline_rounded,
                size: 14, color: AppColors.green)
          else
            _PulseDot(color: accent, active: isRecording),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isError
                  ? AppColors.red
                  : isConnecting
                      ? AppColors.yellow
                      : accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ConnectingSpinner extends StatefulWidget {
  const _ConnectingSpinner({required this.color});
  final Color color;

  @override
  State<_ConnectingSpinner> createState() => _ConnectingSpinnerState();
}

class _ConnectingSpinnerState extends State<_ConnectingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: Icon(Icons.sync_rounded,
              size: 14, color: widget.color.withValues(alpha: 0.8)),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.3;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale = _controller.value;
        final opacity = 0.4 + (0.6 * _controller.value);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: opacity),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * scale),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TranscriptArea extends StatelessWidget {
  const _TranscriptArea({
    required this.transcript,
    required this.isEmpty,
    required this.isError,
  });

  final String transcript;
  final bool isEmpty;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Text(
            transcript,
            style: const TextStyle(
              color: AppColors.red,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_rounded,
            size: 28,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Listening… start speaking',
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Text(
          transcript,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.accent,
    required this.isRecording,
    required this.onPressed,
  });

  final Color accent;
  final bool isRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isRecording ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            isRecording ? Icons.stop_rounded : Icons.check_circle_rounded,
            color: isRecording ? accent : AppColors.green,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _FinalizingBar extends StatelessWidget {
  const _FinalizingBar({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0),
                accent,
                accent.withValues(alpha: 0),
              ],
              stops: [0.0, value.clamp(0.3, 0.7), 1.0],
            ),
          ),
        );
      },
    );
  }
}

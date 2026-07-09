import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../state/recording_cubit.dart';
import '../../state/recording_state.dart';
import 'components/shortcut_chip.dart';
import 'realtime_waveform.dart';

class RecordingPopup extends StatelessWidget {
  const RecordingPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingCubit, RecordingState>(
      builder: (context, state) {
        final visible = state.status != RecordingStatus.idle;
        return AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: visible
              ? Center(
                  child: _PopupCard(state: state, key: const ValueKey('card')),
                )
              : null,
        );
      },
    );
  }
}

class _PopupCard extends StatelessWidget {
  const _PopupCard({required this.state, super.key});

  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final isError = state.hasError;
    final isConnecting = state.status == RecordingStatus.connecting;
    final isRecording = state.status == RecordingStatus.recording;
    final isFinalizing = state.status == RecordingStatus.finalizing;

    final accent = isError
        ? AppColors.red
        : isConnecting
            ? AppColors.yellow
            : AppColors.accent;

    return Container(
      width: AppConstants.popupWidth - 32,
      height: AppConstants.popupHeight - 32,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isError
              ? AppColors.red.withValues(alpha: 0.4)
              : isConnecting
                  ? AppColors.yellow.withValues(alpha: 0.3)
                  : AppColors.border,
          width: 1,
        ),
      ),
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
              transcript: isError ? state.message : state.transcript,
              isEmpty: state.transcript.isEmpty && (isRecording || isConnecting),
              isError: isError,
            ),
          ),
          if (isRecording || isConnecting) ...[
            const SizedBox(height: 10),
            RealtimeWaveform(
              bars: 16,
              maxHeight: 36,
              color: accent,
            ),
          ],
          if (isRecording || isConnecting) ...[
            const SizedBox(height: 10),
            _ShortcutBar(),
          ],
        ],
      ),
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
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.yellow),
              ),
            )
          else if (isFinalizing)
            const Icon(Icons.check_circle_outline_rounded,
                size: 14, color: AppColors.green)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
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
        child: SelectableText(
          transcript,
          style: const TextStyle(
            color: AppColors.red,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (isEmpty) {
      return const Center(
        child: Text(
          'Listening… start speaking',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: SelectableText(
        transcript,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ShortcutBar extends StatelessWidget {
  const _ShortcutBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ShortcutChip(
          icon: Icons.stop_rounded,
          label: 'F1 Stop',
          color: AppColors.red,
        ),
        const SizedBox(width: 8),
        const ShortcutChip(
          icon: Icons.settings_rounded,
          label: 'F2 Settings',
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        const ShortcutChip(
          icon: Icons.close_rounded,
          label: 'Esc Cancel',
          color: AppColors.textMuted,
        ),
      ],
    );
  }
}

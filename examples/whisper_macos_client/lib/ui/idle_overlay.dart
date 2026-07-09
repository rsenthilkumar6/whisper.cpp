import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di.dart';
import '../../core/theme.dart';
import '../../services/hotkey_service.dart';
import '../../services/settings_repository.dart';
import '../../state/recording_cubit.dart';
import '../../state/recording_state.dart';
import 'components/glass_button.dart';
import 'components/shortcut_chip.dart';
import 'settings_sheet.dart';

class IdleOverlay extends StatelessWidget {
  const IdleOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingCubit, RecordingState>(
      builder: (context, state) {
        final isIdle = state.status == RecordingStatus.idle;
        return Opacity(
          opacity: isIdle ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isIdle,
            child: Center(
              child: GestureDetector(
                onTap: () => context.read<RecordingCubit>().toggle(),
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.keyboard_voice_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text.rich(
                          TextSpan(
                            text: 'whisper',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                            children: [
                              TextSpan(
                                text: '.cpp',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w300,
                                  color: AppColors.accent.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Voice Dictation',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ShortcutChip(
                          icon: Icons.keyboard,
                          label: 'F1  Toggle Recording',
                          color: AppColors.accent,
                          iconSize: 14,
                          fontSize: 12.5,
                        ),
                        const SizedBox(height: 8),
                        ShortcutChip(
                          icon: Icons.settings_rounded,
                          label: 'F2  Settings',
                          color: AppColors.textMuted,
                          iconSize: 14,
                          fontSize: 12.5,
                        ),
                        const SizedBox(height: 8),
                        ShortcutChip(
                          icon: Icons.exit_to_app_rounded,
                          label: '⌘Q  Quit',
                          color: AppColors.textMuted,
                          iconSize: 14,
                          fontSize: 12.5,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Click anywhere or press F1 to start',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SettingsButton(
                          label: 'Start Dictation (F1)',
                          icon: Icons.mic_rounded,
                          onPressed: () => context.read<RecordingCubit>().toggle(),
                          expanded: true,
                        ),
                        const SizedBox(height: 8),
                        SettingsButton(
                          label: 'Settings (F2)',
                          icon: Icons.settings_rounded,
                          onPressed: () {
                            SettingsSheet.show(
                              context: context,
                              repository: locator<SettingsRepository>(),
                              onSaved: (c) => locator<HotkeyService>().register(c),
                            );
                          },
                          expanded: true,
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

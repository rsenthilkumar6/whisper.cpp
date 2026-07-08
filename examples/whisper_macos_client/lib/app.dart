import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di.dart';
import 'core/theme.dart';
import 'domain/server_config.dart';
import 'services/hotkey_service.dart';
import 'services/settings_repository.dart';
import 'state/recording_cubit.dart';
import 'state/recording_state.dart';
import 'ui/recording_popup.dart';
import 'ui/settings_sheet.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatelessWidget {
  const App({super.key, required this.recordingCubit});

  final RecordingCubit recordingCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RecordingCubit>.value(
      value: recordingCubit,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const _AppShell(),
        routes: {
          '/settings': (_) => SettingsSheet(
                repository: locator<SettingsRepository>(),
                onSaved: (ServerConfig config) =>
                    locator<HotkeyService>().register(config),
              ),
        },
      ),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordingCubit, RecordingState>(
      builder: (context, state) {
        final isIdle = state.status == RecordingStatus.idle;
        return Stack(
          children: [
            if (isIdle) const _IdleBackground(),
            if (isIdle) const _IdleOverlay(),
            const RecordingPopup(),
          ],
        );
      },
    );
  }
}

class _IdleBackground extends StatelessWidget {
  const _IdleBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.3, -0.3),
          radius: 1.8,
          colors: [
            Color(0xFF1A1A30),
            Color(0xFF0D0D14),
            Color(0xFF07070A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _IdleOverlay extends StatelessWidget {
  const _IdleOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            width: 380,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            decoration: BoxDecoration(
              color: AppColors.glassFill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.glassShadow,
                  blurRadius: 60,
                  offset: Offset(0, 24),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentDim],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGlow,
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
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
                _ShortcutChip(
                  icon: Icons.keyboard,
                  label: 'F1  Toggle Recording',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 8),
                _ShortcutChip(
                  icon: Icons.settings_rounded,
                  label: 'F2  Settings',
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 8),
                _ShortcutChip(
                  icon: Icons.exit_to_app_rounded,
                  label: '⌘Q  Quit',
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 24),
                Text(
                  'Press F1 to start dictation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

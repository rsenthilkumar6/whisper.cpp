import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di.dart';
import 'core/theme.dart';
import 'services/hotkey_service.dart';
import 'services/settings_repository.dart';
import 'services/window_service.dart';
import 'state/recording_cubit.dart';
import 'state/recording_state.dart';
import 'ui/idle_overlay.dart';
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
            if (isIdle) const IdleOverlay(),
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

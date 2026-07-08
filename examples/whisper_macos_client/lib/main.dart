import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di.dart';
import 'services/hotkey_service.dart';
import 'services/settings_repository.dart';
import 'services/tray_service.dart';
import 'services/window_service.dart';
import 'state/recording_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();

  // Build the coordinator and supporting services once.
  final cubit = RecordingCubit(
    audio: locator(),
    inserter: locator(),
    window: locator(),
    tray: locator(),
    settings: locator(),
  );

  final hotkey = HotkeyService(onToggle: cubit.toggle);
  locator.registerSingleton<HotkeyService>(hotkey);

  final window = locator<WindowService>();
  final tray = locator<TrayService>();
  final settings = locator<SettingsRepository>();

  runApp(App(recordingCubit: cubit));

  // Platform channels are fully wired once the engine is running.
  final config = await settings.load();
  await hotkey.register(config);
  await tray.init(
    onToggle: cubit.toggle,
    onShow: () => window.showIdle(),
    onSettings: () {
      window.showSettings();
      navigatorKey.currentState?.pushNamed('/settings');
    },
    onQuit: () {
      window.hide();
      unawaited(hotkey.dispose());
      exit(0);
    },
  );

  // Hide the window at launch — the app lives in the menu bar.
  window.hide();
}

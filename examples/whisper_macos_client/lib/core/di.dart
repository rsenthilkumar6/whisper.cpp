import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/audio_capture.dart';
import '../services/settings_repository.dart';
import '../services/text_inserter.dart';
import '../services/tray_service.dart';
import '../services/window_service.dart';

/// Service locator. Keeping construction in one place makes the dependency
/// graph explicit and keeps widgets/services free of manual wiring.
final GetIt locator = GetIt.instance;

Future<void> setupDependencies() async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: {'whisper_bar.config.v1'},
    ),
  );

  locator
    ..registerSingleton<SettingsRepository>(SettingsRepository(prefs))
    ..registerSingleton<AudioCapture>(AudioCapture())
    ..registerSingleton<TextInserter>(const TextInserter())
    ..registerSingleton<WindowService>(WindowService())
    ..registerSingleton<TrayService>(TrayService());
}

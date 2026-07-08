import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/server_config.dart';

/// Persists [ServerConfig] across launches using `shared_preferences`.
///
/// Acts as the single source of truth for user settings; UI and services
/// read through this repository rather than touching `SharedPreferences`
/// directly, which keeps the storage key isolated and easy to evolve.
class SettingsRepository {
  static const String _key = 'whisper_bar.config.v1';

  final SharedPreferencesWithCache _prefs;

  SettingsRepository(this._prefs);

  /// Load the saved config, falling back to [ServerConfig] defaults.
  Future<ServerConfig> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return const ServerConfig();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ServerConfig.fromJson(json);
    } catch (_) {
      return const ServerConfig();
    }
  }

  /// Persist the given config.
  Future<void> save(ServerConfig config) async {
    await _prefs.setString(_key, jsonEncode(config.toJson()));
  }
}

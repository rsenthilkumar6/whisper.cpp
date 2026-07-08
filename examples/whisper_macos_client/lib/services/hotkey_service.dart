import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:hotkey_manager/hotkey_manager.dart';

import '../domain/server_config.dart';

/// A user-selectable global hotkey preset.
///
/// Keeps the `hotkey_manager` types out of the domain layer; [ServerConfig]
/// only stores the preset [id] string.
class HotkeyPreset {
  const HotkeyPreset(this.id, this.label, this.build);

  final String id;
  final String label;
  final HotKey Function() build;

  static const String defaultId = ServerConfig.defaultHotkeyId;

  static const List<HotkeyPreset> all = [
    HotkeyPreset('f9', 'F9', _f9),
    HotkeyPreset('f10', 'F10', _f10),
    HotkeyPreset('f11', 'F11', _f11),
    HotkeyPreset('cmdShiftSpace', '⌘ + Shift + Space', _cmdShiftSpace),
    HotkeyPreset('cmdShiftD', '⌘ + Shift + D', _cmdShiftD),
  ];

  static HotkeyPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);

  // Explicit empty modifier list (not null) — `hotkey_manager_macos` force-casts
  // `modifiers` to an array, and a null value crashes the app at launch.
  static HotKey _f9() => HotKey(
        key: LogicalKeyboardKey.f9,
        modifiers: const [],
        scope: HotKeyScope.system,
      );
  static HotKey _f10() => HotKey(
        key: LogicalKeyboardKey.f10,
        modifiers: const [],
        scope: HotKeyScope.system,
      );
  static HotKey _f11() => HotKey(
        key: LogicalKeyboardKey.f11,
        modifiers: const [],
        scope: HotKeyScope.system,
      );
  static HotKey _cmdShiftSpace() => HotKey(
        key: LogicalKeyboardKey.space,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
  static HotKey _cmdShiftD() => HotKey(
        key: LogicalKeyboardKey.keyD,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
}

/// Registers a single global hotkey that toggles recording.
class HotkeyService {
  HotkeyService({required this.onToggle});

  final void Function() onToggle;

  /// Register (or re-register) the hotkey described by [config].
  ///
  /// Re-registering is cheap and keeps the live hotkey in sync with settings.
  Future<void> register(ServerConfig config) async {
    await hotKeyManager.unregisterAll();
    final preset = HotkeyPreset.byId(config.hotkeyPresetId);
    await hotKeyManager.register(
      preset.build(),
      keyDownHandler: (_) => onToggle(),
    );
  }

  Future<void> dispose() => hotKeyManager.unregisterAll();
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:system_tray/system_tray.dart';

/// Menu-bar (system tray) integration.
///
/// Provides the status-bar icon, a context menu, and switches the icon between
/// an idle and a recording state so the user gets at-a-glance feedback.
class TrayService {
  final SystemTray _tray = SystemTray();
  final Menu _menu = Menu();

  String? _idleIconPath;
  String? _recordingIconPath;

  Future<void> init({
    required void Function() onToggle,
    required void Function() onShow,
    required void Function() onSettings,
    required void Function() onQuit,
  }) async {
    _idleIconPath = await _extractAsset('assets/tray_icon.png');
    _recordingIconPath = await _extractAsset('assets/tray_icon_recording.png');

    await _tray.initSystemTray(
      iconPath: _idleIconPath ?? '',
      toolTip: 'Whisper Bar',
    );

    await _menu.buildFrom([
      MenuItemLabel(
        label: 'Show Whisper Bar',
        onClicked: (_) => onShow(),
      ),
      MenuItemLabel(
        label: 'Start / Stop Recording',
        onClicked: (_) => onToggle(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Settings…',
        onClicked: (_) => onSettings(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Quit Whisper Bar',
        onClicked: (_) => onQuit(),
      ),
    ]);
    await _tray.setContextMenu(_menu);

    // Left-click on the tray icon toggles recording.
    _tray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) onToggle();
    });
  }

  /// Swap the icon to reflect [recording].
  Future<void> setRecording(bool recording) async {
    final path = recording ? _recordingIconPath : _idleIconPath;
    if (path != null) await _tray.setImage(path);
  }

  /// Copy a bundled asset to a temp file so the native tray API can load it.
  Future<String?> _extractAsset(String asset) async {
    try {
      final ByteData data = await rootBundle.load(asset);
      final Uint8List bytes = data.buffer.asUint8List();
      final dir = await Directory.systemTemp.createTemp('whisper_bar_icons');
      final file = File('${dir.path}/${asset.split('/').last}');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

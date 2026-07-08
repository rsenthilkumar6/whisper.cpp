import 'package:flutter/services.dart';

import '../core/constants.dart';

/// Bridges to the native floating-window controller (see
/// `macos/Runner/MainFlutterWindow.swift`).
///
/// The same NSWindow hosts both the recording overlay and the settings sheet;
/// `activate` controls whether the window takes focus. For the recording
/// overlay it must stay `false` so dictation is typed into the previously
/// focused app rather than into our own UI.
class WindowService {
  static const MethodChannel _channel =
      MethodChannel(AppConstants.windowChannelName);

  /// Show the non-activating recording overlay.
  Future<void> showPopup() => _channel.invokeMethod<void>('show', {
        'activate': false,
        'width': AppConstants.popupWidth,
        'height': AppConstants.popupHeight,
      });

  /// Show the idle welcome screen with activation focus.
  Future<void> showIdle() => _channel.invokeMethod<void>('show', {
        'activate': true,
        'width': AppConstants.popupWidth,
        'height': 480.0,
      });

  /// Show an activatable window (used for the settings sheet).
  Future<void> showSettings() => _channel.invokeMethod<void>('show', {
        'activate': true,
        'width': 520.0,
        'height': 480.0,
      });

  /// Hide the window entirely.
  Future<void> hide() => _channel.invokeMethod<void>('hide');
}

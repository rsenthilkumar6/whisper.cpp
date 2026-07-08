import 'package:equatable/equatable.dart';

/// Connection + behaviour settings for the dictation client.
///
/// Plain, immutable data object. Persistence is handled by
/// [SettingsRepository]; this class only knows how to (de)serialize itself.
class ServerConfig extends Equatable {
  /// Default hotkey preset id. Kept here (not in [HotkeyPreset]) to avoid a
  /// circular import between the domain and services layers.
  static const String defaultHotkeyId = 'f9';

  const ServerConfig({
    this.host = 'm5max.local',
    this.port = 9002,
    this.language = 'en',
    this.translate = false,
    this.hotkeyPresetId = defaultHotkeyId,
  });

  final String host;
  final int port;
  final String language;
  final bool translate;

  /// Identifier of a [HotkeyPreset] (see [HotkeyService]).
  final String hotkeyPresetId;

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    final host = json['host'];
    final port = json['port'];
    final language = json['language'];
    final translate = json['translate'];
    final hotkey = json['hotkeyPresetId'];
    return ServerConfig(
      host: host is String && host.isNotEmpty ? host : 'm5max.local',
      port: port is int ? port : 9002,
      language: language is String && language.isNotEmpty ? language : 'en',
      translate: translate is bool ? translate : false,
      hotkeyPresetId: hotkey is String && hotkey.isNotEmpty
          ? hotkey
          : defaultHotkeyId,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'language': language,
        'translate': translate,
        'hotkeyPresetId': hotkeyPresetId,
      };

  ServerConfig copyWith({
    String? host,
    int? port,
    String? language,
    bool? translate,
    String? hotkeyPresetId,
  }) {
    return ServerConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      language: language ?? this.language,
      translate: translate ?? this.translate,
      hotkeyPresetId: hotkeyPresetId ?? this.hotkeyPresetId,
    );
  }

  /// WebSocket endpoint, e.g. `ws://m5max.local:9002`.
  ///
  /// Normalizes the host so a user who pastes `http://host` or `host:9002`
  /// into the host field still yields a valid `ws://host:port` URI.
  String get wsUrl {
    final cleanHost = host.contains('://') ? host.split('://').last : host;
    final hostOnly = cleanHost.contains(':')
        ? cleanHost.substring(0, cleanHost.indexOf(':'))
        : cleanHost;
    return 'ws://$hostOnly:$port';
  }

  @override
  List<Object?> get props =>
      [host, port, language, translate, hotkeyPresetId];
}

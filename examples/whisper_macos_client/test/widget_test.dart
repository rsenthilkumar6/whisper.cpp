import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_macos_client/domain/server_config.dart';

void main() {
  group('ServerConfig', () {
    test('round-trips through JSON', () {
      const config = ServerConfig(
        host: '192.168.1.10',
        port: 9002,
        language: 'fr',
        translate: true,
        hotkeyPresetId: 'cmdShiftSpace',
      );

      final decoded = ServerConfig.fromJson(
        // ignore: avoid_type_for_parameter_inference
        Map<String, dynamic>.from(config.toJson()),
      );

      expect(decoded.host, '192.168.1.10');
      expect(decoded.port, 9002);
      expect(decoded.language, 'fr');
      expect(decoded.translate, isTrue);
      expect(decoded.hotkeyPresetId, 'cmdShiftSpace');
    });

    test('falls back to defaults for unknown values', () {
      final decoded = ServerConfig.fromJson(<String, dynamic>{
        'translate': 'not-a-bool',
      });
      expect(decoded.translate, isFalse);
      expect(decoded.host, 'm5max.local');
    });

    test('builds the websocket url', () {
      const config = ServerConfig(host: 'localhost', port: 1234);
      expect(config.wsUrl, 'ws://localhost:1234');
    });
  });
}

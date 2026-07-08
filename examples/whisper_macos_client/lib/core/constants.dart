class AppConstants {
  const AppConstants._();

  static const int sampleRate = 16000;
  static const int numChannels = 1;

  static const String defaultHost = 'm5max.local';
  static const int defaultPort = 9002;
  static const String defaultLanguage = 'en';

  static const String windowChannelName = 'com.whisperbar/window';

  static const double popupWidth = 500.0;
  static const double popupHeight = 200.0;

  static const Duration finalDisplayDelay = Duration(milliseconds: 1200);
  static const Duration errorDisplayDelay = Duration(seconds: 5);
}

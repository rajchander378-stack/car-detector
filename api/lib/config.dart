import 'dart:io';

class Config {
  static String get geminiApiKey =>
      Platform.environment['GEMINI_API_KEY'] ?? '';

  static String get ukvdApiKey =>
      Platform.environment['UKVD_API_KEY'] ?? '';

  static String get rapidApiProxySecret =>
      Platform.environment['RAPIDAPI_PROXY_SECRET'] ?? '';

  static int get port =>
      int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  static bool get authEnabled => rapidApiProxySecret.isNotEmpty;
}

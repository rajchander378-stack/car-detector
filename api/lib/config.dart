import 'dart:io';

class Config {
  static String get geminiApiKey =>
      Platform.environment['GEMINI_API_KEY'] ?? '';

  static String get ukvdApiKey =>
      Platform.environment['UKVD_API_KEY'] ?? '';

  static String get apiSecret =>
      Platform.environment['API_SECRET'] ?? '';

  static int get port =>
      int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  static bool get authEnabled => apiSecret.isNotEmpty;
}

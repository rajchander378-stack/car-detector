import 'dart:io';

class Config {
  static String get geminiApiKey =>
      Platform.environment['GEMINI_API_KEY'] ?? '';

  static String get ukvdApiKey =>
      Platform.environment['UKVD_API_KEY'] ?? '';

  static String get apiSecret =>
      Platform.environment['API_SECRET'] ?? '';

  static String get stripeSecretKey =>
      Platform.environment['STRIPE_SECRET_KEY'] ?? '';

  static String get stripeWebhookSecret =>
      Platform.environment['STRIPE_WEBHOOK_SECRET'] ?? '';

  static String get baseUrl =>
      Platform.environment['BASE_URL'] ?? 'https://car-detector-833e5.web.app';

  static int get port =>
      int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  static bool get authEnabled => apiSecret.isNotEmpty;

  static bool get stripeEnabled => stripeSecretKey.isNotEmpty;
}

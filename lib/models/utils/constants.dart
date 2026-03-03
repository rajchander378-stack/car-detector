class Constants {
  // No Gemini API key needed - Firebase handles it

  // UK Vehicle Data API (add your key when you sign up)
  static const String ukVehicleDataApiKey = 'YOUR_UKVD_KEY_HERE';
  static const String ukVehicleDataUrl =
      'https://uk1.ukvehicledata.co.uk/api/datapacket';

  // Thresholds
  static const double minDetectionConfidence = 0.5;
  static const double minGeminiConfidence = 0.6;
  static const int maxImageWidth = 1024;
}
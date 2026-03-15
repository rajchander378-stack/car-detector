class Constants {
  // No Gemini API key needed - Firebase handles it

  // Vehicle Data Global API
  static const String vdglApiKey = 'D5D22850-71A0-4523-8DBA-7CE4B5361B3D';
  static const String vdglBaseUrl = 'https://uk.api.vehicledataglobal.com';
  static const String vdglPackageName = 'DataPackage2';

  // Thresholds
  static const double minDetectionConfidence = 0.5;
  static const double minGeminiConfidence = 0.6;
  static const int maxImageWidth = 1024;
}
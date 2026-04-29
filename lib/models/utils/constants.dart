class Constants {
  // No Gemini API key needed - Firebase handles it

  // VDGL package name passed to the Firebase callable function
  static const String vdglPackageName = 'DataPackage2';

  // Thresholds
  static const double minDetectionConfidence = 0.5;
  static const double minGeminiConfidence = 0.6;
  static const int maxImageWidth = 1024;
}
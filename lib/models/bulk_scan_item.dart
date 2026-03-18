import 'car_identification.dart';

enum BulkScanStatus { pending, optimising, identifying, completed, failed }

class BulkScanItem {
  final String imagePath;
  BulkScanStatus status;
  CarIdentification? identification;
  String? error;
  bool saved;

  /// Manually entered plate when Gemini didn't detect one.
  String? manualNumberPlate;

  BulkScanItem({
    required this.imagePath,
    this.status = BulkScanStatus.pending,
    this.identification,
    this.error,
    this.saved = false,
  });

  bool get isIdentified =>
      status == BulkScanStatus.completed &&
      identification != null &&
      identification!.identified;

  /// The effective plate: manual entry takes precedence over AI-detected.
  String? get effectivePlate =>
      (manualNumberPlate != null && manualNumberPlate!.isNotEmpty)
          ? manualNumberPlate
          : identification?.numberPlate;

  /// Whether this item has a usable number plate for pricing.
  bool get hasPlate =>
      isIdentified && effectivePlate != null && effectivePlate!.isNotEmpty;

  /// Clean and normalise a UK number plate string.
  static String cleanPlate(String plate) =>
      plate.replaceAll(RegExp(r'\s+'), '').toUpperCase();
}

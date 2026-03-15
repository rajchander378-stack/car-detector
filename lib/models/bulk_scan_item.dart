import 'car_identification.dart';

enum BulkScanStatus { pending, optimising, identifying, completed, failed }

class BulkScanItem {
  final String imagePath;
  BulkScanStatus status;
  CarIdentification? identification;
  String? error;
  bool saved;

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
}

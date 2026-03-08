import 'package:cloud_firestore/cloud_firestore.dart';
import 'car_identification.dart';
import 'vehicle_valuation.dart';

class SavedScan {
  final String id;
  final CarIdentification identification;
  final VehicleValuation? valuation;
  final DateTime savedAt;
  final bool isFavourite;

  /// Scans with valuation data expire after this many days.
  /// After expiry the valuation prices should be considered stale.
  /// This default is subject to independent GDPR/data-retention review.
  static const int retentionDays = 90;

  SavedScan({
    required this.id,
    required this.identification,
    this.valuation,
    required this.savedAt,
    this.isFavourite = false,
  });

  bool get isExpired =>
      DateTime.now().difference(savedAt).inDays > retentionDays;

  factory SavedScan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return SavedScan(
      id: doc.id,
      identification: CarIdentification.fromJson(
        Map<String, dynamic>.from(data['identification'] as Map),
      ),
      valuation: data['valuation'] != null
          ? VehicleValuation.fromStoredJson(
              Map<String, dynamic>.from(data['valuation'] as Map),
            )
          : null,
      savedAt: (data['saved_at'] as Timestamp).toDate(),
      isFavourite: data['is_favourite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'identification': identification.toJson(),
      if (valuation != null) 'valuation': valuation!.toJson(),
      'saved_at': Timestamp.fromDate(savedAt),
      'is_favourite': isFavourite,
    };
  }
}

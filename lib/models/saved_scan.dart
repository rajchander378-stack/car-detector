import 'package:cloud_firestore/cloud_firestore.dart';
import 'car_identification.dart';
import 'model_details.dart';
import 'mot_history.dart';
import 'tyre_details.dart';
import 'vehicle_details.dart';
import 'vehicle_valuation.dart';

class SavedScan {
  final String id;
  final CarIdentification identification;
  final VehicleValuation? valuation;
  final VehicleDetailsData? vehicleDetails;
  final ModelDetailsData? modelDetails;
  final MotHistory? motHistory;
  final TyreDetailsData? tyreDetails;
  final DateTime savedAt;
  final bool isFavourite;
  final int reportVersion;
  final String? source; // 'vdgl', 'gemini_estimate', or null (legacy)

  /// Scans with valuation data expire after this many days.
  /// After expiry the valuation prices should be considered stale.
  /// This default is subject to independent GDPR/data-retention review.
  static const int retentionDays = 90;

  SavedScan({
    required this.id,
    required this.identification,
    this.valuation,
    this.vehicleDetails,
    this.modelDetails,
    this.motHistory,
    this.tyreDetails,
    required this.savedAt,
    this.isFavourite = false,
    this.reportVersion = 1,
    this.source,
  });

  bool get isExpired =>
      DateTime.now().difference(savedAt).inDays > retentionDays;

  bool get hasFullReport => reportVersion >= 2;

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
      vehicleDetails: data['vehicle_details'] != null
          ? VehicleDetailsData.fromStoredJson(
              Map<String, dynamic>.from(data['vehicle_details'] as Map),
            )
          : null,
      modelDetails: data['model_details'] != null
          ? ModelDetailsData.fromStoredJson(
              Map<String, dynamic>.from(data['model_details'] as Map),
            )
          : null,
      motHistory: data['mot_history'] != null
          ? MotHistory.fromStoredJson(
              Map<String, dynamic>.from(data['mot_history'] as Map),
            )
          : null,
      tyreDetails: data['tyre_details'] != null
          ? TyreDetailsData.fromStoredJson(
              Map<String, dynamic>.from(data['tyre_details'] as Map),
            )
          : null,
      savedAt: (data['saved_at'] as Timestamp).toDate(),
      isFavourite: data['is_favourite'] as bool? ?? false,
      reportVersion: data['report_version'] as int? ?? 1,
      source: data['source'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'identification': identification.toJson(),
      if (valuation != null) 'valuation': valuation!.toJson(),
      if (vehicleDetails != null) 'vehicle_details': vehicleDetails!.toJson(),
      if (modelDetails != null) 'model_details': modelDetails!.toJson(),
      if (motHistory != null) 'mot_history': motHistory!.toJson(),
      if (tyreDetails != null) 'tyre_details': tyreDetails!.toJson(),
      'saved_at': Timestamp.fromDate(savedAt),
      'is_favourite': isFavourite,
      'report_version': reportVersion,
      if (source != null) 'source': source,
    };
  }
}

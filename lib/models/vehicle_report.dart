import 'model_details.dart';
import 'mot_history.dart';
import 'tyre_details.dart';
import 'vehicle_details.dart';
import 'vehicle_valuation.dart';

/// Aggregates all data sections returned from a DataPackage2 API call.
class VehicleReport {
  final VehicleDetailsData? vehicleDetails;
  final ModelDetailsData? modelDetails;
  final MotHistory? motHistory;
  final VehicleValuation? valuation;
  final TyreDetailsData? tyreDetails;

  VehicleReport({
    this.vehicleDetails,
    this.modelDetails,
    this.motHistory,
    this.valuation,
    this.tyreDetails,
  });

  factory VehicleReport.fromApiJson(Map<String, dynamic> json) {
    final results = json['Results'] as Map<String, dynamic>? ?? {};

    return VehicleReport(
      vehicleDetails: results['VehicleDetails'] != null
          ? VehicleDetailsData.fromApiJson(results['VehicleDetails'] as Map<String, dynamic>)
          : null,
      modelDetails: results['ModelDetails'] != null
          ? ModelDetailsData.fromApiJson(results['ModelDetails'] as Map<String, dynamic>)
          : null,
      motHistory: results['MotHistoryDetails'] != null
          ? MotHistory.fromApiJson(results['MotHistoryDetails'] as Map<String, dynamic>)
          : null,
      valuation: results['ValuationDetails'] != null
          ? VehicleValuation.fromJson(json)
          : null,
      tyreDetails: results['TyreDetails'] != null
          ? TyreDetailsData.fromApiJson(results['TyreDetails'] as Map<String, dynamic>)
          : null,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'car_identification.dart';
import 'model_details.dart';
import 'mot_history.dart';
import 'tyre_details.dart';
import 'vehicle_details.dart';
import 'vehicle_valuation.dart';

/// A vehicle stored in the user's garage (Firestore: users/{uid}/garage/{docId}).
///
/// Garage documents use a slightly different schema to saved_scans — the
/// identification is a flat map and valuation fields use snake_case keys
/// written directly by the web app.
class GarageVehicle {
  final String id;
  final CarIdentification identification;
  final VehicleValuation? valuation;
  final VehicleDetailsData? vehicleDetails;
  final ModelDetailsData? modelDetails;
  final MotHistory? motHistory;
  final TyreDetailsData? tyreDetails;
  final DateTime addedAt;
  final DateTime? valuationUpdated;
  final DateTime? motUpdated;
  final String? source;

  GarageVehicle({
    required this.id,
    required this.identification,
    this.valuation,
    this.vehicleDetails,
    this.modelDetails,
    this.motHistory,
    this.tyreDetails,
    required this.addedAt,
    this.valuationUpdated,
    this.motUpdated,
    this.source,
  });

  String get displayName => identification.displayName;

  String? get plate => identification.numberPlate;

  /// How old the valuation data is, based on valuation_updated or added_at.
  Duration get valuationAge =>
      DateTime.now().difference(valuationUpdated ?? addedAt);

  factory GarageVehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;

    // --- identification ---
    final idMap = data['identification'] as Map<String, dynamic>? ?? {};
    final identification = CarIdentification.fromJson(idMap);

    // --- valuation ---
    // Garage docs store valuation as a flat map with snake_case keys
    // (dealer_forecourt, private_clean, etc.) — same format as
    // VehicleValuation.fromStoredJson.
    VehicleValuation? valuation;
    if (data['valuation'] != null) {
      valuation = VehicleValuation.fromStoredJson(
        Map<String, dynamic>.from(data['valuation'] as Map),
      );
    }

    // --- MOT ---
    // Web stores as 'mot' (not 'mot_history') in raw VDGL API format (PascalCase).
    // Cached/stored docs use snake_case with a 'tests' list.
    MotHistory? motHistory;
    final motRaw = data['mot'] ?? data['mot_history'];
    if (motRaw != null) {
      final motMap = Map<String, dynamic>.from(motRaw as Map);
      if (motMap.containsKey('MotTestDetailsList')) {
        motHistory = MotHistory.fromApiJson(motMap);
      } else {
        // Normalise the due-date key — older stored docs may use MotDueDate or mot_due
        if (motMap['MotDueDate'] != null && motMap['mot_due_date'] == null) {
          motMap['mot_due_date'] = motMap['MotDueDate'];
        }
        if (motMap['mot_due'] != null && motMap['mot_due_date'] == null) {
          motMap['mot_due_date'] = motMap['mot_due'];
        }
        motHistory = MotHistory.fromStoredJson(motMap);
      }
    }

    // --- extra data sections ---
    // The web app writes raw VDGL API format (PascalCase top-level keys).
    // Stored/cached docs use snake_case. Detect by the presence of the API key.
    VehicleDetailsData? vehicleDetails;
    if (data['vehicle_details'] != null) {
      final vdMap = Map<String, dynamic>.from(data['vehicle_details'] as Map);
      vehicleDetails = vdMap.containsKey('VehicleIdentification')
          ? VehicleDetailsData.fromApiJson(vdMap)
          : VehicleDetailsData.fromStoredJson(vdMap);
    }

    ModelDetailsData? modelDetails;
    if (data['model_details'] != null) {
      final mdMap = Map<String, dynamic>.from(data['model_details'] as Map);
      modelDetails = mdMap.containsKey('ModelIdentification')
          ? ModelDetailsData.fromApiJson(mdMap)
          : ModelDetailsData.fromStoredJson(mdMap);
    }

    TyreDetailsData? tyreDetails;
    if (data['tyre_details'] != null) {
      final tdMap = Map<String, dynamic>.from(data['tyre_details'] as Map);
      tyreDetails = tdMap.containsKey('TyreDetailsList')
          ? TyreDetailsData.fromApiJson(tdMap)
          : TyreDetailsData.fromStoredJson(tdMap);
    }

    // --- timestamps ---
    DateTime addedAt;
    if (data['added_at'] is Timestamp) {
      addedAt = (data['added_at'] as Timestamp).toDate();
    } else {
      addedAt = DateTime.now();
    }

    DateTime? valuationUpdated;
    if (data['valuation_updated'] is Timestamp) {
      valuationUpdated = (data['valuation_updated'] as Timestamp).toDate();
    }

    DateTime? motUpdated;
    if (data['mot_updated'] is Timestamp) {
      motUpdated = (data['mot_updated'] as Timestamp).toDate();
    }

    return GarageVehicle(
      id: doc.id,
      identification: identification,
      valuation: valuation,
      vehicleDetails: vehicleDetails,
      modelDetails: modelDetails,
      motHistory: motHistory,
      tyreDetails: tyreDetails,
      addedAt: addedAt,
      valuationUpdated: valuationUpdated,
      motUpdated: motUpdated,
      source: data['source'] as String?,
    );
  }
}

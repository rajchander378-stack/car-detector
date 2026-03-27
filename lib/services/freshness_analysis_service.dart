import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/car_identification.dart';

/// Pricing for individual VDGL sections (with 43% margin).
class SectionPricing {
  static const double basic = 0.30;    // Basic vehicle info refresh
  static const double specs = 0.38;    // Specs / model details
  static const double tyres = 0.18;    // Tyre details
  static const double full = 1.50;     // Full DataPackage2 lookup

  static const double margin = 0.43;
}

/// Freshness state for a single vehicle.
enum FreshnessCategory { fresh, stale, newLookup }

class VehicleFreshness {
  final String plate;
  final CarIdentification identification;
  final FreshnessCategory category;
  final DateTime? valuationDate;
  final DateTime? motDate;
  final bool valuationStale;
  final bool motStale;
  final double estimatedCost;

  VehicleFreshness({
    required this.plate,
    required this.identification,
    required this.category,
    this.valuationDate,
    this.motDate,
    this.valuationStale = false,
    this.motStale = false,
    required this.estimatedCost,
  });
}

class FreshnessAnalysisResult {
  final List<VehicleFreshness> vehicles;
  final int freshCount;
  final int staleCount;
  final int newCount;
  final double totalEstimatedCost;

  FreshnessAnalysisResult({
    required this.vehicles,
    required this.freshCount,
    required this.staleCount,
    required this.newCount,
    required this.totalEstimatedCost,
  });
}

class FreshnessAnalysisService {
  static final FreshnessAnalysisService _instance =
      FreshnessAnalysisService._internal();
  factory FreshnessAnalysisService() => _instance;
  FreshnessAnalysisService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration valuationThreshold = Duration(days: 30);
  static const Duration motThreshold = Duration(days: 180);

  /// Analyze freshness for a list of vehicles (identified by plate).
  Future<FreshnessAnalysisResult> analyze(
      List<({String plate, CarIdentification identification})> vehicles) async {
    final results = <VehicleFreshness>[];
    int freshCount = 0;
    int staleCount = 0;
    int newCount = 0;
    double totalCost = 0;

    for (final v in vehicles) {
      final normalized =
          v.plate.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final hash =
          sha256.convert(utf8.encode(normalized)).toString();

      final doc =
          await _firestore.collection('vehicles').doc(hash).get();

      if (!doc.exists || doc.data() == null) {
        // New — needs full lookup
        results.add(VehicleFreshness(
          plate: v.plate,
          identification: v.identification,
          category: FreshnessCategory.newLookup,
          estimatedCost: SectionPricing.full,
        ));
        newCount++;
        totalCost += SectionPricing.full;
        continue;
      }

      final data = doc.data()!;
      final now = DateTime.now();

      final valuationTs = _toDateTime(data['valuation_updated']);
      final motTs = _toDateTime(data['mot_updated']);

      final valuationStale = valuationTs == null ||
          now.difference(valuationTs) > valuationThreshold;
      final motStale =
          motTs == null || now.difference(motTs) > motThreshold;

      if (!valuationStale && !motStale) {
        // Fresh — no cost
        results.add(VehicleFreshness(
          plate: v.plate,
          identification: v.identification,
          category: FreshnessCategory.fresh,
          valuationDate: valuationTs,
          motDate: motTs,
          estimatedCost: 0,
        ));
        freshCount++;
      } else {
        // Stale — partial refresh cost
        double cost = 0;
        if (valuationStale) cost += SectionPricing.basic;
        if (motStale) cost += SectionPricing.basic;

        results.add(VehicleFreshness(
          plate: v.plate,
          identification: v.identification,
          category: FreshnessCategory.stale,
          valuationDate: valuationTs,
          motDate: motTs,
          valuationStale: valuationStale,
          motStale: motStale,
          estimatedCost: cost,
        ));
        staleCount++;
        totalCost += cost;
      }
    }

    return FreshnessAnalysisResult(
      vehicles: results,
      freshCount: freshCount,
      staleCount: staleCount,
      newCount: newCount,
      totalEstimatedCost: totalCost,
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

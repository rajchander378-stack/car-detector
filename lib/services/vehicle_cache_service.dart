import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/utils/constants.dart';
import '../models/vehicle_report.dart';
import '../models/vehicle_valuation.dart';
import '../models/vehicle_details.dart';
import '../models/model_details.dart';
import '../models/mot_history.dart';
import '../models/tyre_details.dart';
import 'valuation_service.dart';

/// Result from [VehicleCacheService.getReport] indicating whether the data
/// came from the cache or required a fresh API call.
class CacheResult {
  final VehicleReport report;
  final bool wasCacheHit;
  const CacheResult({required this.report, required this.wasCacheHit});
}

/// Centralized vehicle cache backed by Firestore.
///
/// Stores full vehicle data in `vehicles/{registration_hash}` where the
/// document ID is the SHA-256 hash of the normalized plate (uppercase,
/// no spaces). Stale sections are refreshed in the background using
/// individual VDGL packages so callers always get an immediate response.
class VehicleCacheService {
  static final VehicleCacheService _instance = VehicleCacheService._internal();
  factory VehicleCacheService() => _instance;
  VehicleCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValuationService _valuationService = ValuationService();

  // Cache freshness durations
  static const Duration _valuationMaxAge = Duration(hours: 24);
  static const Duration _motMaxAge = Duration(days: 7);

  // ───────────────────────── public API ─────────────────────────

  /// Returns a [VehicleReport] for [vrm], using the Firestore cache when
  /// possible and falling back to the full DataPackage2 API call when not.
  ///
  /// Stale valuation (>24 h) or MOT (>7 d) sections are returned from
  /// cache immediately while a background refresh is kicked off.
  Future<CacheResult> getReport(String vrm) async {
    final normalized = _normalize(vrm);
    final hash = _hash(normalized);
    final docRef = _firestore.collection('vehicles').doc(hash);

    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      // Cache miss – full API call
      final report = await _fetchAndCache(normalized, docRef);
      return CacheResult(report: report, wasCacheHit: false);
    }

    final data = snapshot.data()!;
    final report = _reportFromCache(data);

    // Kick off background refreshes for stale sections (fire-and-forget)
    _refreshStaleFields(normalized, data, docRef);

    return CacheResult(report: report, wasCacheHit: true);
  }

  // ───────────────────── private: fetch & cache ─────────────────────

  Future<VehicleReport> _fetchAndCache(
    String normalizedVrm,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    final report = await _valuationService.getReport(normalizedVrm);
    final now = FieldValue.serverTimestamp();

    final doc = <String, dynamic>{
      'vrm_normalized': normalizedVrm,
      if (report.valuation != null) 'valuation': report.valuation!.toJson(),
      if (report.vehicleDetails != null)
        'vehicle_details': report.vehicleDetails!.toJson(),
      if (report.modelDetails != null)
        'model_details': report.modelDetails!.toJson(),
      if (report.motHistory != null) 'mot_history': report.motHistory!.toJson(),
      if (report.tyreDetails != null)
        'tyre_details': report.tyreDetails!.toJson(),
      'valuation_updated': now,
      'mot_updated': now,
      'created_at': now,
      'scan_count': 1,
      'last_scanned': now,
    };

    await docRef.set(doc);
    return report;
  }

  // ───────────────── private: read cache into models ─────────────────

  VehicleReport _reportFromCache(Map<String, dynamic> data) {
    return VehicleReport(
      valuation: data['valuation'] != null
          ? VehicleValuation.fromStoredJson(
              data['valuation'] as Map<String, dynamic>)
          : null,
      vehicleDetails: data['vehicle_details'] != null
          ? VehicleDetailsData.fromStoredJson(
              data['vehicle_details'] as Map<String, dynamic>)
          : null,
      modelDetails: data['model_details'] != null
          ? ModelDetailsData.fromStoredJson(
              data['model_details'] as Map<String, dynamic>)
          : null,
      motHistory: data['mot_history'] != null
          ? MotHistory.fromStoredJson(
              data['mot_history'] as Map<String, dynamic>)
          : null,
      tyreDetails: data['tyre_details'] != null
          ? TyreDetailsData.fromStoredJson(
              data['tyre_details'] as Map<String, dynamic>)
          : null,
    );
  }

  // ───────────────── private: background refresh logic ─────────────────

  void _refreshStaleFields(
    String normalizedVrm,
    Map<String, dynamic> data,
    DocumentReference<Map<String, dynamic>> docRef,
  ) {
    final now = DateTime.now();

    // Check valuation freshness
    final valuationTs = _toDateTime(data['valuation_updated']);
    if (valuationTs == null || now.difference(valuationTs) > _valuationMaxAge) {
      _refreshValuation(normalizedVrm, docRef);
    }

    // Check MOT freshness
    final motTs = _toDateTime(data['mot_updated']);
    if (motTs == null || now.difference(motTs) > _motMaxAge) {
      _refreshMot(normalizedVrm, docRef);
    }

    // Always bump scan_count and last_scanned
    docRef.update({
      'scan_count': FieldValue.increment(1),
      'last_scanned': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────── private: individual package refreshes ─────────────────

  /// Calls VDGL with `PackageName=ValuationDetails` and updates the cache.
  Future<void> _refreshValuation(
    String normalizedVrm,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      final json = await _callVdgl(normalizedVrm, 'ValuationDetails');
      final valuation = VehicleValuation.fromJson(json);
      await docRef.update({
        'valuation': valuation.toJson(),
        'valuation_updated': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Background refresh – swallow errors silently so the caller
      // still gets the (stale) cached data.
    }
  }

  /// Calls VDGL with `PackageName=MotHistoryDetails` and updates the cache.
  Future<void> _refreshMot(
    String normalizedVrm,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      final json = await _callVdgl(normalizedVrm, 'MotHistoryDetails');
      final results = json['Results'] as Map<String, dynamic>? ?? {};
      final motData = results['MotHistoryDetails'] as Map<String, dynamic>?;
      if (motData != null) {
        final mot = MotHistory.fromApiJson(motData);
        await docRef.update({
          'mot_history': mot.toJson(),
          'mot_updated': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Background refresh – swallow errors silently.
    }
  }

  // ───────────────── private: raw VDGL HTTP call ─────────────────

  Future<Map<String, dynamic>> _callVdgl(
    String normalizedVrm,
    String packageName,
  ) async {
    final queryParams = {
      'ApiKey': Constants.vdglApiKey,
      'PackageName': packageName,
      'Vrm': normalizedVrm,
    };

    final uri = Uri.parse('${Constants.vdglBaseUrl}/r2/lookup')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw ValuationException('Request timed out'),
        );

    if (response.statusCode != 200) {
      throw ValuationException(
        'API returned status ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final responseInfo =
        json['ResponseInformation'] as Map<String, dynamic>? ?? {};
    final isSuccess = responseInfo['IsSuccessStatusCode'] as bool? ?? false;

    if (!isSuccess) {
      final statusMsg =
          responseInfo['StatusMessage']?.toString() ?? 'Unknown error';
      throw ValuationException(statusMsg);
    }

    return json;
  }

  // ───────────────── private: helpers ─────────────────

  /// Normalize a VRM: strip whitespace, uppercase.
  String _normalize(String vrm) =>
      vrm.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// SHA-256 hash of the normalized VRM, returned as a hex string.
  String _hash(String normalizedVrm) =>
      sha256.convert(utf8.encode(normalizedVrm)).toString();

  /// Safely convert a Firestore Timestamp (or null) to a [DateTime].
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

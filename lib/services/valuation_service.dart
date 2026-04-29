import 'package:cloud_functions/cloud_functions.dart';
import '../models/vehicle_report.dart';
import '../models/vehicle_valuation.dart';
import '../models/utils/constants.dart';

class ValuationService {
  static final ValuationService _instance = ValuationService._internal();
  factory ValuationService() => _instance;
  ValuationService._internal();

  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 3);

  /// Fetches a full vehicle report (valuation + MOT + specs + tyres).
  /// Routes through the Firebase callable function so every call is logged
  /// server-side with the authenticated user's uid.
  Future<VehicleReport> getReport(
    String vrm, {
    int? mileage,
    void Function(int attempt, int total)? onRetry,
  }) async {
    final cleanVrm = vrm.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleanVrm.isEmpty) {
      throw ValuationException('No registration number provided');
    }

    ValuationException? lastError;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await _attemptReport(cleanVrm, mileage: mileage);
      } on ValuationException catch (e) {
        lastError = e;

        if (e.message.contains('authentication') ||
            e.message.contains('No valuation data')) {
          rethrow;
        }

        if (attempt < _maxAttempts) {
          onRetry?.call(attempt + 1, _maxAttempts);
          await Future.delayed(_retryDelay);
        }
      }
    }

    throw lastError ?? ValuationException('Report failed after $_maxAttempts attempts');
  }

  /// Backward-compatible method that returns just the valuation.
  Future<VehicleValuation> getValuation(
    String vrm, {
    int? mileage,
    void Function(int attempt, int total)? onRetry,
  }) async {
    final report = await getReport(vrm, mileage: mileage, onRetry: onRetry);
    if (report.valuation == null || !report.valuation!.hasData) {
      throw ValuationException('No valuation data available for $vrm');
    }
    return report.valuation!;
  }

  Future<VehicleReport> _attemptReport(String cleanVrm, {int? mileage}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'vdglLookup',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 20),
        ),
      );

      final result = await callable.call({
        'vrm': cleanVrm,
        'package': Constants.vdglPackageName,
        if (mileage != null) 'mileage': mileage,
      });

      final json = _deepCast(result.data as Map);
      return VehicleReport.fromApiJson(json);
    } on FirebaseFunctionsException catch (e) {
      throw ValuationException(e.message ?? 'Lookup failed');
    }
  }

  /// Recursively converts a Map returned by the Firebase callable SDK
  /// into a fully-typed Map with String keys and dynamic values.
  static Map<String, dynamic> _deepCast(Map<dynamic, dynamic> map) {
    return map.map((k, v) => MapEntry(k.toString(), _castValue(v)));
  }

  static dynamic _castValue(dynamic value) {
    if (value is Map) return _deepCast(value);
    if (value is List) return value.map(_castValue).toList();
    return value;
  }
}

class ValuationException implements Exception {
  final String message;
  ValuationException(this.message);

  @override
  String toString() => message;
}

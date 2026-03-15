import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/utils/constants.dart';
import '../models/vehicle_report.dart';
import '../models/vehicle_valuation.dart';

class ValuationService {
  static final ValuationService _instance = ValuationService._internal();
  factory ValuationService() => _instance;
  ValuationService._internal();

  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 3);

  /// Fetches a full vehicle report (valuation + MOT + specs + tyres).
  /// Returns a [VehicleReport] containing all available data sections.
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
    final queryParams = {
      'ApiKey': Constants.vdglApiKey,
      'PackageName': Constants.vdglPackageName,
      'Vrm': cleanVrm,
      if (mileage != null) 'Mileage': mileage.toString(),
    };

    final uri = Uri.parse('${Constants.vdglBaseUrl}/r2/lookup')
        .replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ValuationException('Request timed out'),
    );

    if (response.statusCode == 401) {
      throw ValuationException('API authentication failed');
    }
    if (response.statusCode == 429) {
      throw ValuationException('Rate limit exceeded — try again later');
    }
    if (response.statusCode != 200) {
      throw ValuationException(
        'API returned status ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final responseInfo =
        json['ResponseInformation'] as Map<String, dynamic>? ?? {};
    final statusCode = responseInfo['StatusCode'] as int? ?? -1;
    final isSuccess = responseInfo['IsSuccessStatusCode'] as bool? ?? false;

    if (!isSuccess) {
      final statusMsg =
          responseInfo['StatusMessage']?.toString() ?? 'Unknown error';
      throw ValuationException(statusMsg);
    }

    // StatusCode 0 = Success, 1 = SuccessWithWarnings
    if (statusCode != 0 && statusCode != 1) {
      final statusMsg =
          responseInfo['StatusMessage']?.toString() ?? 'Lookup failed';
      throw ValuationException(statusMsg);
    }

    return VehicleReport.fromApiJson(json);
  }
}

class ValuationException implements Exception {
  final String message;
  ValuationException(this.message);

  @override
  String toString() => message;
}

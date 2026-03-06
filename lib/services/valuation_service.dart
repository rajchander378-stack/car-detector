import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/utils/constants.dart';
import '../models/vehicle_valuation.dart';

class ValuationService {
  static final ValuationService _instance = ValuationService._internal();
  factory ValuationService() => _instance;
  ValuationService._internal();

  Future<VehicleValuation> getValuation(String vrm, {int? mileage}) async {
    final cleanVrm = vrm.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleanVrm.isEmpty) {
      throw ValuationException('No registration number provided');
    }

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

    final valuation = VehicleValuation.fromJson(json);
    if (!valuation.hasData) {
      throw ValuationException('No valuation data available for $cleanVrm');
    }

    return valuation;
  }
}

class ValuationException implements Exception {
  final String message;
  ValuationException(this.message);

  @override
  String toString() => message;
}

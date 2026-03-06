import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vehicle_valuation.dart';

class ValuationService {
  final String apiKey;

  static const String _baseUrl =
      'https://uk1.ukvehicledata.co.uk/api/datapackage';
  static const String _package = 'ValuationData';

  ValuationService({required this.apiKey});

  Future<VehicleValuation> getValuation(String vrm) async {
    final cleanVrm = vrm.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleanVrm.isEmpty) {
      throw ValuationException('No registration number provided');
    }

    final uri = Uri.parse(
      '$_baseUrl/$_package'
      '?v=2&api_nullitems=1'
      '&auth_apikey=$apiKey'
      '&key_VRM=$cleanVrm',
    );

    final response = await http.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw ValuationException('Request timed out'),
    );

    if (response.statusCode != 200) {
      throw ValuationException(
        'API returned status ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final statusCode = json['Response']?['StatusCode']?.toString();
    if (statusCode != 'Success') {
      final statusMsg =
          json['Response']?['StatusMessage']?.toString() ?? 'Unknown error';
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

import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/car_identification.dart';
import '../models/vehicle_valuation.dart';

class GeminiPricingService {
  static final GeminiPricingService _instance =
      GeminiPricingService._internal();
  factory GeminiPricingService() => _instance;
  GeminiPricingService._internal();

  static const String _systemPrompt = '''
You are a UK used car pricing estimation system. Given a vehicle's make, model, year, body style, and any other details, provide realistic approximate UK market valuations in GBP.

Base your estimates on typical UK used car market values. Consider:
- The vehicle's age, make, model, and body style
- Typical depreciation curves for the brand/segment
- UK market conditions

Return estimated values for all five pricing categories. Values should be realistic whole numbers in GBP.
If you cannot provide a reasonable estimate, return 0 for that category.''';

  static final Schema _pricingSchema = Schema.object(
    properties: {
      'dealer_forecourt': Schema.integer(
        description: 'Estimated dealer forecourt price in GBP',
      ),
      'private_clean': Schema.integer(
        description: 'Estimated private sale price in GBP',
      ),
      'trade_retail': Schema.integer(
        description: 'Estimated trade/retail price in GBP',
      ),
      'part_exchange': Schema.integer(
        description: 'Estimated part exchange value in GBP',
      ),
      'auction': Schema.integer(
        description: 'Estimated auction value in GBP',
      ),
      'confidence_note': Schema.string(
        description: 'Brief note about estimate confidence',
        nullable: true,
      ),
    },
    optionalProperties: ['confidence_note'],
  );

  late final GenerativeModel _model =
      FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
    systemInstruction: Content.text(_systemPrompt),
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: _pricingSchema,
      temperature: 0.2,
    ),
  );

  /// Attempts to get approximate pricing from Gemini based on vehicle
  /// identification details. Returns null if the request fails.
  Future<VehicleValuation?> getApproximatePricing(
    CarIdentification identification,
  ) async {
    try {
      final parts = <String>[];
      if (identification.make != null) parts.add(identification.make!);
      if (identification.model != null) parts.add(identification.model!);

      final yearStr = identification.yearMin != null &&
              identification.yearMax != null
          ? (identification.yearMin == identification.yearMax
              ? '${identification.yearMin}'
              : '${identification.yearMin}–${identification.yearMax}')
          : (identification.yearMin?.toString() ??
              identification.yearMax?.toString() ??
              '');

      var prompt = 'Estimate UK used car prices for: ${parts.join(' ')}';
      if (yearStr.isNotEmpty) prompt += ', Year: $yearStr';
      if (identification.bodyStyle != null) {
        prompt += ', Body: ${identification.bodyStyle}';
      }
      if (identification.trim != null) {
        prompt += ', Trim: ${identification.trim}';
      }
      if (identification.colour != null) {
        prompt += ', Colour: ${identification.colour}';
      }

      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 15));

      final text = response.text;
      if (text == null || text.isEmpty) return null;

      final json = jsonDecode(text) as Map<String, dynamic>;

      return VehicleValuation(
        dealerForecourt: _parseInt(json['dealer_forecourt']),
        privateClean: _parseInt(json['private_clean']),
        tradeRetail: _parseInt(json['trade_retail']),
        partExchange: _parseInt(json['part_exchange']),
        auction: _parseInt(json['auction']),
      );
    } catch (e) {
      return null;
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value == 0 ? null : value;
    final parsed = int.tryParse(value.toString());
    return parsed == 0 ? null : parsed;
  }
}

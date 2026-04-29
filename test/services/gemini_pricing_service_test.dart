import 'package:flutter_test/flutter_test.dart';
import 'package:car_detector/services/gemini_pricing_service.dart';

void main() {
  group('GeminiPricingService.parseIntField', () {
    test('returns null for null input', () {
      expect(GeminiPricingService.parseIntField(null), isNull);
    });

    test('returns null for zero int (no estimate)', () {
      expect(GeminiPricingService.parseIntField(0), isNull);
    });

    test('returns null for zero string', () {
      expect(GeminiPricingService.parseIntField('0'), isNull);
    });

    test('returns value for positive int', () {
      expect(GeminiPricingService.parseIntField(12000), 12000);
    });

    test('parses string integer', () {
      expect(GeminiPricingService.parseIntField('15500'), 15500);
    });

    test('returns null for non-numeric string', () {
      expect(GeminiPricingService.parseIntField('unknown'), isNull);
    });
  });

  group('GeminiPricingService.parseGeminiResponse', () {
    test('returns null when all price fields are zero or absent', () {
      expect(
        GeminiPricingService.parseGeminiResponse({
          'dealer_forecourt': 0,
          'private_clean': 0,
          'trade_retail': 0,
          'part_exchange': 0,
          'auction': 0,
        }),
        isNull,
      );
    });

    test('returns null for empty map', () {
      expect(GeminiPricingService.parseGeminiResponse({}), isNull);
    });

    test('parses all price fields correctly', () {
      final result = GeminiPricingService.parseGeminiResponse({
        'dealer_forecourt': 14000,
        'private_clean': 11000,
        'trade_retail': 10000,
        'part_exchange': 8500,
        'auction': 7000,
        'confidence_note': 'Estimate based on 2018 Ford Fiesta depreciation',
      });

      expect(result, isNotNull);
      expect(result!.dealerForecourt, 14000);
      expect(result.privateClean, 11000);
      expect(result.tradeRetail, 10000);
      expect(result.partExchange, 8500);
      expect(result.auction, 7000);
    });

    test('returns valuation when only some fields are present', () {
      final result = GeminiPricingService.parseGeminiResponse({
        'dealer_forecourt': 18000,
      });

      expect(result, isNotNull);
      expect(result!.dealerForecourt, 18000);
      expect(result.privateClean, isNull);
    });

    test('hasData is true on successful parse', () {
      final result = GeminiPricingService.parseGeminiResponse({
        'private_clean': 9500,
      });
      expect(result!.hasData, isTrue);
    });

    test('parses string price fields', () {
      final result = GeminiPricingService.parseGeminiResponse({
        'dealer_forecourt': '13500',
        'private_clean': '11000',
      });
      expect(result!.dealerForecourt, 13500);
      expect(result.privateClean, 11000);
    });
  });
}

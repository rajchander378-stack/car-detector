import 'package:flutter_test/flutter_test.dart';
import 'package:car_detector/models/vehicle_valuation.dart';

void main() {
  group('VehicleValuation.hasData', () {
    test('returns false when all price fields are null', () {
      final v = VehicleValuation();
      expect(v.hasData, isFalse);
    });

    test('returns true when dealerForecourt is set', () {
      expect(VehicleValuation(dealerForecourt: 12000).hasData, isTrue);
    });

    test('returns true when privateClean is set', () {
      expect(VehicleValuation(privateClean: 10000).hasData, isTrue);
    });

    test('returns true when tradeRetail is set', () {
      expect(VehicleValuation(tradeRetail: 9000).hasData, isTrue);
    });

    test('returns true when privateAverage is set', () {
      expect(VehicleValuation(privateAverage: 8500).hasData, isTrue);
    });

    test('returns false when only non-primary fields are set', () {
      // auction and partExchange alone do not satisfy hasData
      final v = VehicleValuation(auction: 7000, partExchange: 6500);
      expect(v.hasData, isFalse);
    });
  });

  group('VehicleValuation.formatGbp', () {
    test('formats three-digit value', () {
      expect(VehicleValuation.formatGbp(500), '£500');
    });

    test('formats four-digit value with comma', () {
      expect(VehicleValuation.formatGbp(1000), '£1,000');
    });

    test('formats five-digit value', () {
      expect(VehicleValuation.formatGbp(12500), '£12,500');
    });

    test('formats six-digit value', () {
      expect(VehicleValuation.formatGbp(100000), '£100,000');
    });
  });

  group('VehicleValuation.displayPrice', () {
    test('returns no-valuation string when no prices set', () {
      expect(VehicleValuation().displayPrice, 'No valuation available');
    });

    test('returns single value when only one price is set', () {
      final v = VehicleValuation(dealerForecourt: 15000);
      expect(v.displayPrice, '£15,000');
    });

    test('returns range from lowest to highest across all four price fields', () {
      final v = VehicleValuation(
        privateAverage: 9000,
        privateClean: 10000,
        tradeRetail: 11000,
        dealerForecourt: 13000,
      );
      expect(v.displayPrice, '£9,000 – £13,000');
    });
  });

  group('VehicleValuation.fromStoredJson round-trip', () {
    test('serialises and deserialises pricing fields correctly', () {
      final original = VehicleValuation(
        dealerForecourt: 14000,
        privateClean: 11500,
        tradeRetail: 10000,
        partExchange: 8000,
        auction: 7500,
        vehicleDescription: 'Ford Fiesta 1.0T EcoBoost Titanium',
      );

      final json = original.toJson();
      final restored = VehicleValuation.fromStoredJson(json);

      expect(restored.dealerForecourt, 14000);
      expect(restored.privateClean, 11500);
      expect(restored.tradeRetail, 10000);
      expect(restored.partExchange, 8000);
      expect(restored.auction, 7500);
      expect(restored.vehicleDescription, 'Ford Fiesta 1.0T EcoBoost Titanium');
    });

    test('handles null values in stored json', () {
      final v = VehicleValuation.fromStoredJson({});
      expect(v.hasData, isFalse);
      expect(v.vehicleDescription, isNull);
    });

    test('parses string integers from stored json', () {
      final v = VehicleValuation.fromStoredJson({'dealer_forecourt': '12000'});
      expect(v.dealerForecourt, 12000);
    });
  });
}

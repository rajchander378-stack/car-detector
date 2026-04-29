import 'package:flutter_test/flutter_test.dart';
import 'package:car_detector/services/valuation_error_handler.dart';

void main() {
  group('ValuationErrorHandler.isTerminalError', () {
    test('returns true for InvalidSearchTerm', () {
      expect(
        ValuationErrorHandler.isTerminalError('InvalidSearchTerm: XX99ABC'),
        isTrue,
      );
    });

    test('returns true for not found', () {
      expect(
        ValuationErrorHandler.isTerminalError('Vehicle not found'),
        isTrue,
      );
    });

    test('returns true for No vehicle', () {
      expect(
        ValuationErrorHandler.isTerminalError('No vehicle data returned'),
        isTrue,
      );
    });

    test('returns true for authentication error', () {
      expect(
        ValuationErrorHandler.isTerminalError('authentication failed: 401'),
        isTrue,
      );
    });

    test('returns false for generic network timeout', () {
      expect(
        ValuationErrorHandler.isTerminalError('Connection timed out'),
        isFalse,
      );
    });

    test('returns false for generic API error', () {
      expect(
        ValuationErrorHandler.isTerminalError('Internal server error'),
        isFalse,
      );
    });

    test('returns false for empty string', () {
      expect(ValuationErrorHandler.isTerminalError(''), isFalse);
    });
  });

  group('ValuationErrorHandler.toUserMessage', () {
    test('returns readable message for InvalidSearchTerm', () {
      final msg = ValuationErrorHandler.toUserMessage('InvalidSearchTerm: X');
      expect(msg, contains('Registration not recognised'));
      expect(msg, contains('check the plate'));
    });

    test('passes through other error messages unchanged', () {
      const raw = 'Vehicle not found in VDGL database';
      expect(ValuationErrorHandler.toUserMessage(raw), raw);
    });
  });
}

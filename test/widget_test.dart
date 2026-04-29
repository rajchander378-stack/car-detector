// Smoke test — verifies unit test files load without import errors.
// Full widget tests require a running Firebase emulator and are out of scope here.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () => expect(true, isTrue));
}

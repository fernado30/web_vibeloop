import 'package:flutter_test/flutter_test.dart';
import 'package:vibeloop_mobile/features/auth/domain/age_eligibility.dart';

void main() {
  test('permite registrarse al cumplir 13 años', () {
    expect(isUnder13(DateTime(2013, 7, 21), today: DateTime(2026, 7, 21)), isFalse);
  });
  test('rechaza el registro antes de cumplir 13 años', () {
    expect(isUnder13(DateTime(2013, 7, 22), today: DateTime(2026, 7, 21)), isTrue);
  });
}

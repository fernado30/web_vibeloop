import 'package:flutter_test/flutter_test.dart';
import 'package:Nadie_mobile/features/auth/domain/age_eligibility.dart';

void main() {
  test('permite registrarse al cumplir 13 años', () {
    expect(isUnder13(DateTime(2013, 7, 21), today: DateTime(2026, 7, 21)), isFalse);
  });
  test('rechaza el registro antes de cumplir 13 años', () {
    expect(isUnder13(DateTime(2013, 7, 22), today: DateTime(2026, 7, 21)), isTrue);
  });
  test('requiere aceptación explícita de Términos de Servicio y Privacidad', () {
    expect(
      canSubmitAgeVerification(
        birthDate: DateTime(2000, 1, 1),
        confirmed13Plus: true,
        termsAccepted: false,
      ),
      isFalse,
    );
    expect(
      canSubmitAgeVerification(
        birthDate: DateTime(2000, 1, 1),
        confirmed13Plus: true,
        termsAccepted: true,
      ),
      isTrue,
    );
  });
}

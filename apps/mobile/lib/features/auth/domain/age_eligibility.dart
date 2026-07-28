bool isUnder13(DateTime birthDate, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var age = now.year - birthDate.year;
  final birthdayPassed = now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!birthdayPassed) age--;
  return age < 13;
}

bool canSubmitAgeVerification({
  required DateTime? birthDate,
  required bool confirmed13Plus,
  required bool termsAccepted,
}) => birthDate != null && !isUnder13(birthDate) && confirmed13Plus && termsAccepted;

String ageGateMessage() => 'Nadien no está dirigido a menores de 13 años.';

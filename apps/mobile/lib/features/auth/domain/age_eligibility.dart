bool isUnder13(DateTime birthDate, {DateTime? today}) {
  final now = today ?? DateTime.now();
  var age = now.year - birthDate.year;
  final birthdayPassed = now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!birthdayPassed) age--;
  return age < 13;
}

String ageGateMessage() => 'Vibeloop no está dirigido a menores de 13 años.';

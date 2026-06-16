import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('security hardening files stay in place', () {
    final repoRoot = Directory.current.parent.parent.path;
    final migration = File('$repoRoot\\supabase\\migrations\\20260605195334_secure_group_select_policy.sql').readAsStringSync();
    final schema = File('$repoRoot\\supabase\\schema.sql').readAsStringSync();
    final sendAnonymous = File('$repoRoot\\supabase\\functions\\send-anonymous-message\\index.ts').readAsStringSync();
    final registerUser = File('$repoRoot\\supabase\\functions\\register-user\\index.ts').readAsStringSync();
    final joinGuest = File('$repoRoot\\supabase\\functions\\join-guest-with-photo\\index.ts').readAsStringSync();

    expect(migration.contains("x-group-id"), isFalse);
    expect(schema.contains("x-group-id"), isFalse);
    expect(sendAnonymous.contains('inviteCodePattern'), isTrue);
    expect(sendAnonymous.contains('inviteCode has invalid format'), isTrue);
    expect(registerUser.contains('emailPattern'), isTrue);
    expect(joinGuest.contains('inviteCode is invalid'), isTrue);
  });
}

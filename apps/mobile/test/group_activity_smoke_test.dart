import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive groups cleanup stays wired to activity timestamps', () {
    final repoRoot = Directory.current.parent.parent.path;
    final schema = File('$repoRoot\\supabase\\schema.sql').readAsStringSync();
    final migration = File('$repoRoot\\supabase\\migrations\\0017_group_activity_cleanup.sql').readAsStringSync();
    final groupsRepository = File(
      '$repoRoot\\apps\\mobile\\lib\\features\\groups\\data\\groups_repository.dart',
    ).readAsStringSync();

    expect(schema.contains('last_activity_at timestamptz not null default now()'), isTrue);
    expect(schema.contains('touch_group_activity_messages'), isTrue);
    expect(schema.contains('touch_group_activity_anonymous_messages'), isTrue);
    expect(schema.contains('touch_group_activity_reactions'), isTrue);
    expect(migration.contains('last_activity_at'), isTrue);
    expect(groupsRepository.contains('.gte(\'last_activity_at\''), isTrue);
  });
}

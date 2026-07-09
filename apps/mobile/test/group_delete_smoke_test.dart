import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group delete flow is wired through a privileged function with fallback', () {
    final repoRoot = Directory.current.parent.parent.path;
    final groupsRepository = File(
      '$repoRoot\\apps\\mobile\\lib\\features\\groups\\data\\groups_repository.dart',
    ).readAsStringSync();
    final chatScreen = File(
      '$repoRoot\\apps\\mobile\\lib\\features\\chat\\presentation\\chat_screen.dart',
    ).readAsStringSync();
    final deleteGroupFunction = File(
      '$repoRoot\\supabase\\functions\\delete-group\\index.ts',
    ).readAsStringSync();
    final migration = File('$repoRoot\\supabase\\migrations\\0018_group_delete.sql').readAsStringSync();

    expect(groupsRepository.contains("functions.invoke(\n        'delete-group'"), isTrue);
    expect(groupsRepository.contains('_deleteGroupLocally(groupId);'), isTrue);
    expect(chatScreen.contains('Eliminar grupo'), isTrue);
    expect(chatScreen.contains('showDeleteAction:'), isTrue);
    expect(deleteGroupFunction.contains('Only the group owner can delete it'), isTrue);
    expect(migration.contains('groups_delete_by_owner'), isTrue);
  });
}

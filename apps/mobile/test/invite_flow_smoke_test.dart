import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite join flow stays separate from anonymous inbox flow', () {
    final repoRoot = Directory.current.parent.parent.path;
    final groupsRepository = File(
      '$repoRoot\\apps\\mobile\\lib\\features\\groups\\data\\groups_repository.dart',
    ).readAsStringSync();
    final appRouter = File(
      '$repoRoot\\apps\\mobile\\lib\\core\\router\\app_router.dart',
    ).readAsStringSync();
    final inviteJoinScreen = File(
      '$repoRoot\\apps\\mobile\\lib\\features\\groups\\presentation\\invite_join_screen.dart',
    ).readAsStringSync();
    final chatScreen = File(
      '$repoRoot\\apps\\mobile\\lib\\features\\chat\\presentation\\chat_screen.dart',
    ).readAsStringSync();

    expect(groupsRepository.contains("final appLink = 'vibeloop://invite/\$token';"), isTrue);
    expect(groupsRepository.contains("final webLink = '\$normalizedWebUrl/open/\$token';"), isTrue);

    expect(appRouter.contains("path: '/join/:code'"), isTrue);
    expect(appRouter.contains("return InviteJoinScreen(inviteCode: inviteCode);"), isTrue);
    expect(appRouter.contains("final isInviteFlow = state.matchedLocation.startsWith('/invite/') || state.matchedLocation.startsWith('/join/');"), isTrue);

    expect(inviteJoinScreen.contains("getGroupByInviteCode(widget.inviteCode)"), isTrue);
    expect(inviteJoinScreen.contains("isInvitePausedForCode(widget.inviteCode)"), isTrue);
    expect(inviteJoinScreen.contains("joinGroup(group.id, inviteCode: widget.inviteCode)"), isTrue);
    expect(inviteJoinScreen.contains("context.go('/groups/\${group.id}/chat');"), isTrue);

        expect(chatScreen.contains("final webLinkUri = Uri.parse(links.webLink);"), isTrue);
    expect(chatScreen.contains("text: 'Únete a mi grupo en Nadie: \$inviteLink'"), isTrue);
  });
}

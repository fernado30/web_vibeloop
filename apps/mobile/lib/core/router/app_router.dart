import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/invite_join_screen.dart';
import '../../features/groups/presentation/groups_list_screen.dart';
import '../../features/anonymous/presentation/anonymous_inbox_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/groups',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth-callback',
        builder: (context, state) => const _AuthCallbackScreen(),
      ),
      GoRoute(
        path: '/invite/:code',
        builder: (context, state) {
          final token = state.pathParameters['code']!;
          final inviteCode = token.split('-').last;
          return InviteJoinScreen(inviteCode: inviteCode);
        },
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsListScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: ':id/chat',
            builder: (context, state) => ChatScreen(groupId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: ':id/anonymous',
            builder: (context, state) => AnonymousInboxScreen(groupId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.hasScheme && uri.path.isNotEmpty) {
        final normalizedLocation = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
        if (normalizedLocation != state.uri.toString()) {
          return normalizedLocation;
        }
      }

      final isLoading = authState.maybeWhen(loading: () => true, orElse: () => false);
      if (isLoading) {
        return null;
      }

      final isAuthed = authState.maybeWhen(authenticated: (_) => true, orElse: () => false);
      final goingToAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isProtectedRoute = state.matchedLocation.startsWith('/groups/create') ||
          state.matchedLocation.contains('/chat') ||
          state.matchedLocation.contains('/anonymous');

      if (!isAuthed && isProtectedRoute) {
        return '/login';
      }

      if (isAuthed && goingToAuth) {
        return '/groups';
      }

      return null;
  },
);
});

class _AuthCallbackScreen extends StatelessWidget {
  const _AuthCallbackScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}

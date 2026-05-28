import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/legal/presentation/terms_of_use_screen.dart';
import '../../features/legal/presentation/help_screen.dart';
import '../../features/legal/presentation/security_resources_screen.dart';
import '../../features/settings/presentation/hidden_words_screen.dart';
import '../../features/settings/presentation/blocked_users_screen.dart';
import '../../features/settings/presentation/pause_link_screen.dart';
import '../../features/settings/presentation/message_filtering_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/settings/presentation/appearance_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/invite_join_screen.dart';
import '../../features/groups/presentation/groups_list_screen.dart';
import '../../features/groups/presentation/group_photos_screen.dart';
import '../../features/anonymous/presentation/anonymous_inbox_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepositoryProvider);

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
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'privacy-policy',
                builder: (context, state) => const PrivacyPolicyScreen(),
              ),
              GoRoute(
                path: 'terms-of-use',
                builder: (context, state) => const TermsOfUseScreen(),
              ),
              GoRoute(
                path: 'help',
                builder: (context, state) => const HelpScreen(),
              ),
              GoRoute(
                path: 'security-resources',
                builder: (context, state) => const SecurityResourcesScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'appearance',
                builder: (context, state) => const AppearanceScreen(),
              ),
              GoRoute(
                path: 'hidden-words',
                builder: (context, state) => const HiddenWordsScreen(),
              ),
              GoRoute(
                path: 'blocked-users',
                builder: (context, state) => const BlockedUsersScreen(),
              ),
              GoRoute(
                path: 'pause-link',
                builder: (context, state) => const PauseLinkScreen(),
              ),
              GoRoute(
                path: 'message-filtering',
                builder: (context, state) => const MessageFilteringScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: ':id/chat',
            builder: (context, state) => ChatScreen(groupId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: ':id/photos',
            builder: (context, state) => GroupPhotosScreen(groupId: state.pathParameters['id']!),
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
      if (uri.scheme == 'vibeloop') {
        if (uri.host == 'invite') {
          final invitePath = uri.pathSegments.isEmpty ? '' : '/${uri.pathSegments.join('/')}';
          final query = uri.hasQuery ? '?${uri.query}' : '';
          return '/invite$invitePath$query';
        }

        if (uri.host == 'auth-callback') {
          return '/auth-callback';
        }
      }

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

      final user = authState.maybeWhen(authenticated: (user) => user, orElse: () => null);
      final isAuthed = user != null;
      final isAnonymous = authRepo.currentUser?.isAnonymous ?? false;
      final goingToAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isProtectedRoute = state.matchedLocation.contains('/chat') ||
          state.matchedLocation.contains('/anonymous') ||
          state.matchedLocation.contains('/photos');

      if (!isAuthed && isProtectedRoute) {
        return '/login';
      }

      if (state.matchedLocation.startsWith('/groups/create') && (isAnonymous || !isAuthed)) {
        return '/login';
      }

      if (isAuthed && !isAnonymous && goingToAuth) {
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

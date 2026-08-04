import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../settings/app_preferences_repository.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/legal/presentation/help_screen.dart';
import '../../features/legal/presentation/security_resources_screen.dart';
import '../../features/legal/presentation/dmca_screen.dart';
import '../../features/settings/presentation/hidden_words_screen.dart';
import '../../features/settings/presentation/blocked_users_screen.dart';
import '../../features/settings/presentation/moderation_queue_screen.dart';
import '../../features/settings/presentation/pause_link_screen.dart';
import '../../features/settings/presentation/message_filtering_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/settings/presentation/appearance_screen.dart';
import '../../features/settings/presentation/delete_account_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/invite_join_screen.dart';
import '../../features/groups/presentation/groups_list_screen.dart';
import '../../features/groups/presentation/group_photos_screen.dart';
import '../../features/anonymous/presentation/anonymous_inbox_screen.dart';
import '../../features/stitch/presentation/stitch_design_screen.dart';
import '../../features/stitch/presentation/stitch_onboarding_flow.dart';

String? resolveAppRedirect({
  required String matchedLocation,
  required bool isLoading,
  required bool preferencesLoaded,
  required bool onboardingSeen,
  required bool isAuthed,
  required bool isAnonymous,
  required bool goingToAuth,
  required bool isInviteFlow,
  required bool isAuthCallback,
  required bool isWelcome,
  required bool isSplash,
}) {
  if (isLoading || !preferencesLoaded) {
    return null;
  }

  if (!isAuthed && !goingToAuth && !isWelcome && !isInviteFlow && !isAuthCallback && !isSplash) {
    if (matchedLocation == '/groups' && onboardingSeen) {
      return null;
    }
    return '/login';
  }

  if (!onboardingSeen) {
    if (!isWelcome && !isInviteFlow && !isAuthCallback) {
      return StitchDesignScreen.routeName;
    }
  } else {
    if (isWelcome || isSplash) {
      return '/groups';
    }
  }

  if (matchedLocation.startsWith('/groups/create') && (isAnonymous || !isAuthed)) {
    return '/login';
  }

  if (isAuthed && !isAnonymous && goingToAuth) {
    return '/groups';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: StitchDesignScreen.routeName,
        builder: (context, state) => const StitchDesignScreen(),
      ),
      GoRoute(
        path: StitchPlatformOnboardingScreen.routeName,
        builder: (context, state) => const StitchPlatformOnboardingScreen(),
      ),
      GoRoute(
        path: StitchUsernameOnboardingScreen.routeName,
        builder: (context, state) => const StitchUsernameOnboardingScreen(),
      ),
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
        path: '/join/:code',
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
                path: 'help',
                builder: (context, state) => const HelpScreen(),
              ),
              GoRoute(
                path: 'security-resources',
                builder: (context, state) => const SecurityResourcesScreen(),
              ),
              GoRoute(
                path: 'dmca',
                builder: (context, state) => const DmcaScreen(),
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
                path: 'moderation-queue',
                builder: (context, state) => const ModerationQueueScreen(),
              ),
              GoRoute(
                path: 'pause-link',
                builder: (context, state) => const PauseLinkScreen(),
              ),
              GoRoute(
                path: 'message-filtering',
                builder: (context, state) => const MessageFilteringScreen(),
              ),
              GoRoute(
                path: 'delete-account',
                builder: (context, state) => const DeleteAccountScreen(),
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

      final isLoading = authState.maybeWhen(loading: () => true, orElse: () => false);
      final preferences = ref.read(appPreferencesControllerProvider);
      final user = authState.maybeWhen(authenticated: (user) => user, orElse: () => null);
      final isAuthed = user != null;
      final isAnonymous = authRepo.currentUser?.isAnonymous ?? false;
      final goingToAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final isInviteFlow = state.matchedLocation.startsWith('/invite/') || state.matchedLocation.startsWith('/join/');
      final isAuthCallback = state.matchedLocation == '/auth-callback';
      final isWelcome = state.matchedLocation == StitchDesignScreen.routeName ||
          state.matchedLocation == StitchPlatformOnboardingScreen.routeName ||
          state.matchedLocation == StitchUsernameOnboardingScreen.routeName;
      final isSplash = state.matchedLocation == '/splash';

      return resolveAppRedirect(
        matchedLocation: state.matchedLocation,
        isLoading: isLoading,
        preferencesLoaded: preferences.loaded,
        onboardingSeen: preferences.onboardingSeen,
        isAuthed: isAuthed,
        isAnonymous: isAnonymous,
        goingToAuth: goingToAuth,
        isInviteFlow: isInviteFlow,
        isAuthCallback: isAuthCallback,
        isWelcome: isWelcome,
        isSplash: isSplash,
      );
    },
  );
});

class _AuthCallbackScreen extends StatelessWidget {
  const _AuthCallbackScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0F1D),
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFF8E5DF8),
          ),
        ),
      ),
    );
  }
}

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
      body: SizedBox.shrink(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        child: _SplashBackdrop(),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF14002C),
            Color(0xFF2B0054),
            Color(0xFF730069),
            Color(0xFFF1007D),
          ],
          stops: [0.0, 0.36, 0.70, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoSize =
              (constraints.maxWidth * 0.36).clamp(120.0, 310.0).toDouble();

          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.center,
                child: _SplashLogoGlow(size: logoSize),
              ),
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: Image.asset(
                    'assets/icon/nadie_app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashLogoGlow extends StatelessWidget {
  const _SplashLogoGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size * 1.18,
        height: size * 1.18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB000FF).withValues(alpha: 0.30),
              blurRadius: size * 0.30,
              spreadRadius: size * 0.10,
            ),
            BoxShadow(
              color: const Color(0xFFFF008C).withValues(alpha: 0.22),
              blurRadius: size * 0.52,
              spreadRadius: size * 0.05,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibeloop_mobile/core/router/app_router.dart';
import 'package:vibeloop_mobile/core/settings/app_preferences_repository.dart';
import 'package:vibeloop_mobile/features/stitch/presentation/stitch_onboarding_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el redirect envía a login cuando se intenta entrar a crear grupo sin sesión', () {
    final redirect = resolveAppRedirect(
      matchedLocation: '/groups',
      isLoading: false,
      preferencesLoaded: true,
      onboardingSeen: false,
      isAuthed: false,
      isAnonymous: false,
      goingToAuth: false,
      isInviteFlow: false,
      isAuthCallback: false,
      isWelcome: false,
      isSplash: false,
    );

    expect(redirect, '/login');
  });

  test('permite abrir la pantalla de grupos tras completar onboarding aunque no haya sesión', () {
    final redirect = resolveAppRedirect(
      matchedLocation: '/groups',
      isLoading: false,
      preferencesLoaded: true,
      onboardingSeen: true,
      isAuthed: false,
      isAnonymous: false,
      goingToAuth: false,
      isInviteFlow: false,
      isAuthCallback: false,
      isWelcome: false,
      isSplash: false,
    );

    expect(redirect, isNull);
  });

  testWidgets('no permite continuar si el nombre de usuario está vacío', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final router = GoRouter(
      initialLocation: StitchUsernameOnboardingScreen.routeName,
      routes: [
        GoRoute(
          path: StitchUsernameOnboardingScreen.routeName,
          builder: (context, state) => const StitchUsernameOnboardingScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) => const Scaffold(body: Center(child: Text('groups'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(AppPreferencesRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('groups'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('continuar en el paso de username lleva a la pantalla de crear grupo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final router = GoRouter(
      initialLocation: StitchUsernameOnboardingScreen.routeName,
      routes: [
        GoRoute(
          path: StitchUsernameOnboardingScreen.routeName,
          builder: (context, state) => const StitchUsernameOnboardingScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) => const Scaffold(body: Center(child: Text('groups'))),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) => const Scaffold(body: Center(child: Text('groups'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(AppPreferencesRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.enterText(find.byType(TextField), 'sami');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('groups'), findsOneWidget);
  });
}

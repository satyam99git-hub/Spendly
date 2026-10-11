import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/features/authentication/domain/entities/auth_user.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/judge/presentation/controllers/judge_providers.dart';
import 'package:nayaya_app/features/judge/presentation/screens/judge_shell.dart';
import 'package:nayaya_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:nayaya_app/routes/app_router.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_judge_repository.dart';
import '../../helpers/pump_app.dart';

/// The splash is a pure animation -- it does not navigate. What is worth testing
/// is therefore the pairing: that it renders, and that the ROUTER moves off it
/// to the right place once the session resolves.
void main() {
  group('rendering', () {
    testWidgets('shows the wordmark, tagline and provenance line', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('NyayaAI'), findsOneWidget);
      expect(find.text('JUSTICE, SIMPLIFIED'), findsOneWidget);
      expect(
        find.text('Government of India • Advanced FIR System'),
        findsOneWidget,
      );
    });

    testWidgets('honours reduced motion by starting fully drawn', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: SplashScreen()),
        ),
      );
      // No pumping past the animation: with motion disabled it should already
      // be at its end state on the first frame.
      await tester.pump();

      // The elements fade via FadeTransition, which drives a
      // RenderAnimatedOpacity directly rather than building an Opacity widget.
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('NyayaAI'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 1.0);
    });
  });

  group('startup routing', () {
    Future<void> pumpApp(
      WidgetTester tester,
      FakeAuthRepository repository,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            // A judge lands on the Judge Portal, whose Home loads the docket
            // on build.
            judgeRepositoryProvider.overrideWithValue(FakeJudgeRepository()),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: ref.watch(appRouterProvider),
            ),
          ),
        ),
      );
    }

    testWidgets('holds on the splash while the session is being resolved', (
      tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.pump();

      // Still resolving: the brand mark is up and sign-in has not appeared.
      expect(find.text('JUSTICE, SIMPLIFIED'), findsOneWidget);
      expect(find.text('Email address'), findsNothing);

      await settleStartup(tester);
      await tester.pumpAndSettle();
    });

    testWidgets('goes to sign-in when there is no stored session', (
      tester,
    ) async {
      final repository = FakeAuthRepository()..restoreResult = null;
      await pumpApp(tester, repository);

      await settleStartup(tester);
      await tester.pumpAndSettle();

      expect(find.text('Email address'), findsOneWidget);
      expect(repository.restoreCount, 1);
    });

    testWidgets('goes straight to home when a session is restored', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..restoreResult = const AuthUser(
          role: UserRole.police,
          uniqueId: 'POL9999',
          fullName: 'Shivam Gupta',
          email: 'shivam99@gmail.com',
        );
      await pumpApp(tester, repository);

      await settleStartup(tester);
      await tester.pumpAndSettle();

      expect(find.text('Shivam Gupta'), findsOneWidget);
      expect(find.text('POL9999'), findsOneWidget);
      // Never flashed the sign-in form on the way through.
      expect(find.text('Email address'), findsNothing);
    });

    // The sign-in screen never navigates; the redirect does. This is the test
    // that proves the pairing works end to end.
    testWidgets('signing in moves from the form to home', (tester) async {
      final repository = FakeAuthRepository()
        ..restoreResult = null
        ..loginResult = const AuthUser(
          role: UserRole.judge,
          uniqueId: 'JUD001',
          fullName: 'Test Judge',
          email: 'judge@example.com',
        );
      await pumpApp(tester, repository);
      await settleStartup(tester);
      await tester.pumpAndSettle();

      expect(find.text('Email address'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'judge@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      // A judge lands on the Judge Portal. The website's judge page names
      // nobody — it greets every judge as "Judge" (judge_dashboard.html:110) —
      // so the account's name and ID are not on screen to assert on.
      expect(find.byType(JudgeShell), findsOneWidget);
      expect(
        find.textContaining('Welcome back, Judge.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Email address'), findsNothing);
    });

    testWidgets('signing out returns to sign-in', (tester) async {
      final repository = FakeAuthRepository()
        ..restoreResult = const AuthUser(
          role: UserRole.judge,
          uniqueId: 'JUD001',
          fullName: 'Test Judge',
        );
      await pumpApp(tester, repository);
      await settleStartup(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Email address'), findsOneWidget);
      expect(repository.logoutCount, 1);
    });

    // The website's citizen "Sign Out" is a plain link to /logout, and the
    // project kept that for citizens (parity spec, decision D-4a).
    testWidgets('a citizen signs out at once, with no confirmation', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..restoreResult = const AuthUser(
          role: UserRole.citizen,
          uniqueId: 'CIT001',
          fullName: 'Test Citizen',
        );
      await pumpApp(tester, repository);
      await settleStartup(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Email address'), findsOneWidget);
      expect(repository.logoutCount, 1);
    });
  });
}

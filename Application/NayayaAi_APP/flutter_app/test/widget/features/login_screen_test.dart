import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/authentication/domain/entities/auth_user.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

/// Behavioural coverage for sign-in. These assert what the screen DOES -- what
/// it submits, what it refuses to submit, what it clears on failure -- not how
/// it is laid out. Pixel assertions belong in the golden tests.
void main() {
  Finder emailField() => find.byType(TextField).first;
  Finder passwordField() => find.byType(TextField).last;

  group('rendering', () {
    testWidgets('shows the masthead, both fields and the footer', (
      tester,
    ) async {
      await pumpAuthApp(tester, repository: FakeAuthRepository());

      expect(find.text('Sign in'), findsWidgets);
      expect(
        find.text('Authorised access only. Activity is logged.'),
        findsOneWidget,
      );
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(
        find.text('NyayaAI · Government of India'),
        findsOneWidget,
      );
    });

    testWidgets('offers a route to registration', (tester) async {
      await pumpAuthApp(tester, repository: FakeAuthRepository());

      expect(find.text('New to NyayaAI?'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
    });

    // The website authenticates every role through one email/password form and
    // returns the role in the response. A role picker here would be the app
    // guessing at something the server is about to state authoritatively.
    testWidgets('does not ask for a role', (tester) async {
      await pumpAuthApp(tester, repository: FakeAuthRepository());

      expect(find.text('Citizen'), findsNothing);
      expect(find.text('Police Officer'), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('rejects an empty form without calling the repository', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpAuthApp(tester, repository: repository);

      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(repository.loginCalls, isEmpty);
    });

    testWidgets('rejects a malformed email', (tester) async {
      final repository = FakeAuthRepository();
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'not-an-email');
      await tester.enterText(passwordField(), 'whatever');
      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repository.loginCalls, isEmpty);
    });

    // The server has never enforced a password policy, so accounts already in
    // the database have passwords shorter than any floor the app might invent.
    // A client-side minimum here would lock those users out of an app whose
    // whole job is to accept their existing credentials.
    testWidgets('accepts a short password so existing accounts can sign in', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'abc');
      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(find.textContaining('at least'), findsNothing);
      expect(repository.loginCalls, hasLength(1));
    });
  });

  group('input normalisation', () {
    testWidgets('lowercases the email and strips whitespace', (tester) async {
      final repository = FakeAuthRepository();
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), '  Officer@Example.COM ');
      await tester.enterText(passwordField(), 'secret');
      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(repository.loginCalls.single.email, 'officer@example.com');
    });
  });

  group('submission', () {
    testWidgets('sends exactly what was typed', (tester) async {
      final repository = FakeAuthRepository();
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'judge@example.com');
      await tester.enterText(passwordField(), 'Sup3rSecret');
      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(repository.loginCalls.single.email, 'judge@example.com');
      expect(repository.loginCalls.single.password, 'Sup3rSecret');
    });

    testWidgets('shows a spinner while the request is in flight', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..delay = const Duration(milliseconds: 300);
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'secret');
      await tester.tap(find.text('Sign in').last);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a second tap cannot fire a second request', (tester) async {
      final repository = FakeAuthRepository()
        ..delay = const Duration(milliseconds: 300);
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'secret');

      await tester.tap(find.text('Sign in').last);
      await tester.pump();
      // The button nulls its callback while busy, so this tap lands on a
      // disabled control.
      await tester.tap(find.text('Sign in').last, warnIfMissed: false);
      await tester.pump();

      expect(repository.loginCalls, hasLength(1));

      await tester.pump(const Duration(milliseconds: 400));
    });

    // Where a successful sign-in LANDS is the router's redirect, not this
    // screen's doing -- the screen deliberately never navigates. That behaviour
    // is covered in splash_screen_test, against the real app router.
    testWidgets('reports success without navigating itself', (tester) async {
      final repository = FakeAuthRepository()
        ..loginResult = const AuthUser(
          role: UserRole.police,
          uniqueId: 'POL001',
          email: 'officer@example.com',
        );
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'secret');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(repository.loginCalls, hasLength(1));
      // No failure banner: the attempt succeeded even though this harness has
      // no redirect to carry the user onward.
      expect(find.textContaining('Invalid'), findsNothing);
    });
  });

  group('failure handling', () {
    testWidgets("surfaces the server's own message", (tester) async {
      final repository = FakeAuthRepository()
        ..loginFailure = const AuthFailure(message: 'Invalid credentials');
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'wrong');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('clears the password but keeps the email', (tester) async {
      final repository = FakeAuthRepository()
        ..loginFailure = const AuthFailure();
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'wrong');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(emailField()).controller?.text,
        'officer@example.com',
      );
      expect(tester.widget<TextField>(passwordField()).controller?.text, '');
    });

    testWidgets('a network failure reads as connectivity, not a bad password', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..loginFailure = const NetworkFailure();
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'secret');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Cannot reach'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets('the banner clears on the next attempt', (tester) async {
      final repository = FakeAuthRepository()
        ..loginFailure = const AuthFailure(message: 'Invalid credentials');
      await pumpAuthApp(tester, repository: repository);

      await tester.enterText(emailField(), 'officer@example.com');
      await tester.enterText(passwordField(), 'wrong');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);

      repository
        ..loginFailure = null
        ..loginResult = const AuthUser(
          role: UserRole.citizen,
          uniqueId: 'CIT001',
        );

      await tester.enterText(passwordField(), 'right');
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('the registration link opens sign-up', (tester) async {
      await pumpAuthApp(tester, repository: FakeAuthRepository());

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsWidgets);
      expect(find.text('I am registering as'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/shared/widgets/inputs/password_strength_meter.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

/// Behavioural coverage for registration.
///
/// The interesting rule here is the server's: police, lawyer and judge must
/// supply their own correctly-prefixed unique ID, while a citizen's is generated
/// server-side. Picking a role therefore changes what the form asks for, and
/// most of these tests are about that.
void main() {
  // The form's field order: name, email, password, and -- for the professional
  // roles only -- the unique ID.
  final nameBox = find.byType(TextField).at(0);
  final emailBox = find.byType(TextField).at(1);
  final passwordBox = find.byType(TextField).at(2);
  final confirmBox = find.byType(TextField).at(3);
  final idBox = find.byType(TextField).at(4);

  Future<void> pumpSignup(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) =>
      pumpAuthApp(
        tester,
        repository: repository,
        initialLocation: AppRoutes.signup,
      );

  /// Scrolls the submit button into view, then taps it.
  ///
  /// With the unique-ID field showing, the form is taller than a phone screen
  /// and the button genuinely sits below the fold -- a real user scrolls to
  /// reach it. Tapping blind would miss and fail the test for a reason that has
  /// nothing to do with what it is asserting.
  Future<void> submit(WidgetTester tester) async {
    final button = find.text('Create account').last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
  }

  group('role selection', () {
    testWidgets('offers the four registerable roles and defaults to citizen', (
      tester,
    ) async {
      await pumpSignup(tester, FakeAuthRepository());

      expect(find.text('Citizen'), findsOneWidget);
      expect(find.text('Police Officer'), findsOneWidget);
      expect(find.text('Lawyer'), findsOneWidget);
      expect(find.text('Judge'), findsOneWidget);

      // Administrator is not registerable — the server rejects it as an
      // invalid role.
      expect(find.text('Administrator'), findsNothing);
    });

    testWidgets('hides the unique-ID field for a citizen', (tester) async {
      await pumpSignup(tester, FakeAuthRepository());

      expect(find.text('Citizen ID'), findsNothing);
      expect(find.textContaining('Must start with'), findsNothing);
    });

    testWidgets('reveals a prefixed ID field for a police officer', (
      tester,
    ) async {
      await pumpSignup(tester, FakeAuthRepository());

      await tester.tap(find.text('Police Officer'));
      await tester.pumpAndSettle();

      expect(find.text('Police Officer ID'), findsOneWidget);
      expect(
        find.text('Must start with POL and match the ID issued to you.'),
        findsOneWidget,
      );
    });

    testWidgets('the prefix hint follows the selected role', (tester) async {
      await pumpSignup(tester, FakeAuthRepository());

      await tester.tap(find.text('Judge'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Must start with JUD'), findsOneWidget);

      await tester.tap(find.text('Lawyer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Must start with LAW'), findsOneWidget);
    });

    // A POL id left in the box after switching to Lawyer would fail server
    // validation with a message about a prefix the user can no longer see.
    testWidgets('switching to citizen clears a typed ID', (tester) async {
      final repository = FakeAuthRepository();
      await pumpSignup(tester, repository);

      await tester.tap(find.text('Police Officer'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'POL777');

      await tester.tap(find.text('Citizen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Police Officer'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        isEmpty,
      );
    });
  });

  group('validation', () {
    testWidgets('rejects an empty form', (tester) async {
      final repository = FakeAuthRepository();
      await pumpSignup(tester, repository);

      await submit(tester);
      await tester.pump();

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Enter your email address'), findsOneWidget);
      // Distinct from the field's "Choose a password" label -- see
      // Validators.signupPassword.
      expect(find.text('Enter a password'), findsOneWidget);
      expect(repository.signupCalls, isEmpty);
    });

    testWidgets('enforces the role prefix before reaching the server', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpSignup(tester, repository);

      await tester.tap(find.text('Police Officer'));
      await tester.pumpAndSettle();

      await tester.enterText(nameBox, 'Test Officer');
      await tester.enterText(emailBox, 'officer@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await tester.enterText(idBox, 'XYZ123');

      await submit(tester);
      await tester.pump();

      expect(find.text('ID must start with POL'), findsOneWidget);
      expect(repository.signupCalls, isEmpty);
    });

    testWidgets('requires more than just the prefix', (tester) async {
      final repository = FakeAuthRepository();
      await pumpSignup(tester, repository);

      await tester.tap(find.text('Lawyer'));
      await tester.pumpAndSettle();

      await tester.enterText(nameBox, 'Test Counsel');
      await tester.enterText(emailBox, 'law@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await tester.enterText(idBox, 'LAW');

      await submit(tester);
      await tester.pump();

      expect(find.text('Add your number after LAW'), findsOneWidget);
      expect(repository.signupCalls, isEmpty);
    });

    testWidgets('enforces the app password floor', (tester) async {
      final repository = FakeAuthRepository();
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'cit@example.com');
      await tester.enterText(passwordBox, 'short');
      await tester.enterText(confirmBox, 'short');

      await submit(tester);
      await tester.pump();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(repository.signupCalls, isEmpty);
    });
  });

  group('submission', () {
    testWidgets('uppercases the unique ID, matching the server', (
      tester,
    ) async {
      final repository = FakeAuthRepository()..signupResult = 'POL042';
      await pumpSignup(tester, repository);

      await tester.tap(find.text('Police Officer'));
      await tester.pumpAndSettle();

      await tester.enterText(nameBox, 'Test Officer');
      await tester.enterText(emailBox, 'officer@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await tester.enterText(idBox, 'pol042');

      await submit(tester);
      await tester.pumpAndSettle();

      expect(repository.signupCalls.single.uniqueId, 'POL042');
      expect(repository.signupCalls.single.role, UserRole.police);
    });

    testWidgets('sends the citizen role with no ID', (tester) async {
      final repository = FakeAuthRepository()..signupResult = 'CIT013';
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'cit@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');

      await submit(tester);
      await tester.pumpAndSettle();

      expect(repository.signupCalls.single.role, UserRole.citizen);
      expect(repository.signupCalls.single.uniqueId, isEmpty);
    });

    // A citizen's ID is generated server-side and shown here for the first and
    // only time, so the confirmation must not be dismissible by a timeout.
    testWidgets('shows the assigned unique ID on success', (tester) async {
      final repository = FakeAuthRepository()..signupResult = 'CIT013';
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'cit@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');

      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Account created'), findsOneWidget);
      expect(find.text('CIT013'), findsOneWidget);
      expect(find.text('YOUR UNIQUE ID'), findsOneWidget);
    });

    testWidgets('returns to sign-in after the confirmation', (tester) async {
      final repository = FakeAuthRepository()..signupResult = 'CIT013';
      await pumpAuthApp(tester, repository: repository);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'cit@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await submit(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue to sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('New to NyayaAI?'), findsOneWidget);
    });

    // /signup establishes no session server-side, so the app must not pretend
    // one exists.
    testWidgets('does not sign the user in', (tester) async {
      final repository = FakeAuthRepository()..signupResult = 'CIT013';
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'cit@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsNothing);
      expect(repository.loginCalls, isEmpty);
    });
  });

  group('website parity', () {
    // POST /signup answers an already-registered email with 200, no ID and
    // "If eligible, your account has been created." (app.py:2004-2005). The
    // screen must not announce an account that was never made.
    testWidgets('an already-registered email shows the server message only', (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..signupResult = ''
        ..signupMessage = 'If eligible, your account has been created.';
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'taken@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await submit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('If eligible, your account has been created.'),
        findsOneWidget,
      );
      expect(find.text('Account created'), findsNothing);
      expect(find.text('YOUR UNIQUE ID'), findsNothing);
    });

    // The website's Confirm box and its message (signup.html:501-504).
    testWidgets('a mismatched confirmation is refused before the server', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'cit@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password124');
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repository.signupCalls, isEmpty);
    });

    // signup.html:480-491 — one point each, weak/medium/strong.
    test('the strength meter scores as the website does', () {
      expect(PasswordStrengthMeter.strengthOf(''), 0);
      expect(PasswordStrengthMeter.strengthOf('abcdef'), 1);
      expect(PasswordStrengthMeter.strengthOf('abcdefghij'), 2);
      expect(PasswordStrengthMeter.strengthOf('Abcdefghi1'), 3);
      expect(PasswordStrengthMeter.strengthOf('Abcdefghi1!'), 4);
      expect(PasswordStrengthMeter.levelOf(1), 'weak');
      expect(PasswordStrengthMeter.levelOf(2), 'medium');
      expect(PasswordStrengthMeter.levelOf(3), 'strong');
    });
  });

  group('failure handling', () {
    testWidgets("surfaces the server's duplicate-email message", (
      tester,
    ) async {
      final repository = FakeAuthRepository()
        ..signupFailure = const ValidationFailure('Email already registered');
      await pumpSignup(tester, repository);

      await tester.enterText(nameBox, 'Test Citizen');
      await tester.enterText(emailBox, 'taken@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Email already registered'), findsOneWidget);
      expect(find.text('Account created'), findsNothing);
    });

    testWidgets("surfaces the server's duplicate-ID message", (tester) async {
      final repository = FakeAuthRepository()
        ..signupFailure =
            const ValidationFailure('Unique ID already registered');
      await pumpSignup(tester, repository);

      await tester.tap(find.text('Judge'));
      await tester.pumpAndSettle();

      await tester.enterText(nameBox, 'Test Judge');
      await tester.enterText(emailBox, 'judge@example.com');
      await tester.enterText(passwordBox, 'password123');
      await tester.enterText(confirmBox, 'password123');
      await tester.enterText(idBox, 'JUD001');
      await submit(tester);
      await tester.pumpAndSettle();

      expect(find.text('Unique ID already registered'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/features/authentication/domain/entities/auth_user.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/citizen_missing_person_detail_screen.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/citizen_shell.dart';
import 'package:nayaya_app/features/complaints/presentation/controllers/complaint_providers.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_lock_controller.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/evidence/presentation/widgets/evidence_keys.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_form_controller.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_field_keys.dart';
import 'package:nayaya_app/features/judge/presentation/controllers/judge_providers.dart';
import 'package:nayaya_app/features/lawyer/presentation/controllers/lawyer_providers.dart';
import 'package:nayaya_app/features/missing_persons/presentation/controllers/missing_person_providers.dart';
import 'package:nayaya_app/routes/app_router.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_complaint_repository.dart';
import '../../helpers/fake_evidence_repository.dart';
import '../../helpers/fake_fir_repository.dart';
import '../../helpers/fake_judge_repository.dart';
import '../../helpers/fake_lawyer_repository.dart';
import '../../helpers/fake_missing_person_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';
import '../../helpers/pump_app.dart';

/// Who can reach the police surfaces, against the REAL app router.
///
/// The FIR form and the locker have their own tests, which mount them directly —
/// right for testing a form, and silent on whether a citizen can open one. That
/// answer lives in one place, the redirect in `app_router.dart`, and this is
/// where it is checked.
///
/// It is a UI guard and only a UI guard: `POST /generate_fir` and every evidence
/// endpoint have no session check of their own. What these tests prove is that
/// the app does not offer a door it would then have to apologise for, not that
/// the record is protected.
void main() {
  late FakeAuthRepository auth;

  Future<void> pumpSignedIn(WidgetTester tester, UserRole role) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);

    auth = FakeAuthRepository()
      ..restoreResult = AuthUser(
        role: role,
        uniqueId: '${role.idPrefix}001',
        fullName: 'Test ${role.label}',
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          firRepositoryProvider.overrideWithValue(FakeFirRepository()),
          evidenceRepositoryProvider
              .overrideWithValue(FakeEvidenceRepository()),
          // The console's tabs live in an IndexedStack, so every one of them is
          // built the moment a police user lands — including the complaints
          // inbox, which fetches on build. Without this it would reach for the
          // real Dio client and render its failure state behind the tab being
          // asserted on.
          complaintRepositoryProvider
              .overrideWithValue(FakeComplaintRepository()),
          missingPersonRepositoryProvider
              .overrideWithValue(FakeMissingPersonRepository()),
          // A lawyer lands on the Lawyer Portal, whose Home fetches on build.
          lawyerRepositoryProvider.overrideWithValue(FakeLawyerRepository()),
          // A judge lands on the Judge Portal, which loads the docket and the
          // FIR list on build.
          judgeRepositoryProvider.overrideWithValue(FakeJudgeRepository()),
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            routerConfig: ref.watch(appRouterProvider),
          ),
        ),
      ),
    );

    await settleStartup(tester);
    await tester.pumpAndSettle();
  }

  /// Navigates the way a deep link or a restored task would — bypassing the UI,
  /// which is the only interesting case for a guard.
  Future<void> goTo(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  group('police', () {
    testWidgets('land on the tabbed console, not the role list', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.police);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('FIR'), findsOneWidget);
      expect(find.text('Complaints'), findsOneWidget);
      expect(find.text('Evidence'), findsOneWidget);
    });

    testWidgets('the FIR tab offers filing one, and the card opens the form', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.police);

      expect(find.text('File an FIR'), findsOneWidget);

      await tester.tap(find.text('File an FIR'));
      await tester.pumpAndSettle();

      // Step 1 of the wizard. "File this FIR" lives on the review, four steps
      // away, so this asserts the form opened rather than that it can be
      // submitted — which is fir_form_screen_test's business.
      expect(find.text('New FIR'), findsOneWidget);
      expect(
        find.byKey(FirFieldKeys.step(FirFormStep.registration)),
        findsOneWidget,
      );
    });

    testWidgets('the Evidence tab opens on the PIN gate', (tester) async {
      await pumpSignedIn(tester, UserRole.police);

      await tester.tap(find.text('Evidence'));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceKeys.pinField), findsOneWidget);
    });

    // The gate exists to stop a handset left on a desk from showing a
    // complainant's evidence to whoever picks it up. A locker unlocked once at
    // the start of a shift and open for the rest of it does not do that, so
    // leaving the tab closes it again.
    testWidgets('the locker relocks when the officer leaves its tab', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.police);

      await tester.tap(find.text('Evidence'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(EvidenceKeys.pinField),
          matching: find.byType(TextField),
        ),
        FakeEvidenceRepository().acceptedPin,
      );
      await tester.tap(find.byKey(EvidenceKeys.pinSubmit));
      await tester.pumpAndSettle();
      expect(find.byKey(EvidenceKeys.pinField), findsNothing);

      await tester.tap(find.text('FIR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evidence'));
      await tester.pumpAndSettle();

      expect(find.byKey(EvidenceKeys.pinField), findsOneWidget);
    });

    testWidgets('an admin reaches it too, matching the server\'s _is_police', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.admin);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('File an FIR'), findsOneWidget);
    });
  });

  group('everyone else', () {
    testWidgets('a citizen gets the Citizen Portal, with no police surfaces', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.citizen);

      expect(find.byType(CitizenShell), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('File an FIR'), findsNothing);
    });

    testWidgets('a citizen sent straight to the FIR form lands on home', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.citizen);

      await goTo(tester, '/fir/new');

      expect(find.text('File this FIR'), findsNothing);
      expect(find.byType(CitizenShell), findsOneWidget);
    });

    testWidgets('a judge is turned away from the FIR form as well', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.judge);

      await goTo(tester, '/fir/new');

      expect(find.text('File this FIR'), findsNothing);
    });

    // The guard is one loop over AppRoutes.policePrefixes, so /evidence is
    // covered by construction — but "by construction" is what this asserts.
    testWidgets('a citizen cannot deep-link into the evidence routes', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.citizen);

      await goTo(tester, '/evidence/add');
      expect(find.text('Add evidence'), findsNothing);
      expect(find.byType(CitizenShell), findsOneWidget);

      await goTo(tester, '/evidence/item/FIR001/scene.jpg');
      expect(find.text('Evidence'), findsNothing);
      expect(find.byType(CitizenShell), findsOneWidget);
    });

    // Two prefixes added with the law library and the missing-persons register.
    // The guard covers a new prefix only if it was added to `policePrefixes`,
    // which is a line a feature is easy to ship without.
    testWidgets('a citizen cannot deep-link into the law routes', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.citizen);

      for (final path in [
        '/law',
        '/law/ask',
        '/law/outcome',
        '/law/section/IPC/379',
      ]) {
        await goTo(tester, path);
        expect(
          find.byType(CitizenShell),
          findsOneWidget,
          reason: '$path let a citizen through',
        );
      }
    });

    testWidgets('a citizen cannot deep-link into the missing-persons routes', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.citizen);

      for (final path in [
        '/missing-persons',
        '/missing-persons/new',
        '/missing-persons/MP_1',
      ]) {
        await goTo(tester, path);
        expect(
          find.byType(CitizenShell),
          findsOneWidget,
          reason: '$path let a citizen through',
        );
      }
    });

    // Every prefix in the list, checked as a list. A police surface added
    // without its prefix here is a surface a citizen can deep-link into, and
    // that is a one-line omission nobody notices in review.
    testWidgets('every police prefix turns a citizen away', (tester) async {
      await pumpSignedIn(tester, UserRole.citizen);

      for (final prefix in AppRoutes.policePrefixes) {
        await goTo(tester, prefix);
        expect(
          find.byType(CitizenShell),
          findsOneWidget,
          reason: '$prefix let a citizen through',
        );
      }
    });
  });

  group('the citizen surfaces', () {
    // The mirror of the police guard: the website's /citizen-dashboard turns
    // every other role away (app.py:572-573).
    testWidgets('a citizen reaches the citizen missing-person page', (
      tester,
    ) async {
      await pumpSignedIn(tester, UserRole.citizen);

      await goTo(tester, '/citizen/missing-persons/MP_1');

      expect(find.byType(CitizenMissingPersonDetailScreen), findsOneWidget);
    });

    for (final role in [UserRole.police, UserRole.lawyer, UserRole.judge]) {
      testWidgets('a ${role.wireValue} is turned away from it', (tester) async {
        await pumpSignedIn(tester, role);

        await goTo(tester, '/citizen/missing-persons/MP_1');

        expect(find.byType(CitizenMissingPersonDetailScreen), findsNothing);
        expect(find.byType(CitizenShell), findsNothing);
      });
    }
  });

  group('the receipt', () {
    // Its whole content is a record that was just filed. Without one there is
    // nothing to confirm, so a cold launch onto this URL must not show an empty
    // congratulations.
    testWidgets('is unreachable when no FIR has been filed', (tester) async {
      await pumpSignedIn(tester, UserRole.police);

      await goTo(tester, '/fir/success');

      expect(find.text('FIR registered'), findsNothing);
      expect(find.text('Test Police Officer'), findsOneWidget);
    });
  });

  group('signing out', () {
    // The locker's state is in memory and survives a screen being popped, so
    // without the reset in app_router the next person to sign in on the same
    // handset would find it already open.
    testWidgets('closes the evidence locker', (tester) async {
      await pumpSignedIn(tester, UserRole.police);

      final container = containerOf(tester);
      await container
          .read(evidenceLockControllerProvider.notifier)
          .unlock(FakeEvidenceRepository().acceptedPin);
      await tester.pumpAndSettle();
      expect(
        container.read(evidenceLockControllerProvider).unlocked,
        isTrue,
      );

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(
        container.read(evidenceLockControllerProvider).unlocked,
        isFalse,
      );
    });
  });
}

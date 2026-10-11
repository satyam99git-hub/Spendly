import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/constants/storage_keys.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_lock_controller.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/evidence/presentation/screens/evidence_locker_screen.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_form_controller.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_record.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_form_screen.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_record_screen.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_success_screen.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import '../helpers/fake_evidence_repository.dart';
import '../helpers/fake_fir_repository.dart';
import '../helpers/golden_assets.dart';
import '../helpers/golden_fonts.dart';
import '../helpers/in_memory_secure_storage.dart';

/// Golden snapshots of the police console.
///
/// Five surfaces, chosen because each is a different *kind* of screen, not
/// because there are five worth looking at: a long form, a receipt, a gate, a
/// populated list, and the same form in dark. Snapshotting more would pin
/// several near-identical columns of fields and turn one wording change into
/// four failures.
///
/// Every date in them is fixed. A golden that moves with the calendar is a
/// golden that fails every morning.
///
/// See loadGoldenFonts for why the fonts are bound by hand and why these are
/// tagged `golden`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

  /// iPhone-14-class logical size at 3x.
  const logicalSize = Size(390, 844);
  const pixelRatio = 3.0;

  /// A draft seeded through storage rather than typed. Driving the form for six
  /// screenshots would make these tests about the form's interactions, which
  /// the widget tests already own.
  final filled = const FirDraft(
    firNo: 'FIR 41/2026',
    district: 'Delhi',
    policeStation: 'North Delhi PS',
    firDate: '2026-08-09',
    occurrenceDate: '2026-08-07',
    placeOfOccurrence: 'Sector 14 market, opposite the bus stand',
    complainantName: 'Anita Sharma',
    sections: [
      ActSection(act: 'IPC', section: '379'),
      ActSection(act: 'IPC', section: '411'),
    ],
    statement: 'The complainant states that her two-wheeler, parked outside '
        'the Sector 14 market, was found missing at about 12:30 hrs on '
        '7 August 2026.',
  ).toJson();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    List<Override> overrides = const [],
  }) async {
    tester.view
      ..devicePixelRatio = pixelRatio
      ..physicalSize = logicalSize * pixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            // Tests report zero insets. Inject the notch and home-indicator
            // padding a real handset has, or the header sits too high.
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              textScaler: TextScaler.noScaling,
            ),
            child: child!,
          ),
          home: child,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await precacheBrandAssets(tester);
  }

  List<Override> firOverrides({Map<String, String>? storage}) => [
        firRepositoryProvider.overrideWithValue(FakeFirRepository()),
        secureStorageProvider.overrideWithValue(InMemorySecureStorage(storage)),
      ];

  group('the FIR form', () {
    testWidgets(
      'filled, light',
      (tester) async {
        await pumpRouted(
          tester,
          const FirFormScreen(),
          overrides: firOverrides(
            storage: {StorageKeys.firDraft: jsonEncode(filled)},
          ),
        );

        await expectLater(
          find.byType(FirFormScreen),
          matchesGoldenFile('images/fir_form_light.png'),
        );
      },
      tags: 'golden',
    );

    // The seventh surface, and the one the wizard exists for: a dense read-only
    // summary of all twenty-five entries, with the blanks named rather than
    // hidden. Worth pinning separately from the entry steps — those are columns
    // of fields, this is the screen an officer signs off a statutory record on.
    testWidgets(
      'the review before filing',
      (tester) async {
        await pumpRouted(
          tester,
          const FirFormScreen(),
          overrides: firOverrides(
            storage: {StorageKeys.firDraft: jsonEncode(filled)},
          ),
          afterPump: (container) async => container
              .read(firFormControllerProvider.notifier)
              .goTo(FirFormStep.review),
        );

        await expectLater(
          find.byType(FirFormScreen),
          matchesGoldenFile('images/fir_review.png'),
        );
      },
      tags: 'golden',
    );

    testWidgets(
      'empty, dark',
      (tester) async {
        await pumpRouted(
          tester,
          const FirFormScreen(),
          brightness: Brightness.dark,
          overrides: firOverrides(),
          // The form seeds the FIR date with today, so an untouched one is the
          // single thing on this page that moves with the calendar. Pinned here
          // rather than seeded through storage, which would also raise the
          // "picked up where you left off" notice over an empty form.
          //
          // Flushed rather than left to the debounce. `edit` schedules a one-second
          // autosave, and a golden that finishes inside that second tears the tree
          // down with a timer still pending — which the test binding fails on. It
          // only started biting when the pinned date stopped matching today's, at
          // which point the edit stopped being a no-op.
          afterPump: (container) async {
            final notifier = container.read(firFormControllerProvider.notifier);
            notifier.edit((d) => d.copyWith(firDate: '2026-08-09'));
            await notifier.flush();
          },
        );

        await expectLater(
          find.byType(FirFormScreen),
          matchesGoldenFile('images/fir_form_dark.png'),
        );
      },
      tags: 'golden',
    );
  });

  group('the receipt', () {
    testWidgets(
      'after filing',
      (tester) async {
        final controllerOverrides = firOverrides();

        await pumpRouted(
          tester,
          const FirSuccessScreen(),
          overrides: controllerOverrides,
          afterPump: (container) async {
            // The screen renders nothing without a receipt, and the honest way to
            // give it one is to file an FIR through the controller the screen
            // reads.
            final notifier = container.read(firFormControllerProvider.notifier);
            notifier.edit((_) => FirDraft.fromJson(filled));
            await notifier.submit();
          },
        );

        await expectLater(
          find.byType(FirSuccessScreen),
          matchesGoldenFile('images/fir_receipt.png'),
        );
      },
      tags: 'golden',
    );
  });

  group('the record viewer', () {
    // The sixth surface, and a different kind again: a read-only page of dense
    // entries with the narrative set apart from them. The history *list* is
    // deliberately not snapshotted — it is the same kind of screen as the
    // evidence list below, and pinning both would fail twice for one change to a
    // row.
    testWidgets(
      'one FIR, as records hold it',
      (tester) async {
        final repository = FakeFirRepository()..records = [goldenRecord];

        await pumpRouted(
          tester,
          const FirRecordScreen(firNo: 'FIR 41/2026'),
          overrides: [firRepositoryProvider.overrideWithValue(repository)],
        );

        await expectLater(
          find.byType(FirRecordScreen),
          matchesGoldenFile('images/fir_record.png'),
        );
      },
      tags: 'golden',
    );
  });

  group('the evidence locker', () {
    testWidgets(
      'locked',
      (tester) async {
        await pump(
          tester,
          _lockerHost(),
          overrides: [
            evidenceRepositoryProvider
                .overrideWithValue(FakeEvidenceRepository()),
          ],
        );

        await expectLater(
          find.byType(EvidenceLockerScreen),
          matchesGoldenFile('images/evidence_locked.png'),
        );
      },
      tags: 'golden',
    );

    testWidgets(
      'open, with files in it',
      (tester) async {
        await pump(
          tester,
          _lockerHost(),
          overrides: [
            evidenceRepositoryProvider
                .overrideWithValue(FakeEvidenceRepository()),
          ],
        );

        final locker = tester.element(find.byType(EvidenceLockerScreen));
        // The PIN goes to the server now; the fake above accepts its default.
        await ProviderScope.containerOf(locker)
            .read(evidenceLockControllerProvider.notifier)
            .unlock(FakeEvidenceRepository().acceptedPin);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(EvidenceLockerScreen),
          matchesGoldenFile('images/evidence_list.png'),
        );
      },
      tags: 'golden',
    );
  });
}

/// The same FIR as [filled], but as the *server* would hand it back — with the
/// three columns only it can write.
///
/// Not derived from the draft. The viewer's job is to show a stored record, and
/// building one from the form's draft here would quietly assert that the two
/// shapes are the same; they are not, which is the whole reason `FirRecord`
/// exists.
const goldenRecord = FirRecord(
  firNo: 'FIR 41/2026',
  firId: '17549023114567',
  district: 'Delhi',
  policeStation: 'North Delhi PS',
  year: '2026',
  firDate: '2026-08-09',
  actSections: 'IPC 379, IPC 411',
  occurrenceDay: 'Friday',
  occurrenceDate: '2026-08-07',
  placeOfOccurrence: 'Sector 14 market, opposite the bus stand',
  complainantName: 'Anita Sharma',
  statement: 'The complainant states that her two-wheeler, parked outside '
      'the Sector 14 market, was found missing at about 12:30 hrs on '
      '7 August 2026.',
  pdfFile: 'FIR_FIR 41/2026.pdf',
  createdAt: 'Sun, 09 Aug 2026 06:30:00 GMT',
  status: 'Saved to Police Records',
);

/// Mounts [child] inside a real router, then optionally drives the providers
/// before the snapshot is taken.
///
/// Separate from `pump` because only the FIR screens need a [GoRouter] — the
/// locker is a tab, and giving it one would put a route in a golden that has
/// none in the app.
Future<void> pumpRouted(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
  Future<void> Function(ProviderContainer container)? afterPump,
}) async {
  const logicalSize = Size(390, 844);
  const pixelRatio = 3.0;

  tester.view
    ..devicePixelRatio = pixelRatio
    ..physicalSize = logicalSize * pixelRatio;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/screen',
    routes: [
      GoRoute(path: '/screen', builder: (context, state) => child),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const Scaffold(),
      ),
      GoRoute(
        path: AppRoutes.firNew,
        name: AppRoutes.firNewName,
        builder: (context, state) => const FirFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.firSuccess,
        name: AppRoutes.firSuccessName,
        builder: (context, state) => const FirSuccessScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 47, bottom: 34),
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  if (afterPump != null) {
    await afterPump(container);
    await tester.pumpAndSettle();
  }

  await precacheBrandAssets(tester);
}

/// The locker as the dashboard hosts it.
///
/// The ambient scaffold background is navy — the auth screens are built on it —
/// and every real screen paints its own surface over the top. Snapshotting the
/// locker in a bare [Scaffold] would record it as navy-on-navy, which is a
/// picture of the harness, not of the app.
Widget _lockerHost() => Builder(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const SafeArea(child: EvidenceLockerScreen()),
      ),
    );

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/features/evidence/data/datasources/evidence_file_picker.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_form_controller.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_form_screen.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_success_screen.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_field_keys.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_proofs_field.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_evidence_repository.dart';
import 'fake_fir_repository.dart';
import 'in_memory_secure_storage.dart';

/// Mounts the FIR form with a scripted repository and an in-memory keystore.
///
/// A real [GoRouter] rather than a bare `home:`, because filing an FIR ends in a
/// route change — the form replaces itself with the receipt — and that handoff
/// is one of the things worth testing.
///
/// The app router is deliberately NOT used: its first route is the splash and
/// its redirect gates on a signed-in police session, which would put every test
/// here behind a sign-in it is not about. The role guard is the router's
/// business and is asserted where it lives.
Future<void> pumpFirForm(
  WidgetTester tester, {
  required FakeFirRepository repository,
  InMemorySecureStorage? storage,
  String initialLocation = AppRoutes.firNew,
  // The form's proof attachments file into the evidence locker once the FIR is
  // registered, so the FIR form needs both halves overridden even in tests that
  // never touch an attachment.
  FakeEvidenceRepository? evidence,
  FakeEvidenceFilePicker? picker,
}) async {
  // Taller than any real handset, so these tests are about behaviour rather than
  // about scrolling to reach a field. How it looks at 390x844 is the goldens'
  // job.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 1600);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const Scaffold(body: Text('HOME')),
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firRepositoryProvider.overrideWithValue(repository),
        evidenceRepositoryProvider
            .overrideWithValue(evidence ?? FakeEvidenceRepository()),
        evidenceFilePickerProvider
            .overrideWithValue(picker ?? FakeEvidenceFilePicker()),
        secureStorageProvider
            .overrideWithValue(storage ?? InMemorySecureStorage()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );

  // Drains the saved-draft read, which the form holds a spinner for.
  await tester.pumpAndSettle();
}

// ---- interacting with the form ---------------------------------------------

/// The [TextField] inside the control carrying [key].
///
/// Every entry is keyed (see `FirFieldKeys`) so a test can name an entry the way
/// the form does rather than by position or by hint text.
Finder firInput(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

Future<void> enterFir(WidgetTester tester, Key key, String text) async {
  await tester.enterText(firInput(key), text);
  await tester.pump();
}

/// Taps a picker or lookup field open.
Future<void> tapPicker(WidgetTester tester, Key key) async {
  await tester.tap(
    find.descendant(of: find.byKey(key), matching: find.byType(InkWell)).first,
  );
  await tester.pumpAndSettle();
}

/// Opens a lookup field and chooses [option] from the sheet.
Future<void> chooseOption(WidgetTester tester, Key key, String option) async {
  await tapPicker(tester, key);
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Opens a date picker and accepts whatever it opened on. Choosing a specific
/// day means driving the calendar grid, which tests the Material picker rather
/// than this form.
Future<void> acceptDate(WidgetTester tester, Key key) async {
  await tapPicker(tester, key);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// Adds one act-and-section pair through the sheet.
Future<void> addSection(
  WidgetTester tester, {
  required String act,
  required String section,
}) async {
  // The button renames itself once the field holds a pair, so a test adding a
  // second section must not look for the first one's wording.
  final opener = find.text('Add an act and section').evaluate().isEmpty
      ? find.text('Add another section')
      : find.text('Add an act and section');
  await tester.tap(opener);
  await tester.pumpAndSettle();

  // Reached through the sheet rather than by its hint, because the sheet offers
  // the act just used — so on a second pair it shows "IPC", not "Select an act".
  await tester.tap(
    find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(InkWell),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(act).last);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'e.g. 379, or 376(2)',
    ),
    section,
  );
  await tester.pump();

  await tester.tap(find.text('Add section'));
  await tester.pumpAndSettle();
}

// ---- moving through the wizard ---------------------------------------------

/// Advances one step. Silently does nothing if the step refuses — which is what
/// a test of validation wants to assert on, by checking where it ended up.
Future<void> firNext(WidgetTester tester) async {
  await tester.tap(find.byKey(FirFieldKeys.next));
  await tester.pumpAndSettle();
}

/// Goes back one step, using the footer's button rather than the header's arrow.
Future<void> firBack(WidgetTester tester) async {
  await tester.tap(find.byKey(FirFieldKeys.back));
  await tester.pumpAndSettle();
}

/// Which step is on screen, asserted through the body's key rather than by
/// reading the header's text — so a copy edit to "Step 2 of 4" does not break
/// every test that has to get somewhere.
Finder firStep(FirFormStep step) => find.byKey(FirFieldKeys.step(step));

/// Taps the review's Edit link for [step].
///
/// Scrolled into view first: the review prints all twenty-five entries, so the
/// later groups' links are well below the fold. Without this, `tap` aims at
/// coordinates outside the viewport and fails with a finder error that says
/// nothing about why.
Future<void> tapReviewEdit(WidgetTester tester, FirFormStep step) async {
  final edit = find.byKey(FirFieldKeys.reviewEdit(step));
  await tester.scrollUntilVisible(edit, 300);
  await tester.pumpAndSettle();
  await tester.tap(edit);
  await tester.pumpAndSettle();
}

/// Fills every required entry and stops on the review, ready to file.
///
/// The FIR date is not touched: the form seeds it with today, which is the
/// behaviour a test of "the required entries" should be relying on. Nothing on
/// step 2 is touched either — none of it is required, and a helper that filled
/// it would hide a regression that made one of them mandatory.
Future<void> fillMinimalFir(
  WidgetTester tester, {
  String firNo = 'FIR001',
  String district = 'Delhi',
  String station = 'North Delhi PS',
}) async {
  // Step 1 — registration.
  await enterFir(tester, FirFieldKeys.firNo, firNo);
  await chooseOption(tester, FirFieldKeys.district, district);
  await chooseOption(tester, FirFieldKeys.policeStation, station);
  await addSection(tester, act: 'IPC', section: '379');
  await firNext(tester);

  // Step 2 — occurrence. Nothing here is required.
  await firNext(tester);

  // Step 3 — the complainant.
  await enterFir(tester, FirFieldKeys.complainantName, 'A. Sharma');
  await firNext(tester);

  // Step 4 — the complaint.
  await enterFir(
    tester,
    FirFieldKeys.statement,
    'Two-wheeler taken from outside the market at around noon.',
  );
  await firNext(tester);
}

/// Walks to step 4 without filling anything, for a test about the attachments
/// rather than about the entries.
///
/// Steps 1 to 3 have required entries and Next refuses without them, so the
/// walk fills exactly those and nothing else.
Future<void> goToComplaintStep(WidgetTester tester) async {
  await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
  await chooseOption(tester, FirFieldKeys.district, 'Delhi');
  await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
  await firNext(tester);
  await firNext(tester);
  await enterFir(tester, FirFieldKeys.complainantName, 'A. Sharma');
  await firNext(tester);
}

/// [fillMinimalFir], but attaching one proof file on step 4 before moving on.
///
/// Separate from [fillMinimalFir] rather than a flag on it: every other test
/// that fills the form would then be silently filing an attachment too, and an
/// upload appearing in a fake it never asked about is how a passing test stops
/// meaning anything.
Future<void> fillMinimalFirWithProof(WidgetTester tester) async {
  await enterFir(tester, FirFieldKeys.firNo, 'FIR001');
  await chooseOption(tester, FirFieldKeys.district, 'Delhi');
  await chooseOption(tester, FirFieldKeys.policeStation, 'North Delhi PS');
  await addSection(tester, act: 'IPC', section: '379');
  await firNext(tester);
  await firNext(tester);
  await enterFir(tester, FirFieldKeys.complainantName, 'A. Sharma');
  await firNext(tester);

  await enterFir(
    tester,
    FirFieldKeys.statement,
    'Two-wheeler taken from outside the market at around noon.',
  );
  await tester.tap(find.byKey(FirProofKeys.attach));
  await tester.pumpAndSettle();
  await tester.tap(find.text(EvidenceSource.camera.label));
  await tester.pumpAndSettle();

  await firNext(tester);
}

/// Presses the one button that files it. Only on the review.
Future<void> tapFile(WidgetTester tester) async {
  await tester.tap(find.byKey(FirFieldKeys.submit));
  await tester.pumpAndSettle();
}

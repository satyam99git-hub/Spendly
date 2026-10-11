import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/features/complaints/presentation/controllers/complaint_filter_controller.dart';
import 'package:nayaya_app/features/complaints/presentation/controllers/complaint_providers.dart';
import 'package:nayaya_app/features/complaints/presentation/controllers/complaint_write.dart';
import 'package:nayaya_app/features/complaints/presentation/screens/complaint_detail_screen.dart';
import 'package:nayaya_app/features/complaints/presentation/screens/complaints_inbox_screen.dart';
import 'package:nayaya_app/features/complaints/presentation/widgets/complaint_keys.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_providers.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_form_screen.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_complaint_repository.dart';
import 'fake_fir_repository.dart';
import 'in_memory_secure_storage.dart';

/// The clock every date filter in these tests is measured against.
///
/// Pinned, because "Today" is otherwise whatever day the suite happens to run
/// on — and a test of a date filter that passes in August and fails in September
/// is worse than no test.
final testNow = DateTime.utc(2026, 8, 9, 6, 30);

/// Who these tests are signed in as. Every note the app writes is signed with
/// this, so an assertion about the trail can name it.
const testOfficer = 'SI K. Deshmukh';

/// Mounts the complaints inbox and the detail screen with a scripted repository.
///
/// A real [GoRouter] rather than a bare `home:`, because opening a complaint is
/// a route change carrying a path parameter, and "Register FIR takes the officer
/// to the form with the complaint already in it" is a route change too — both
/// are among the things most worth testing here.
///
/// The app router is deliberately not used, for the same reason as
/// `pumpFirHistory`: its first route is the splash and its redirect gates on a
/// signed-in police session, which would put every test behind a sign-in it is
/// not about. The role guard is the router's business and is asserted where it
/// lives, in `fir_route_guard_test.dart`.
Future<void> pumpComplaints(
  WidgetTester tester, {
  required FakeComplaintRepository repository,
  FakeFirRepository? firRepository,
  InMemorySecureStorage? storage,
  String initialLocation = AppRoutes.home,
}) async {
  // Taller than any real handset, so these tests are about behaviour rather than
  // about scrolling to reach a row. How it looks at 390x844 is the goldens' job.
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
        // The inbox on its own rather than inside the police console: the
        // console's other two tabs would drag the FIR and evidence features
        // into every assertion about a complaint.
        builder: (context, state) => const Scaffold(
          body: SafeArea(child: ComplaintsInboxScreen()),
        ),
      ),
      GoRoute(
        path: AppRoutes.complaintDetail,
        name: AppRoutes.complaintDetailName,
        builder: (context, state) => ComplaintDetailScreen(
          trackingId: state.pathParameters['trackingId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.firNew,
        name: AppRoutes.firNewName,
        builder: (context, state) => const FirFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.firRecord,
        name: AppRoutes.firRecordName,
        builder: (context, state) => Scaffold(
          body: Text('FIR RECORD ${state.pathParameters['firNo']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        complaintRepositoryProvider.overrideWithValue(repository),
        complaintClockProvider.overrideWithValue(() => testNow),
        // The signature on every note the app writes. Overridden rather than
        // reached through a real session: building the auth controller starts a
        // restore and the splash hold behind it, which none of these tests are
        // about and all of them would have to wait on.
        complaintAuthorProvider.overrideWithValue(testOfficer),
        firRepositoryProvider
            .overrideWithValue(firRepository ?? FakeFirRepository()),
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

  // Drains the inbox fetch, which the list holds a spinner for.
  await tester.pumpAndSettle();
}

// ---- getting around ---------------------------------------------------------

/// Opens the complaint with [trackingId] from the inbox.
///
/// By its key rather than its text, so a change to what a row prints does not
/// break every test that has to get past the list first.
Future<void> openComplaint(WidgetTester tester, String trackingId) async {
  await tester.tap(find.byKey(ComplaintKeys.tile(trackingId)));
  await tester.pumpAndSettle();
}

/// Types into the inbox's search box.
Future<void> searchComplaints(WidgetTester tester, String query) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(ComplaintKeys.search),
      matching: find.byType(TextField),
    ),
    query,
  );
  await tester.pumpAndSettle();
}

/// Taps a stage chip — All, Active, Pending, Under review, FIR filed, Closed.
///
/// Scrolled into view first, because the six of them do not fit across a handset
/// and the row scrolls sideways. Without this, `tap` aims at coordinates outside
/// the viewport and quietly hits whatever is there instead — a filter that
/// silently does not apply, and a test that fails a long way from its cause.
Future<void> selectStage(WidgetTester tester, String stageName) async {
  final chip = find.byKey(ComplaintKeys.stageChip(stageName));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// The container behind the mounted app, for the handful of assertions that are
/// about state rather than about pixels — what the FIR draft holds after a
/// conversion, for one, which no widget prints in full.
ProviderContainer complaintsContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Opens the date sheet and picks a preset.
Future<void> selectDatePreset(WidgetTester tester, String presetName) async {
  await tester.tap(find.byKey(ComplaintKeys.filterButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ComplaintKeys.datePreset(presetName)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ComplaintKeys.filterApply));
  await tester.pumpAndSettle();
}

/// The [TextField] inside the sheet control carrying [key].
///
/// Every box in both sheets is keyed (see `ComplaintKeys`) so a test can name
/// one the way the sheet does rather than by hint text.
Finder complaintInput(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

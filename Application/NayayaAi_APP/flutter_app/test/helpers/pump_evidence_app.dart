import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/evidence/presentation/screens/evidence_add_screen.dart';
import 'package:nayaya_app/features/evidence/presentation/screens/evidence_detail_screen.dart';
import 'package:nayaya_app/features/evidence/presentation/screens/evidence_locker_screen.dart';
import 'package:nayaya_app/features/evidence/presentation/widgets/evidence_keys.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_providers.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_evidence_repository.dart';
import 'fake_fir_repository.dart';

/// Mounts the evidence locker with a scripted repository and file picker.
///
/// A real [GoRouter], because Add and Detail are pushed routes and the
/// list→add→list round trip is one of the things worth testing. The app router
/// is deliberately not used — its redirect gates on a signed-in police session,
/// which is the route guard's business and is asserted where that lives.
///
/// [firRepository] backs the Add screen's *Choose from history* sheet. It is
/// optional and empty by default: most of these tests are about the locker, and
/// an empty history is what the sheet shows when the station has filed nothing —
/// never a crash, and never a reason the file cannot be uploaded by typing the
/// number.
Future<void> pumpEvidenceLocker(
  WidgetTester tester, {
  required FakeEvidenceRepository repository,
  FakeEvidenceFilePicker? picker,
  FakeFirRepository? firRepository,
  String initialLocation = _lockerPath,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: _lockerPath,
        builder: (context, state) => const Scaffold(
          body: SafeArea(child: EvidenceLockerScreen()),
        ),
      ),
      GoRoute(
        path: AppRoutes.evidenceAdd,
        name: AppRoutes.evidenceAddName,
        builder: (context, state) => const EvidenceAddScreen(),
      ),
      GoRoute(
        path: AppRoutes.evidenceDetail,
        name: AppRoutes.evidenceDetailName,
        builder: (context, state) => EvidenceDetailScreen(
          firNo: state.pathParameters['firNo'] ?? '',
          filename: state.pathParameters['filename'] ?? '',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        evidenceRepositoryProvider.overrideWithValue(repository),
        evidenceFilePickerProvider
            .overrideWithValue(picker ?? FakeEvidenceFilePicker()),
        firRepositoryProvider
            .overrideWithValue(firRepository ?? FakeFirRepository()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// The locker has no route of its own in the app — it is the Evidence tab's two
/// states inside `/home`. Tests need somewhere to mount it, so they get this.
const _lockerPath = '/test-locker';

/// Types [pin] into the gate and presses Unlock.
Future<void> enterPin(WidgetTester tester, String pin) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(EvidenceKeys.pinField),
      matching: find.byType(TextField),
    ),
    pin,
  );
  await tester.pump();
  await tester.tap(find.byKey(EvidenceKeys.pinSubmit));
  await tester.pumpAndSettle();
}

/// The PIN [FakeEvidenceRepository] accepts, which stands in for the one the
/// server holds. Named here so a test that needs a *wrong* PIN can be sure it
/// is picking one.
const lockerPin = 'secure@123';

/// Opens the locker with the PIN the server accepts.
Future<void> unlockLocker(WidgetTester tester) => enterPin(tester, lockerPin);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/citizen/presentation/controllers/citizen_providers.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/citizen_missing_person_detail_screen.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/citizen_shell.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/missing_persons/presentation/controllers/missing_person_providers.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_auth_repository.dart';
import 'fake_citizen_repositories.dart';
import 'fake_evidence_repository.dart';
import 'fake_missing_person_repository.dart';
import 'in_memory_secure_storage.dart';
import 'pump_app.dart';

/// Everything a citizen test may want to reach into after pumping.
class CitizenHarness {
  CitizenHarness({
    FakeCitizenComplaintRepository? complaints,
    FakeRightsChatRepository? rights,
    FakeCaseStatusRepository? cases,
    FakeMissingPersonRepository? missing,
    FakeEvidenceFilePicker? picker,
    FakeAuthRepository? auth,
  })  : complaints = complaints ?? FakeCitizenComplaintRepository(),
        rights = rights ?? FakeRightsChatRepository(),
        cases = cases ?? FakeCaseStatusRepository(),
        missing = missing ?? FakeMissingPersonRepository(),
        picker = picker ?? FakeEvidenceFilePicker(),
        auth = auth ?? FakeAuthRepository();

  final FakeCitizenComplaintRepository complaints;
  final FakeRightsChatRepository rights;
  final FakeCaseStatusRepository cases;
  final FakeMissingPersonRepository missing;
  final FakeEvidenceFilePicker picker;
  final FakeAuthRepository auth;
}

/// Mounts the Citizen Portal on `/home`, with the citizen detail route beside
/// it, over fakes for every endpoint it can reach.
Future<CitizenHarness> pumpCitizenApp(
  WidgetTester tester, {
  CitizenHarness? harness,
  Size size = const Size(400, 2400),
  double textScale = 1.0,
}) async {
  final h = harness ?? CitizenHarness();

  // A phone-width portrait viewport, tall enough that long sections do not
  // push the widget under test off-screen.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const Scaffold(body: Text('LOGIN')),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const CitizenShell(),
      ),
      GoRoute(
        path: AppRoutes.citizenMissingPerson,
        name: AppRoutes.citizenMissingPersonName,
        builder: (context, state) => CitizenMissingPersonDetailScreen(
          personId: state.pathParameters['personId'] ?? '',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(h.auth),
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        citizenComplaintRepositoryProvider.overrideWithValue(h.complaints),
        rightsChatRepositoryProvider.overrideWithValue(h.rights),
        caseStatusRepositoryProvider.overrideWithValue(h.cases),
        missingPersonRepositoryProvider.overrideWithValue(h.missing),
        evidenceFilePickerProvider.overrideWithValue(h.picker),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
      ),
    ),
  );
  await settleStartup(tester);
  await tester.pumpAndSettle();
  return h;
}

/// Opens the drawer and picks [label] — the website's sidebar link.
Future<void> openCitizenSection(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(Drawer), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/lawyer/presentation/controllers/lawyer_providers.dart';
import 'package:nayaya_app/features/lawyer/presentation/screens/lawyer_shell.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_auth_repository.dart';
import 'fake_evidence_repository.dart';
import 'fake_lawyer_repository.dart';
import 'in_memory_secure_storage.dart';
import 'pump_app.dart';

/// Everything a lawyer test may want to reach into after pumping.
class LawyerHarness {
  LawyerHarness({
    FakeLawyerRepository? lawyer,
    FakeEvidenceFilePicker? picker,
    FakeAuthRepository? auth,
  })  : lawyer = lawyer ?? FakeLawyerRepository(),
        picker = picker ?? FakeEvidenceFilePicker(),
        auth = auth ?? FakeAuthRepository();

  final FakeLawyerRepository lawyer;
  final FakeEvidenceFilePicker picker;
  final FakeAuthRepository auth;
}

/// Mounts the Lawyer Portal on `/home` over fakes for every endpoint.
Future<LawyerHarness> pumpLawyerApp(
  WidgetTester tester, {
  LawyerHarness? harness,
  Size size = const Size(400, 2400),
}) async {
  final h = harness ?? LawyerHarness();

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
        builder: (context, state) => const LawyerShell(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(h.auth),
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        lawyerRepositoryProvider.overrideWithValue(h.lawyer),
        evidenceFilePickerProvider.overrideWithValue(h.picker),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await settleStartup(tester);
  await tester.pumpAndSettle();
  return h;
}

/// Opens the drawer and picks [label] — the page's sidebar link.
Future<void> openLawyerSection(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(Drawer), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

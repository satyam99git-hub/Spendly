import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/judge/presentation/controllers/judge_providers.dart';
import 'package:nayaya_app/features/judge/presentation/screens/judge_shell.dart';
import 'package:nayaya_app/features/legal/presentation/controllers/legal_providers.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_auth_repository.dart';
import 'fake_judge_repository.dart';
import 'fake_legal_repository.dart';
import 'in_memory_secure_storage.dart';
import 'pump_app.dart';

/// Everything a judge test may want to reach into after pumping.
class JudgeHarness {
  JudgeHarness({
    FakeJudgeRepository? judge,
    FakeLegalRepository? legal,
    FakeAuthRepository? auth,
    InMemorySecureStorage? storage,
  })  : judge = judge ?? FakeJudgeRepository(),
        legal = legal ?? FakeLegalRepository(),
        auth = auth ?? FakeAuthRepository(),
        storage = storage ?? InMemorySecureStorage();

  final FakeJudgeRepository judge;
  final FakeLegalRepository legal;
  final FakeAuthRepository auth;
  final InMemorySecureStorage storage;
}

/// Mounts the Judge Portal on `/home` over fakes for every endpoint.
Future<JudgeHarness> pumpJudgeApp(
  WidgetTester tester, {
  JudgeHarness? harness,
  Size size = const Size(400, 2400),
}) async {
  final h = harness ?? JudgeHarness();

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
        builder: (context, state) => const JudgeShell(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(h.auth),
        secureStorageProvider.overrideWithValue(h.storage),
        judgeRepositoryProvider.overrideWithValue(h.judge),
        legalRepositoryProvider.overrideWithValue(h.legal),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  // The portal itself never reads the session, so start the auth controller
  // here, as the app does before `/home` is reachable — otherwise its startup
  // hold would begin on the first sign-out tap, mid-test.
  ProviderScope.containerOf(tester.element(find.byType(JudgeShell)))
      .read(authControllerProvider);
  await settleStartup(tester);
  await tester.pumpAndSettle();
  return h;
}

/// Opens the drawer and picks [label] — the page's sidebar link.
Future<void> openJudgeSection(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(Drawer), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

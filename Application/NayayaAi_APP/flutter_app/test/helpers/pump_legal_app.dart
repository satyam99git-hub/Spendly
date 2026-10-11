import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/features/legal/presentation/controllers/legal_providers.dart';
import 'package:nayaya_app/features/legal/presentation/screens/ask_law_screen.dart';
import 'package:nayaya_app/features/legal/presentation/screens/law_library_screen.dart';
import 'package:nayaya_app/features/legal/presentation/screens/law_outcome_screen.dart';
import 'package:nayaya_app/features/legal/presentation/screens/law_reference_screen.dart';
import 'package:nayaya_app/features/legal/presentation/screens/law_section_screen.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_legal_repository.dart';

/// Mounts the law screens over a scripted repository.
///
/// Its own router rather than the app's: the real one redirects on auth state,
/// and a law-library test has no business signing anybody in to look at a list
/// of sections. The route *names* are the app's, so a rename breaks these too.
Future<void> pumpLawScreen(
  WidgetTester tester, {
  required FakeLegalRepository repository,
  String initialLocation = AppRoutes.lawLibrary,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 1600);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.lawLibrary,
        name: AppRoutes.lawLibraryName,
        builder: (context, state) => const LawLibraryScreen(),
        routes: [
          GoRoute(
            path: 'ask',
            name: AppRoutes.lawAskName,
            builder: (context, state) => const AskLawScreen(),
          ),
          GoRoute(
            path: 'outcome',
            name: AppRoutes.lawOutcomeName,
            builder: (context, state) => const LawOutcomeScreen(),
          ),
          GoRoute(
            path: 'reference',
            name: AppRoutes.lawReferenceName,
            builder: (context, state) => const LawReferenceScreen(),
          ),
          GoRoute(
            path: 'section/:act/:section',
            name: AppRoutes.lawSectionName,
            builder: (context, state) => LawSectionScreen(
              act: state.pathParameters['act'] ?? '',
              section: state.pathParameters['section'] ?? '',
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        legalRepositoryProvider.overrideWithValue(repository),
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

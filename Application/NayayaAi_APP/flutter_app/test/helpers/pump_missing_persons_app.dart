import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/missing_persons/presentation/controllers/missing_person_providers.dart';
import 'package:nayaya_app/features/missing_persons/presentation/screens/missing_person_detail_screen.dart';
import 'package:nayaya_app/features/missing_persons/presentation/screens/missing_person_form_screen.dart';
import 'package:nayaya_app/features/missing_persons/presentation/screens/missing_persons_screen.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_evidence_repository.dart';
import 'fake_missing_person_repository.dart';

/// Mounts the missing-persons screens over a scripted repository and picker.
///
/// The photograph is the whole feature, so the picker is overridden in every
/// test whether or not it is used: a real one needs a platform channel, and a
/// screen that could not build is a screen no test can say anything about.
Future<void> pumpMissingPersons(
  WidgetTester tester, {
  required FakeMissingPersonRepository repository,
  FakeEvidenceFilePicker? picker,
  String initialLocation = AppRoutes.missingPersons,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 1800);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.missingPersons,
        name: AppRoutes.missingPersonsName,
        builder: (context, state) => const MissingPersonsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            name: AppRoutes.missingPersonNewName,
            builder: (context, state) => const MissingPersonFormScreen(),
          ),
          GoRoute(
            path: ':personId',
            name: AppRoutes.missingPersonName,
            builder: (context, state) => MissingPersonDetailScreen(
              personId: state.pathParameters['personId'] ?? '',
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
        missingPersonRepositoryProvider.overrideWithValue(repository),
        evidenceFilePickerProvider
            .overrideWithValue(picker ?? FakeEvidenceFilePicker()),
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

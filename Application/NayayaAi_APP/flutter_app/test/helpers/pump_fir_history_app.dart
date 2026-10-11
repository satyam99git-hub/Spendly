import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_record.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_providers.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_history_screen.dart';
import 'package:nayaya_app/features/fir/presentation/screens/fir_record_screen.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_fir_pdf_store.dart';
import 'fake_fir_repository.dart';

/// Mounts the history list and the record viewer with a scripted repository and
/// a PDF store that writes to a temp directory.
///
/// A real [GoRouter] rather than a bare `home:`, because opening a record is a
/// route change carrying a path parameter — and "the row I tapped is the FIR the
/// viewer asked the server for" is one of the things worth testing.
///
/// The app router is deliberately not used, for the same reason as
/// `pumpFirForm`: its first route is the splash and its redirect gates on a
/// signed-in police session. The role guard is the router's business and is
/// asserted where it lives.
Future<void> pumpFirHistory(
  WidgetTester tester, {
  required FakeFirRepository repository,
  FakeFirPdfStore? pdfStore,
  String initialLocation = AppRoutes.firHistory,
}) async {
  // Taller than any real handset, so these tests are about behaviour rather than
  // about scrolling to reach a row.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 1600);
  addTearDown(tester.view.reset);

  final store = pdfStore ?? FakeFirPdfStore();
  addTearDown(store.dispose);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: AppRoutes.firHistory,
        name: AppRoutes.firHistoryName,
        builder: (context, state) => const FirHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.firRecord,
        name: AppRoutes.firRecordName,
        builder: (context, state) => FirRecordScreen(
          firNo: state.pathParameters['firNo'] ?? '',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firRepositoryProvider.overrideWithValue(repository),
        firPdfStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );

  // Drains the history fetch, which the list holds a spinner for.
  await tester.pumpAndSettle();
}

/// Opens the record with [firNo] from the list.
///
/// Found by the number as the row writes it — `FirRecord.label` does not prefix
/// a number that already says FIR — so this helper cannot drift from the tile.
Future<void> openRecord(WidgetTester tester, String firNo) async {
  await tester.tap(find.text(FirRecord.label(firNo)));
  await tester.pumpAndSettle();
}

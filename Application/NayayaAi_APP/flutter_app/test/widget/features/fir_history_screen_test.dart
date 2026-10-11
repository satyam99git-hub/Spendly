import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/fir/data/datasources/fir_pdf_store.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_history_keys.dart';
import 'package:nayaya_app/routes/app_routes.dart';

import '../../helpers/fake_fir_pdf_store.dart';
import '../../helpers/fake_fir_repository.dart';
import '../../helpers/fir_records.dart';
import '../../helpers/pump_fir_history_app.dart';

/// The history list and the record viewer, from an officer's side of them.
void main() {
  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(FirHistoryKeys.search),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pumpAndSettle();
  }

  group('the history list', () {
    testWidgets('shows a row per FIR, in the order the repository returned',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [
          aFirRecord(firNo: 'FIR003'),
          aFirRecord(firNo: 'FIR002'),
          aFirRecord(firNo: 'FIR001'),
        ];

      await pumpFirHistory(tester, repository: repository);

      expect(find.byKey(FirHistoryKeys.tile('FIR003')), findsOneWidget);
      expect(find.byKey(FirHistoryKeys.tile('FIR001')), findsOneWidget);

      // Ordering is the repository's job — asserted against the server's replies
      // in the unit suite. What matters here is that the screen does not reorder
      // what it was handed.
      final numbers = tester
          .widgetList<Text>(find.textContaining('FIR00'))
          .map((t) => t.data)
          .toList();
      expect(numbers, ['FIR003', 'FIR002', 'FIR001']);
    });

    testWidgets('shows who reported it, where, and what it was filed under',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [
          aFirRecord(
            complainantName: 'A. Sharma',
            policeStation: 'North Delhi PS',
            actSections: 'IPC 379, IPC 411',
          ),
        ];

      await pumpFirHistory(tester, repository: repository);

      expect(find.text('A. Sharma · North Delhi PS'), findsOneWidget);
      expect(find.text('IPC 379'), findsOneWidget);
      expect(find.text('IPC 411'), findsOneWidget);
      expect(find.text('9 Aug 2026'), findsOneWidget);
    });

    testWidgets('filters on the number, the name and the section',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [
          aFirRecord(firNo: 'FIR001', complainantName: 'A. Sharma'),
          aFirRecord(
            firNo: 'FIR002',
            complainantName: 'R. Iyer',
            actSections: 'IPC 420',
          ),
        ];

      await pumpFirHistory(tester, repository: repository);

      await typeSearch(tester, 'iyer');
      expect(find.byKey(FirHistoryKeys.tile('FIR002')), findsOneWidget);
      expect(find.byKey(FirHistoryKeys.tile('FIR001')), findsNothing);

      await typeSearch(tester, '420');
      expect(find.byKey(FirHistoryKeys.tile('FIR002')), findsOneWidget);

      await typeSearch(tester, 'FIR001');
      expect(find.byKey(FirHistoryKeys.tile('FIR001')), findsOneWidget);
      expect(find.byKey(FirHistoryKeys.tile('FIR002')), findsNothing);
    });

    // The no-match state names the query, so it is clear the list is filtered
    // rather than empty — two states that look identical without the words.
    testWidgets('says what matched nothing, and offers a way back',
        (tester) async {
      final repository = FakeFirRepository()..records = [aFirRecord()];

      await pumpFirHistory(tester, repository: repository);
      await typeSearch(tester, 'zzz');

      expect(find.text('Nothing matches “zzz”'), findsOneWidget);
      expect(find.byKey(FirHistoryKeys.tile('FIR001')), findsNothing);
    });

    testWidgets('an empty collection reads as an empty station, not a fault',
        (tester) async {
      await pumpFirHistory(tester, repository: FakeFirRepository());

      expect(find.text('No FIRs on record'), findsOneWidget);
    });

    testWidgets('shows the failure the server gave', (tester) async {
      final repository = FakeFirRepository()
        ..historyFailure = const NetworkFailure(
          message: 'Cannot reach the NyayaAI server.',
        );

      await pumpFirHistory(tester, repository: repository);

      expect(find.text('Police records could not be loaded'), findsOneWidget);
      expect(find.text('Cannot reach the NyayaAI server.'), findsOneWidget);
    });

    testWidgets('pull-to-refresh asks the server again', (tester) async {
      final repository = FakeFirRepository()..records = [aFirRecord()];

      await pumpFirHistory(tester, repository: repository);

      await tester.fling(
        find.byKey(FirHistoryKeys.list),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      // A colleague filed one while this list was on screen.
      expect(find.byKey(FirHistoryKeys.tile('FIR001')), findsOneWidget);
    });
  });

  group('opening a record', () {
    testWidgets('asks the server for the FIR whose row was tapped',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [aFirRecord(firNo: 'FIR001'), aFirRecord(firNo: 'FIR002')];

      await pumpFirHistory(tester, repository: repository);
      await openRecord(tester, 'FIR002');

      // Not handed the record from the list: the viewer re-reads it, so it shows
      // what the server holds now and can rebuild itself from its URL.
      expect(repository.recordLookups, ['FIR002']);
      expect(find.text('FORM IF-1 · FIRST INFORMATION REPORT'), findsOneWidget);
    });

    testWidgets('shows the entries that were filled in', (tester) async {
      final repository = FakeFirRepository()..records = [aFirRecord()];

      await pumpFirHistory(tester, repository: repository);
      await openRecord(tester, 'FIR001');

      expect(find.text('North Delhi PS'), findsOneWidget);
      expect(find.text('A. Sharma'), findsOneWidget);
      expect(find.text('9 Aug 2026'), findsOneWidget);
      expect(find.text('Sector 14 market'), findsOneWidget);
      expect(
        find.text('Two-wheeler taken from outside the market at noon.'),
        findsOneWidget,
      );
      expect(find.text('Recorded 9 Aug 2026, 06:30 UTC'), findsOneWidget);
    });

    // A short-format FIR leaves eighteen of the twenty-seven blank. Printing
    // them all would read as a record filed badly rather than briefly.
    testWidgets('hides the entries that were left blank', (tester) async {
      final repository = FakeFirRepository()..records = [aFirRecord()];

      await pumpFirHistory(tester, repository: repository);
      await openRecord(tester, 'FIR001');

      expect(find.text('Passport number'), findsNothing);
      expect(find.text('Father / husband'), findsNothing);
      expect(find.text('General diary reference'), findsNothing);
      // Said once, at the bottom, instead of nineteen times up the page.
      expect(
        find.text('Entries left blank at the station are not shown.'),
        findsOneWidget,
      );
    });

    // The other half of that argument: a record filed at the desk carries the
    // eighteen, and dropping them would be showing less than was filed.
    testWidgets('shows the entries only the desk records', (tester) async {
      final repository = FakeFirRepository()..records = [aDeskFiledRecord()];

      await pumpFirHistory(tester, repository: repository);
      await openRecord(tester, 'FIR900');

      expect(find.text('GD 114/2026'), findsOneWidget);
      expect(find.text('21:15 hrs'), findsOneWidget);
      expect(find.text('S. Iyer'), findsOneWidget);
      expect(find.text('Z1234567'), findsOneWidget);

      // A record with all 27 entries is longer than any handset, so the last
      // block is below the fold. Scrolling to it is part of what is being
      // asserted: it is there to be reached.
      await tester.scrollUntilVisible(
        find.text('Two men, one known to the complainant'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Two men, one known to the complainant'),
        findsOneWidget,
      );
      expect(find.text('Cash, ₹40,000'), findsOneWidget);
    });

    testWidgets('a number that names no record says so plainly',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [aFirRecord(firNo: 'FIR001')];

      await pumpFirHistory(
        tester,
        repository: repository,
        initialLocation: '${AppRoutes.firPrefix}/record/FIR404',
      );

      expect(find.text('No such FIR in police records'), findsOneWidget);
      expect(find.text('FIR record FIR404 not found'), findsOneWidget);
    });
  });

  group('downloading the PDF', () {
    testWidgets('fetches it to the store\'s path and opens it', (tester) async {
      final repository = FakeFirRepository()..records = [aFirRecord()];
      final store = FakeFirPdfStore();

      await pumpFirHistory(tester, repository: repository, pdfStore: store);
      await openRecord(tester, 'FIR001');
      await tester.tap(find.byKey(FirHistoryKeys.download));
      await tester.pumpAndSettle();

      expect(repository.downloads.single.firNo, 'FIR001');
      expect(repository.downloads.single.savePath, store.paths.single);
      expect(File(store.paths.single).existsSync(), isTrue);
      expect(store.opens, [store.paths.single]);

      // Nothing to say when the PDF opened: the viewer is already on screen, and
      // a message behind it is either invisible or stale by the time it is read.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a double-tap downloads once', (tester) async {
      final repository = FakeFirRepository()
        ..records = [aFirRecord()]
        ..delay = const Duration(milliseconds: 200);

      await pumpFirHistory(tester, repository: repository);
      await openRecord(tester, 'FIR001');

      await tester.tap(find.byKey(FirHistoryKeys.download));
      await tester.pump();
      await tester.tap(
        find.byKey(FirHistoryKeys.download),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(repository.downloads, hasLength(1));
    });

    // Nothing stops an officer pressing back mid-download, and nothing should.
    // The controller is autoDispose, so the pop tears it down while the fetch is
    // in flight — and writing state to a disposed notifier throws.
    testWidgets('leaving the record mid-download is not an error',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [aFirRecord()]
        ..delay = const Duration(milliseconds: 300);

      await pumpFirHistory(tester, repository: repository);
      await openRecord(tester, 'FIR001');
      await tester.tap(find.byKey(FirHistoryKeys.download));
      await tester.pump();

      // Back out while it runs, then let the download land on a screen that is
      // no longer there.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(FirHistoryKeys.list), findsOneWidget);
    });

    // Downloaded but unopenable is not a failed download, and must not be
    // reported as one — the officer needs a viewer, not another attempt.
    testWidgets('says where the file is when nothing can open it',
        (tester) async {
      final repository = FakeFirRepository()..records = [aFirRecord()];
      final store = FakeFirPdfStore(outcome: FirPdfOpenOutcome.noViewer);

      await pumpFirHistory(tester, repository: repository, pdfStore: store);
      await openRecord(tester, 'FIR001');
      await tester.tap(find.byKey(FirHistoryKeys.download));
      await tester.pumpAndSettle();

      // Named, not just "saved": an officer who has to go and find the file
      // needs to know what it is called.
      expect(
        find.text(
          'Saved as FIR_FIR001.pdf, but this handset has no app that opens '
          'PDFs.',
        ),
        findsOneWidget,
      );
      expect(File(store.paths.single).existsSync(), isTrue);
    });

    // The common case for a record filed on another machine.
    testWidgets('explains a PDF the station server does not have',
        (tester) async {
      final repository = FakeFirRepository()
        ..records = [aFirRecord()]
        ..downloadFailure = const ValidationFailure(
          'The station server has no PDF for this FIR.',
        );
      final store = FakeFirPdfStore();

      await pumpFirHistory(tester, repository: repository, pdfStore: store);
      await openRecord(tester, 'FIR001');
      await tester.tap(find.byKey(FirHistoryKeys.download));
      await tester.pumpAndSettle();

      expect(
        find.text('The station server has no PDF for this FIR.'),
        findsOneWidget,
      );
      // Nothing was fetched, so nothing was handed to a viewer.
      expect(store.opens, isEmpty);
    });
  });
}

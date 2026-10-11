@Tags(['live'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/legal/data/datasources/legal_remote_data_source.dart';

import 'live_dio.dart';

/// Contract tests for the law library and the two legal-AI surfaces, against a
/// RUNNING NyayaAI server.
///
/// These are the endpoints whose shapes are least like each other, and the unit
/// suite can only prove the app reads the shapes it was told about:
///
///   - `/api/sections/<act>` answers a paginated envelope whose `section` is a
///     **number**, not a string;
///   - `/api/search-sections` answers a bare array with an `act` on each row and
///     no description at all;
///   - `/api/section-detail` answers one row with no `act`;
///   - `/api/predict-outcome` answers HTML in `prediction` and the data the app
///     actually reads in `results`, a key added to the handler for this app.
///
/// Read-only. Unlike the FIR and evidence suites this writes nothing, so there
/// is no cleanup.
///
///   flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
void main() {
  late Dio dio;
  late LegalRemoteDataSource remote;

  setUpAll(() {
    dio = createLiveDio();
    remote = LegalRemoteDataSource(dio);
  });

  tearDownAll(() => dio.close(force: true));

  group('the acts', () {
    test('are the eight the section tables are keyed by', () async {
      expect(
        await remote.acts(),
        ['IPC', 'CRPC', 'NIA', 'IEA', 'HMA', 'CPC', 'IDA', 'MVA'],
      );
    });
  });

  group('browsing one act', () {
    test('answers a page, and says how many there are', () async {
      final page = await remote.sections('IPC', limit: 5);

      expect(page.act, 'IPC');
      expect(page.sections, hasLength(5));
      expect(page.page, 1);
      // The IPC is 575 sections; the exact figure is the database's, so only
      // the shape of the claim is asserted.
      expect(page.total, greaterThan(100));
      expect(page.pages, greaterThan(1));
      expect(page.hasMore, isTrue);
    });

    // The column is an INTEGER and arrives as a JSON number. A model that cast
    // it to String would throw on the first row of the first page.
    test('a section number arrives as a number and is read as text', () async {
      final page = await remote.sections('IPC', limit: 1);
      final first = page.sections.single;

      expect(first.section, isNotEmpty);
      expect(int.tryParse(first.section), isNotNull);
      expect(first.act, 'IPC');
      expect(first.title, isNotEmpty);
      // Unlike a cross-act search hit, a row from here carries its text.
      expect(first.isSummary, isFalse);
    });

    test('the second page is different sections from the first', () async {
      final one = await remote.sections('IPC', limit: 5);
      final two = await remote.sections('IPC', limit: 5, page: 2);

      expect(two.page, 2);
      expect(
        two.sections.map((s) => s.section),
        isNot(anyElement(isIn(one.sections.map((s) => s.section)))),
      );
    });

    test('search narrows the act', () async {
      final all = await remote.sections('IPC', limit: 1);
      final theft = await remote.sections('IPC', search: 'theft', limit: 50);

      expect(theft.total, lessThan(all.total));
      expect(theft.sections, isNotEmpty);
      expect(
        theft.sections.any((s) => s.title.toLowerCase().contains('theft')),
        isTrue,
      );
    });

    test('an act the tables do not have is refused, in the server\'s words',
        () async {
      await expectLater(
        remote.sections('NOTANACT'),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            contains('Invalid act'),
          ),
        ),
      );
    });
  });

  group('one section', () {
    test('reads back in full', () async {
      final section = await remote.section('IPC', '379');

      expect(section.act, 'IPC');
      expect(section.section, '379');
      expect(section.title.toLowerCase(), contains('theft'));
      expect(section.description, isNotEmpty);
      expect(section.longLabel, 'IPC Section 379');
    });
  });

  group('searching every act at once', () {
    test('answers a bare array of hits carrying their own act', () async {
      final hits = await remote.search('theft');

      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.act.isNotEmpty), isTrue);
      expect(hits.every((h) => h.section.isNotEmpty), isTrue);
      // The endpoint's SELECT has no description, which is why opening a hit
      // costs a second call.
      expect(hits.every((h) => h.isSummary), isTrue);
    });

    test('reaches past the IPC', () async {
      final hits = await remote.search('theft');

      expect(hits.map((h) => h.act).toSet().length, greaterThan(1));
    });
  });

  group('asking a legal question', () {
    test('answers with prose the screen shows as it came', () async {
      final answer = await remote.ask('What is the punishment for theft?');

      expect(answer, isNotEmpty);
      // Not parsed by the app, so only that there is something to show.
      expect(answer.length, greaterThan(40));
    });

    // A question the index cannot match is answered, not refused.
    test('an unmatchable question is still a 200 with a sentence', () async {
      final answer = await remote.ask('zzzz qqqq no such thing');

      expect(answer, isNotEmpty);
    });
  });

  group('matching a situation to sections', () {
    // `results` was added to the handler for this app: the website reads
    // `prediction`, which is Tailwind-classed HTML no native client can use.
    test('reads the structured results, not the HTML', () async {
      final findings = await remote.predictOutcome(
        'A mobile phone was stolen from a market',
      );

      expect(findings, isNotEmpty);
      final first = findings.first;
      expect(first.act, isNotEmpty);
      expect(first.section, isNotEmpty);
      expect(first.title, isNotEmpty);
      expect(first.score, greaterThan(0));
    });

    test('carries the punishment and the two flags an officer acts on',
        () async {
      final findings = await remote.predictOutcome(
        'A mobile phone was stolen from a market',
      );
      final theft = findings.firstWhere((f) => f.section == '378');

      expect(theft.punishment, isNotEmpty);
      expect(theft.isCognizable, isTrue);
      expect(theft.isBailable, isNotNull);
      expect(theft.bnsEquivalent, isNotEmpty);
    });

    test('a situation nothing matches is an empty list, not a failure',
        () async {
      expect(await remote.predictOutcome('zzzz qqqq'), isEmpty);
    });
  });
}

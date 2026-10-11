@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/fir/data/datasources/fir_remote_data_source.dart';
import 'package:nayaya_app/features/fir/data/models/fir_models.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';

import 'live_dio.dart';

/// Contract tests for FIR registration against a RUNNING NyayaAI server.
///
/// The unit suite proves the app builds the payload it thinks it does. Only this
/// proves the server agrees: that the 27 keys land in the 27 columns, that a
/// duplicate FIR number is rejected the way the app expects, and that the three
/// lookup endpoints answer with the shape the pickers are built on.
///
/// The column check is the one that could not be written any other way. Every
/// key is read server-side with `data.get(key, "")`, so a misspelt key does not
/// fail — it files an FIR with a blank column, and nobody finds out until the
/// record is needed. Reading the stored document back is what catches that.
///
/// It matters *more* now that the form is short. Eighteen of the columns are
/// sent as empty strings, and an empty column is exactly what a misspelt key
/// produces — so a test that only checked the nine collected entries would pass
/// while the record quietly lost its shape.
///
/// NOT part of the default run. See dart_test.yaml.
///
///   # 1. start the website (from the repo root)
///   venv/bin/python app.py
///   # 2. then, from flutter_app/
///   flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
///
/// WRITES TO THE DATABASE, and there is no delete route. See tearDownAll.
void main() {
  late Dio dio;
  late FirRemoteDataSource remote;

  /// Unique per run, because the server's duplicate check is the whole point of
  /// one of the tests below and a re-run must not collide with the last one.
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final firNo = 'ZZFLUTTER$stamp';

  /// A draft with something distinctive in every entry the short form collects,
  /// so the round-trip below can tell any two of them apart. Values that landed
  /// in the wrong column would still be present — only a per-column comparison
  /// catches a transposition.
  final draft = FirDraft(
    firNo: firNo,
    district: 'Delhi',
    policeStation: 'North Delhi PS',
    firDate: '2026-08-09',
    occurrenceDate: '2026-08-07',
    placeOfOccurrence: 'Sector 14 market, opposite the bus stand',
    complainantName: 'Live Probe Complainant',
    statement: 'Live contract probe — two-wheeler taken from outside the '
        'market at around noon.',
    sections: const [
      ActSection(act: 'IPC', section: '379'),
      ActSection(act: 'CRPC', section: '41'),
    ],
  );

  setUpAll(() {
    dio = createLiveDio();
    remote = FirRemoteDataSource(dio);
  });

  tearDownAll(() {
    // The server has no delete-FIR route, and it also wrote a PDF. Remove both
    // after the run:
    //
    //   venv/bin/python -c "from pymongo import MongoClient; \
    //     print(MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB'] \
    //       ['fir_records'] \
    //       .delete_many({'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count)"
    //   rm -f generated_firs/FIR_ZZFLUTTER*.pdf
    //
    // ignore: avoid_print
    print('Live FIR left behind: $firNo — see tearDownAll note.');
  });

  group('lookups', () {
    test('districts answers with a non-empty list of strings', () async {
      final districts = await remote.districts();

      expect(districts, isNotEmpty);
      expect(districts, contains('Delhi'));
      expect(districts.every((d) => d.trim().isNotEmpty), isTrue);
    });

    test('acts answers with the eight the section tables are keyed by',
        () async {
      final acts = await remote.acts();

      expect(
        acts,
        containsAll(['IPC', 'CRPC', 'NIA', 'IEA', 'HMA', 'CPC', 'IDA', 'MVA']),
      );
    });

    test('police stations answers for a known district', () async {
      final stations = await remote.policeStations('Delhi');

      expect(stations, isNotEmpty);
      expect(stations, contains('North Delhi PS'));
    });

    // The handler synthesises "<district> PS" rather than 404ing, which is why
    // the app can let an officer type a district the list does not carry.
    test('an unknown district gets a synthesised station, not a 404', () async {
      final stations = await remote.policeStations('Nowhere');

      expect(stations, ['Nowhere PS']);
    });
  });

  group('registration', () {
    test('files an FIR and answers with the shape the app reads', () async {
      final receipt = await remote.register(FirSubmission(draft));

      expect(receipt.firNo, firNo);
      expect(receipt.firId, isNotEmpty);
      expect(receipt.status, 'Saved to Police Records');
      // `pdf_url` on a current server, `pdf_file` on one still writing PDFs to
      // its own disk. The label is the filename either way, which is the whole
      // point of reading it through FirPdf rather than off one column.
      expect(receipt.pdfLabel, isNotEmpty);
      expect(receipt.hasPdf, isTrue);
      expect(receipt.createdAt, isNotEmpty);
      expect(receipt.message, isNotEmpty);

      // The sections the app sent, not ones the server inferred. An empty
      // act_sections would have triggered its AI branch.
      expect(receipt.actSections, 'IPC Section 379, CRPC Section 41');
    });

    test('every one of the 27 columns holds what was sent', () async {
      final response = await dio.get<dynamic>('/api/fir-records/$firNo');
      final stored = Map<String, dynamic>.from(response.data as Map);
      final sent = FirSubmission(draft).toJson();

      for (final entry in sent.entries) {
        expect(
          stored[entry.key],
          entry.value,
          reason: 'column ${entry.key} does not hold what was sent',
        );
      }
    });

    test('the derived columns arrive computed, not blank', () async {
      final response = await dio.get<dynamic>('/api/fir-records/$firNo');
      final stored = Map<String, dynamic>.from(response.data as Map);

      // Both are derived by the app; the server only stores them.
      expect(stored['year'], '2026');
      // 2026-08-07 is a Friday.
      expect(stored['occurrence_day'], 'Friday');
      expect(
        stored['place_of_occurrence'],
        'Sector 14 market, opposite the bus stand',
      );
    });

    // The one rejection the handler makes, and the reason the FIR number is
    // required rather than optional like most of the form.
    //
    // Matched loosely on purpose. The handler has already changed its wording
    // once — it used to name the number ("FIR number X already exists") and now
    // says only "FIR already exists" — and the app relays whatever sentence it
    // is given rather than recognising one. Pinning the exact string here tests
    // the server's copywriting, not the app's behaviour, and fails the suite for
    // a change that costs an officer nothing.
    test('a duplicate FIR number is refused with the server wording', () async {
      await expectLater(
        remote.register(FirSubmission(draft)),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message.toLowerCase(),
            'message',
            allOf(contains('fir'), contains('already exists')),
          ),
        ),
      );
    });
  });

  /// Reading it back — the half of the feature the unit suite cannot prove.
  ///
  /// Runs after the group above and depends on it: the FIR these tests look for
  /// is the one it just filed. That is deliberate rather than lazy — a history
  /// probe against a record the same run created is the only version of this
  /// test that does not depend on what happens to be in the station's database.
  group('FIR history', () {
    test('the filed FIR comes back in the collection', () async {
      final records = await remote.history();

      expect(records, isNotEmpty);
      expect(records.map((r) => r.firNo), contains(firNo));
    });

    // The reason ServerTime exists. `jsonify` writes a datetime as an RFC 1123
    // HTTP date here, while `/generate_fir` writes `str(datetime)` — two
    // spellings of one column, and the list is ordered by it.
    test('created_at arrives as an HTTP date the app can parse', () async {
      final records = await remote.history();
      final filed = records.firstWhere((r) => r.firNo == firNo);

      expect(filed.createdAt, isNotEmpty);
      expect(
        filed.filedAt,
        isNotNull,
        reason: 'created_at "${filed.createdAt}" did not parse — ServerTime '
            'needs to learn this shape',
      );
      expect(filed.filedAt!.isUtc, isTrue);
    });

    test('one record reads back through the model, column for column',
        () async {
      final record = await remote.record(firNo);
      final sent = FirSubmission(draft).toJson();

      expect(record.firNo, sent['fir_no']);
      expect(record.district, sent['dist']);
      expect(record.policeStation, sent['ps']);
      expect(record.actSections, sent['act_sections']);
      expect(record.placeOfOccurrence, sent['place_of_occurrence']);
      expect(record.complainantName, sent['complainant_name']);
      expect(record.statement, sent['statement']);

      // Written by the server, which is why the viewer can show them.
      expect(record.firId, isNotEmpty);
      expect(record.hasPdf, isTrue);
      expect(record.status, 'Saved to Police Records');
    });

    test('an unknown number is a 404 carrying the server\'s sentence',
        () async {
      await expectLater(
        remote.record('ZZNOSUCHFIR'),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'FIR record ZZNOSUCHFIR not found',
          ),
        ),
      );
    });

    test('the generated PDF downloads and is a PDF', () async {
      final dir = Directory.systemTemp.createTempSync('nayaya_live_pdf');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/$firNo.pdf';

      await remote.downloadPdf(firNo: firNo, savePath: path);

      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      // Not just "something arrived": a 200 carrying an HTML error page would
      // also write a file, and this is the cheapest way to tell them apart.
      expect(file.readAsBytesSync().take(4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    });

    // Normal, not exceptional: `generated_firs/` lives on whichever machine
    // filed the record, so a database restored from a backup has records whose
    // PDFs are simply not here.
    test('a record with no PDF on this server explains itself', () async {
      final dir = Directory.systemTemp.createTempSync('nayaya_live_pdf');
      addTearDown(() => dir.deleteSync(recursive: true));

      await expectLater(
        remote.downloadPdf(
          firNo: 'ZZNOSUCHFIR',
          savePath: '${dir.path}/missing.pdf',
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            contains('no PDF for this FIR'),
          ),
        ),
      );
      expect(File('${dir.path}/missing.pdf').existsSync(), isFalse);
    });
  });
}

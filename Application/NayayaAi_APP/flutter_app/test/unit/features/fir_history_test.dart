import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/core/utils/server_time.dart';
import 'package:nayaya_app/features/fir/data/datasources/fir_remote_data_source.dart';
import 'package:nayaya_app/features/fir/data/models/fir_models.dart';
import 'package:nayaya_app/features/fir/data/repositories/fir_repository_impl.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';

/// Pins FIR history's contract with the three endpoints it reads, and the two
/// pieces of server behaviour the app is obliged to work around.
///
/// The first is `created_at`: it reaches the client in two different spellings
/// depending on which handler answered, and the whole list is ordered by it.
/// The second is the `/fir/download/<no>` 404, which is a normal outcome rather
/// than an edge case and has to arrive as a sentence.
void main() {
  group('ServerTime — the two spellings of created_at', () {
    // What `GET /api/fir-records` sends, because `jsonify` serialises a datetime
    // as an RFC 1123 HTTP date.
    test('reads the HTTP date the record list sends', () {
      final parsed = ServerTime.parse('Sun, 09 Aug 2026 06:30:00 GMT');

      expect(parsed, DateTime.utc(2026, 8, 9, 6, 30));
      expect(parsed!.isUtc, isTrue);
    });

    // What `POST /generate_fir` sends, because that handler calls str() on it.
    test('reads the str(datetime) the receipt sends, as UTC', () {
      final parsed = ServerTime.parse('2026-08-09 06:30:00.345678');

      // Sub-second precision is kept rather than rounded away: it is the only
      // thing separating two FIRs filed in the same second, which is how the
      // list's tie-break gets to stay a tie-break rather than a coin toss.
      expect(parsed, DateTime.utc(2026, 8, 9, 6, 30, 0, 345, 678));
      // The string carries no zone and DateTime.tryParse would call it local.
      // Trusting that shifts every timestamp by the handset's offset — five and
      // a half hours in India, which reads as a filing that has not happened.
      expect(parsed!.isUtc, isTrue);
    });

    test('answers null for empty, blank and unreadable values', () {
      expect(ServerTime.parse(null), isNull);
      expect(ServerTime.parse(''), isNull);
      expect(ServerTime.parse('   '), isNull);
      expect(ServerTime.parse('sometime last Tuesday'), isNull);
    });

    // A record seeded straight into Mongo has turned up with no timestamp. The
    // list still has to show it, so the raw value is passed through rather than
    // blanked — an empty line reads as "never recorded", which is a claim.
    test('displays what it cannot parse rather than nothing', () {
      expect(ServerTime.display('not a date'), 'not a date');
      expect(ServerTime.display(''), '');
    });

    test('states UTC rather than converting to local time', () {
      expect(
        ServerTime.display('Sun, 09 Aug 2026 06:30:00 GMT'),
        '9 Aug 2026, 06:30 UTC',
      );
      expect(
        ServerTime.displayDay('Sun, 09 Aug 2026 06:30:00 GMT'),
        '9 Aug 2026',
      );
    });
  });

  group('FirRecordResponse — reading a stored FIR back', () {
    // The inverse of FirSubmission, and the pair has to stay that way: a key
    // that drifts apart shows up in the viewer as a permanently blank entry,
    // which looks exactly like an FIR filed incomplete.
    test('reads back every key the submission writes', () {
      const draft = FirDraft(
        firNo: 'FIR001',
        district: 'Delhi',
        policeStation: 'North Delhi PS',
        firDate: '2026-08-09',
        complainantName: 'A. Sharma',
        statement: 'Two-wheeler taken.',
        sections: [ActSection(act: 'IPC', section: '379')],
      );

      // Every column, filled with its own key's name so a transposition is
      // visible rather than merely possible.
      final stored = <String, dynamic>{
        for (final key in const FirSubmission(draft).toJson().keys)
          key: 'v_$key',
      };

      final record = FirRecordResponse.fromJson(stored);

      expect(record.firNo, 'v_fir_no');
      expect(record.district, 'v_dist');
      expect(record.policeStation, 'v_ps');
      expect(record.year, 'v_year');
      expect(record.firDate, 'v_fir_date');
      expect(record.actSections, 'v_act_sections');
      expect(record.occurrenceDay, 'v_occurrence_day');
      expect(record.occurrenceDate, 'v_occurrence_date');
      expect(record.occurrenceTime, 'v_occurrence_time');
      expect(record.infoReceivedDate, 'v_info_received_date');
      expect(record.infoReceivedTime, 'v_info_received_time');
      expect(record.gdrEntryNo, 'v_gdr_entry_no');
      expect(record.typeOfInformation, 'v_type_of_information');
      expect(record.placeOfOccurrence, 'v_place_of_occurrence');
      expect(record.complainantName, 'v_complainant_name');
      expect(record.fatherHusbandName, 'v_father_husband_name');
      expect(record.dob, 'v_dob');
      expect(record.nationality, 'v_nationality');
      expect(record.passportNo, 'v_passport_no');
      expect(record.dateOfIssue, 'v_date_of_issue');
      expect(record.placeOfIssue, 'v_place_of_issue');
      expect(record.occupation, 'v_occupation');
      expect(record.address, 'v_address');
      expect(record.detailsOfAccused, 'v_details_of_accused');
      expect(record.reasonsForDelay, 'v_reasons_for_delay');
      expect(record.propertyParticulars, 'v_property_particulars');
      expect(record.statement, 'v_statement');
    });

    // Three columns only the server writes, which is why the receipt screen and
    // this viewer can show them at all.
    test('reads the three columns the client never sends', () {
      final record = FirRecordResponse.fromJson({
        'fir_no': 'FIR001',
        'fir_id': '17549023114567',
        'pdf_file': 'FIR_FIR001.pdf',
        'created_at': 'Sun, 09 Aug 2026 06:30:00 GMT',
        'status': 'Saved to Police Records',
      });

      expect(record.firId, '17549023114567');
      expect(record.pdfFile, 'FIR_FIR001.pdf');
      expect(record.hasPdf, isTrue);
      expect(record.status, 'Saved to Police Records');
      expect(record.filedAt, DateTime.utc(2026, 8, 9, 6, 30));
    });

    // The history list mixes both eras: records filed before PDF storage moved
    // to Supabase carry `pdf_file`, everything since carries `pdf_url`. The
    // viewer has to read whichever one the record it is showing happens to have.
    test('reads the PDF from pdf_url and labels it with the filename', () {
      final record = FirRecordResponse.fromJson({
        'fir_no': 'FIR001',
        'fir_id': '17549023114567',
        'pdf_url': 'https://uafjhimjuyfqkqfnadei.supabase.co/storage/v1/object/'
            'public/firs/1787717861371606.pdf',
        'created_at': 'Sun, 09 Aug 2026 06:30:00 GMT',
        'status': 'Saved to Police Records',
      });

      expect(record.hasPdf, isTrue);
      expect(record.pdfLabel, '1787717861371606.pdf');
      expect(record.pdfFile, isEmpty);
    });

    test('a record with neither PDF column claims no PDF', () {
      final record = FirRecordResponse.fromJson({
        'fir_no': 'FIR001',
        'status': 'Saved to Police Records',
      });

      expect(record.hasPdf, isFalse);
      expect(record.pdfLabel, isEmpty);
    });

    // Schemaless collection, two writers. `year` posts as a number from the
    // website's form and as a string from here; a cast would throw on one of
    // them.
    test('reads a column that arrives as something other than a String', () {
      final record = FirRecordResponse.fromJson({
        'fir_no': 41,
        'year': 2026,
        'act_sections': null,
      });

      expect(record.firNo, '41');
      expect(record.year, '2026');
      expect(record.actSections, '');
    });

    test(
        'splits the sections column for display, and tolerates one that does '
        'not split', () {
      expect(
        FirRecordResponse.fromJson({'act_sections': 'IPC 379, IPC 411'})
            .sectionList,
        ['IPC 379', 'IPC 411'],
      );
      expect(
        FirRecordResponse.fromJson({'act_sections': 'section 379 IPC'})
            .sectionList,
        ['section 379 IPC'],
      );
      expect(
        FirRecordResponse.fromJson({'act_sections': ' , ,'}).sectionList,
        isEmpty,
      );
    });
  });

  group('FirRecord.matches — what the search box looks at', () {
    final record = FirRecordResponse.fromJson({
      'fir_no': 'FIR001',
      'dist': 'Delhi',
      'ps': 'North Delhi PS',
      'act_sections': 'IPC 379',
      'complainant_name': 'A. Sharma',
      'place_of_occurrence': 'Sector 14 market',
      'statement': 'A motorcycle was taken from outside the market.',
    });

    test('matches the number, the name, the station and the section', () {
      expect(record.matches('fir001'), isTrue);
      expect(record.matches('sharma'), isTrue);
      expect(record.matches('north delhi'), isTrue);
      expect(record.matches('379'), isTrue);
      expect(record.matches('sector 14'), isTrue);
    });

    // Deliberate. A hit inside a five-hundred word statement puts a row on
    // screen with nothing visible to explain why it is there, and "theft"
    // matches half a station's records.
    test('does not search the narrative', () {
      expect(record.matches('motorcycle'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(record.matches(''), isTrue);
    });
  });

  group('the history endpoint', () {
    late _StubAdapter adapter;
    late FirRepositoryImpl repository;

    setUp(() {
      adapter = _StubAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://stub'))
        ..httpClientAdapter = adapter;
      repository = FirRepositoryImpl(remote: FirRemoteDataSource(dio));
    });

    // The server returns the collection in insertion order and takes no sort
    // parameter, so this is the only place an order can be imposed at all.
    test('orders records newest first, by when the server stored them',
        () async {
      adapter.json = jsonEncode([
        {'fir_no': 'A', 'created_at': 'Fri, 07 Aug 2026 06:30:00 GMT'},
        {'fir_no': 'B', 'created_at': 'Sun, 09 Aug 2026 06:30:00 GMT'},
        {'fir_no': 'C', 'created_at': 'Sat, 08 Aug 2026 06:30:00 GMT'},
      ]);

      final records = await repository.history();

      expect(records.map((r) => r.firNo), ['B', 'C', 'A']);
    });

    // An unreadable timestamp is not evidence of recency. Floating one to the
    // head of the list would make it the first thing seen, every time.
    test('sorts records with no usable timestamp to the bottom', () async {
      adapter.json = jsonEncode([
        {'fir_no': 'NO_DATE'},
        {'fir_no': 'DATED', 'created_at': 'Fri, 07 Aug 2026 06:30:00 GMT'},
        {'fir_no': 'BAD_DATE', 'created_at': 'sometime last week'},
      ]);

      final records = await repository.history();

      expect(records.first.firNo, 'DATED');
      expect(records.map((r) => r.firNo).skip(1), ['NO_DATE', 'BAD_DATE']);
    });

    test('breaks ties on the FIR number, so the order is stable', () async {
      const stamp = 'Sun, 09 Aug 2026 06:30:00 GMT';
      adapter.json = jsonEncode([
        {'fir_no': 'FIR002', 'created_at': stamp},
        {'fir_no': 'FIR003', 'created_at': stamp},
        {'fir_no': 'FIR001', 'created_at': stamp},
      ]);

      final records = await repository.history();

      expect(records.map((r) => r.firNo), ['FIR003', 'FIR002', 'FIR001']);
    });

    // One malformed document should cost the officer that record, not the whole
    // history — four things write to this collection.
    test('skips a row that is not an object, and one with no FIR number',
        () async {
      adapter.json = jsonEncode([
        {'fir_no': 'FIR001', 'created_at': 'Sun, 09 Aug 2026 06:30:00 GMT'},
        'a bare string',
        {'complainant_name': 'no number here'},
      ]);

      final records = await repository.history();

      expect(records.map((r) => r.firNo), ['FIR001']);
    });

    test('an empty collection is an empty list, not a failure', () async {
      adapter.json = '[]';

      expect(await repository.history(), isEmpty);
    });

    test('a body that is not an array fails as a server fault', () async {
      adapter.json = '{"error": "Failed to retrieve FIR records"}';

      expect(
        () => repository.history(),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('one record, and its PDF', () {
    late _StubAdapter adapter;
    late FirRepositoryImpl repository;
    late Directory temp;

    setUp(() {
      adapter = _StubAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://stub'))
        ..httpClientAdapter = adapter;
      repository = FirRepositoryImpl(remote: FirRemoteDataSource(dio));
      temp = Directory.systemTemp.createTempSync('nayaya_fir_pdf');
      addTearDown(() => temp.deleteSync(recursive: true));
    });

    test('reads one record by its number', () async {
      adapter.json = jsonEncode({
        'fir_no': 'FIR001',
        'complainant_name': 'A. Sharma',
      });

      final record = await repository.record('FIR001');

      expect(record.firNo, 'FIR001');
      expect(record.complainantName, 'A. Sharma');
    });

    // The server's own wording, passed through: "FIR record X not found" tells
    // an officer to check the number, which "not found" does not.
    test('a number that names no record fails with the server\'s sentence',
        () async {
      adapter
        ..status = 404
        ..json = jsonEncode({'error': 'FIR record FIR404 not found'});

      await expectLater(
        () => repository.record('FIR404'),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'FIR record FIR404 not found',
          ),
        ),
      );
    });

    test('writes the downloaded PDF to the path it was given', () async {
      adapter.json = '%PDF-1.4 stub';
      final path = '${temp.path}/FIR_FIR001.pdf';

      await repository.downloadPdf(firNo: 'FIR001', savePath: path);

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsStringSync(), '%PDF-1.4 stub');
    });

    // The common case for a record filed on another machine: `generated_firs/`
    // is local to whichever server wrote it. It has to read as an explanation,
    // not as a fault — and ErrorMapper cannot supply one here, because a
    // download is streamed and never parses the error body.
    test('a missing PDF explains itself, and writes no file', () async {
      adapter
        ..status = 404
        ..json = jsonEncode({'error': 'PDF for FIR FIR001 not found'});
      final path = '${temp.path}/FIR_FIR001.pdf';

      await expectLater(
        () => repository.downloadPdf(firNo: 'FIR001', savePath: path),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            contains('no PDF for this FIR'),
          ),
        ),
      );
      expect(File(path).existsSync(), isFalse);
    });
  });
}

/// Answers every request with [json] and [status], so the data layer can be
/// tested without a server.
///
/// Written here rather than pulled in as a package: two fields and one method
/// against `HttpClientAdapter` is less to explain than a mocking library, and it
/// keeps the tests describing the *server's* replies rather than a mock's
/// grammar.
class _StubAdapter implements HttpClientAdapter {
  String json = '{}';
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      json,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

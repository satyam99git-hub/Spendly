@Tags(['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/evidence/data/datasources/evidence_remote_data_source.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_category.dart';
import 'package:nayaya_app/features/evidence/domain/entities/evidence_file.dart';
import 'package:nayaya_app/features/fir/data/datasources/fir_remote_data_source.dart';
import 'package:nayaya_app/features/fir/data/models/fir_models.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';

import 'live_dio.dart';

/// Contract tests for the evidence locker against a RUNNING NyayaAI server.
///
/// Three things only a real server can settle, and each has burned somebody:
///
///  1. **The multipart body actually arrives.** `DioClient` sets a JSON content
///     type for every other request in the app. Sent with that header, a
///     multipart body reaches Flask as an empty `request.files` and the handler
///     answers "Missing FIR or file" — a message that names neither of the two
///     things that were, in fact, sent. A fake cannot catch that; this can.
///  2. **The FIR must exist first.** `/upload-evidence` is the only evidence
///     endpoint that validates anything, and its rejection is what the Add
///     screen renders verbatim.
///  3. **`file_type` is a category, not a MIME type**, despite the Mongo column
///     of the same name holding a MIME type. The list and the detail screen are
///     built on the category.
///
/// NOT part of the default run. See dart_test.yaml.
///
///   # 1. start the website (from the repo root)
///   venv/bin/python app.py
///   # 2. then, from flutter_app/
///   flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
///
/// WRITES TO THE DATABASE AND TO DISK. See tearDownAll.
void main() {
  late Dio dio;
  late EvidenceRemoteDataSource evidence;
  late FirRemoteDataSource fir;
  late Directory scratch;

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final firNo = 'ZZFLUTTER$stamp';
  final filename = 'zzflutter_$stamp.txt';

  setUpAll(() async {
    dio = createLiveDio();
    evidence = EvidenceRemoteDataSource(dio);
    fir = FirRemoteDataSource(dio);

    scratch = await Directory.systemTemp.createTemp('nyayaai_evidence');

    // The upload is rejected unless the FIR exists, so the probe has to file one
    // first. This is the dependency the feature doc calls out: evidence cannot
    // be attached while an FIR is being written.
    await fir.register(
      FirSubmission(
        FirDraft(
          firNo: firNo,
          district: 'Delhi',
          policeStation: 'North Delhi PS',
          firDate: '2026-08-09',
          complainantName: 'Live Probe Complainant',
          statement: 'Live evidence probe.',
          sections: const [ActSection(act: 'IPC', section: '379')],
        ),
      ),
    );
  });

  tearDownAll(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);

    // Neither the FIR nor the evidence row has a delete route, and the upload
    // also wrote a file into static/uploads/evidence/<fir_no>/:
    //
    //   venv/bin/python -c "from pymongo import MongoClient; \
    //     db = MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB']; \
    //     print(db['fir_records'].delete_many( \
    //       {'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count, \
    //       db['evidence_files'].delete_many( \
    //       {'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count)"
    //   rm -rf static/uploads/evidence/ZZFLUTTER*
    //   rm -f generated_firs/FIR_ZZFLUTTER*.pdf
    //
    // ignore: avoid_print
    print('Live evidence left behind: $firNo/$filename — see tearDownAll.');
  });

  Future<EvidenceFile> writeProbeFile() async {
    final file = File('${scratch.path}/$filename');
    await file.writeAsString('live evidence probe $stamp');
    return EvidenceFile(
      path: file.path,
      name: filename,
      sizeInBytes: await file.length(),
    );
  }

  // The PIN gate. In-app until it was found that the handset and the website's
  // console opened the same locker with two different strings; this is the only
  // test that can prove they now agree, because the value lives on the server.
  group('the PIN gate', () {
    test('the server accepts the station PIN', () async {
      expect(await evidence.verifyLockerPin('secure@123'), isTrue);
    });

    test('a wrong PIN is a clean no, not a failure', () async {
      expect(await evidence.verifyLockerPin('not-the-pin'), isFalse);
    });

    test('the comparison is exact', () async {
      expect(await evidence.verifyLockerPin('SECURE@123'), isFalse);
      expect(await evidence.verifyLockerPin(' secure@123 '), isFalse);
    });
  });

  group('upload', () {
    test('a multipart body reaches the handler with both parts', () async {
      final item = await evidence.upload(
        firNo: firNo,
        file: await writeProbeFile(),
      );

      // If the JSON content type had leaked through, this would have been
      // "Missing FIR or file" instead.
      expect(item.firNo, firNo);
      expect(item.filename, filename);
    });

    test('an FIR that does not exist is refused, in the server\'s words',
        () async {
      await expectLater(
        evidence.upload(
          firNo: 'ZZNOSUCHFIR$stamp',
          file: await writeProbeFile(),
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'FIR number does not exist. Please enter a valid FIR.',
          ),
        ),
      );
    });
  });

  group('reading it back', () {
    test('the file appears against its FIR, with a category and a time',
        () async {
      final items = await evidence.forFir(firNo);

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.filename, filename);
      // `.txt` is not in the server's table, so both sides should say "other".
      expect(item.category, EvidenceCategory.other);
      expect(item.hasTimestamp, isTrue);
    });

    test('the whole-locker listing includes it too', () async {
      final all = await evidence.all();

      expect(
        all.where((i) => i.firNo == firNo && i.filename == filename),
        hasLength(1),
      );
    });

    // An unknown FIR is an empty locker, not an error — which is what lets the
    // detail screen say "no longer in the locker" rather than showing a failure.
    test('an unknown FIR answers with an empty list, not a 404', () async {
      expect(await evidence.forFir('ZZNOSUCHFIR$stamp'), isEmpty);
    });

    // Served by `send_from_directory` with no session check, which is what lets
    // the detail screen preview an image with Image.network.
    test('the stored file is served back byte for byte', () async {
      final response = await dio.get<dynamic>(
        '/evidence-file/$firNo/$filename',
        options: Options(responseType: ResponseType.plain),
      );

      expect(response.statusCode, 200);
      expect(response.data.toString(), 'live evidence probe $stamp');
    });
  });

  group('the access log', () {
    // A stub server-side: it acknowledges and discards. Pinned so that the day
    // it starts writing, the client is already sending a body it can write.
    test('acknowledges without ever failing', () async {
      await expectLater(
        evidence.logAccess({
          'fir_no': firNo,
          'filename': filename,
          'action': 'view',
        }),
        completes,
      );
    });
  });
}

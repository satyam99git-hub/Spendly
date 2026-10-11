import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/constants/api_endpoints.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/judge/data/datasources/judge_bookmark_store.dart';
import 'package:nayaya_app/features/judge/data/datasources/judge_remote_data_source.dart';
import 'package:nayaya_app/features/judge/data/models/judge_models.dart';

import '../../helpers/fake_judge_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';

/// The Judge Portal's contract with the website: the same requests, the same
/// readings of the reply, the same arithmetic over the docket.
void main() {
  DocketEntry entry({
    int id = 1,
    String caseId = 'FIR001',
    String date = '2099-01-15 10:30',
    String urgency = 'normal',
    String status = 'scheduled',
    String? caseType = 'Criminal',
    String? remarks,
  }) =>
      DocketEntry.fromJson(
        docketRow(
          id: id,
          caseId: caseId,
          hearingDate: date,
          urgency: urgency,
          status: status,
          caseType: caseType,
          remarks: remarks,
        ),
      );

  group('Home arithmetic (updateStats / renderUpcomingHearings)', () {
    final now = DateTime(2026, 10, 11, 12);

    test('counts total, urgent, scheduled and the next seven days', () {
      final stats = DocketStats.of(
        [
          entry(id: 1, date: '2026-10-12 10:00', urgency: 'urgent'),
          entry(id: 2, date: '2026-10-18 11:00', status: 'adjourned'),
          entry(id: 3, date: '2026-10-19 10:00'), // 8 days out
          entry(id: 4, date: '2026-10-10 10:00', urgency: 'urgent'), // past
          entry(id: 5, date: 'not a date'),
        ],
        now: now,
      );

      expect(stats.total, 5);
      expect(stats.urgent, 2);
      expect(stats.scheduled, 4);
      // "This week" ignores status, as the page's filter does.
      expect(stats.thisWeek, 2);
    });

    test('upcoming: scheduled, from now on, soonest first, at most five', () {
      final list = upcomingHearings(
        [
          for (var i = 9; i >= 1; i--) entry(id: i, date: '2026-10-1$i 09:00'),
          entry(id: 20, date: '2026-10-12 08:00', status: 'adjourned'),
          entry(id: 21, date: '2026-10-01 08:00'),
        ],
        now: now,
      );

      expect(list.map((e) => e.id), [2, 3, 4, 5, 6]);
    });
  });

  group('Case Workspace grouping (loadWorkspace)', () {
    test('one card per case in first-seen order; latest is the last', () {
      final cases = WorkspaceCase.group([
        entry(
          id: 1,
          caseId: 'A',
          date: '2099-02-01 10:00',
          status: 'adjourned',
        ),
        entry(id: 2, caseId: 'B', caseType: null),
        entry(id: 3, caseId: 'A', date: '2099-01-01 10:00', caseType: ''),
      ]);

      expect(cases.map((c) => c.caseId), ['A', 'B']);
      expect(cases.first.hearingCount, '2 hearings');
      expect(cases.last.hearingCount, '1 hearing');
      expect(cases.first.latest.id, 3);
      // `items[0]?.case_type || "General"`.
      expect(cases.first.detailType, 'Criminal');
      expect(cases.last.detailType, 'General');
      // The timeline is oldest first.
      expect(cases.first.timeline.map((e) => e.id), [3, 1]);
    });
  });

  group('the hearing modal', () {
    test('edit pre-fill normalises the stored value as datetime-local does',
        () {
      expect(editInputValue('2099-01-15 10:30'), '2099-01-15T10:30');
      expect(editInputValue('2099-01-15T10:30:00'), '2099-01-15T10:30');
      // An offset is not a local date-time: the box would be empty.
      expect(editInputValue('2099-01-15T10:30:00+00:00'), '');
      expect(editInputValue('soon'), '');
    });

    test('the payload carries the page\'s six keys', () {
      const payload = DocketPayload(
        caseId: 'FIR001',
        hearingDate: '2099-01-15 10:30',
        caseType: 'Criminal',
        urgency: 'urgent',
        status: 'adjourned',
        remarks: 'r',
      );
      expect(payload.toJson(), {
        'case_id': 'FIR001',
        'hearing_date': '2099-01-15 10:30',
        'case_type': 'Criminal',
        'urgency': 'urgent',
        'status': 'adjourned',
        'remarks': 'r',
      });
    });

    test('suggestions match FIR no., complainant or district; eight at most',
        () {
      final all = [
        for (var i = 0; i < 12; i++)
          JudgeFir.fromJson(judgeFirRow(firNo: 'FIR10$i')),
        JudgeFir.fromJson(
          judgeFirRow(firNo: 'X9', complainant: 'Ravi', dist: 'Nagpur'),
        ),
      ];
      expect(firSuggestions(all, '   '), isNull);
      expect(firSuggestions(all, 'fir10')!.length, 8);
      expect(firSuggestions(all, 'fir10')!.first.firNo, 'FIR100');
      expect(firSuggestions(all, 'RAVI')!.single.firNo, 'X9');
      expect(firSuggestions(all, 'nagp')!.single.firNo, 'X9');
      expect(firSuggestions(all, 'zzz'), isEmpty);
    });

    test('the preview line falls back as the page does', () {
      final fir = JudgeFir.fromJson(
        judgeFirRow(complainant: null, dist: null, sections: ''),
      );
      expect(fir.previewLine, '✓ Unknown ·  · No sections');
      expect(fir.field('ps'), 'Shivajinagar PS');
      expect(JudgeFir.fromJson(judgeFirRow(ps: null)).field('ps'), '-');
    });
  });

  group('endpoints', () {
    test('filters are added only when set', () {
      expect(ApiEndpoints.judgeDocketFiltered(), '/judge/docket');
      expect(
        ApiEndpoints.judgeDocketFiltered(status: 'scheduled'),
        '/judge/docket?status=scheduled',
      );
      expect(
        ApiEndpoints.judgeDocketFiltered(
          status: 'completed',
          urgency: 'urgent',
        ),
        '/judge/docket?status=completed&urgency=urgent',
      );
      expect(ApiEndpoints.judgeDocketEntry(7), '/judge/docket/7');
      expect(ApiEndpoints.openBareAct('BNS'), '/open-bare-act/BNS');
    });
  });

  group('JudgeRemoteDataSource', () {
    late _Server server;
    late JudgeRemoteDataSource source;

    setUp(() {
      server = _Server();
      source = JudgeRemoteDataSource(server.dio);
    });

    test('docket parses rows and sends the filters', () async {
      server.on('/judge/docket', 200, [docketRow(id: 5)]);
      final list = await source.docket(status: 'adjourned');
      expect(list.single.id, 5);
      expect(server.lastQuery, 'status=adjourned');
    });

    test('a 403 from the docket is a session that is no longer a judge\'s',
        () async {
      server.on('/judge/docket', 403, {'error': 'unauthorized'});
      await expectLater(
        source.docket(),
        throwsA(
          isA<AuthFailure>().having((f) => f.sessionExpired, 'expired', true),
        ),
      );
    });

    test('create sends the payload; refusals read message, then error',
        () async {
      const payload = DocketPayload(
        caseId: 'C1',
        hearingDate: '2099-01-01 10:00',
        caseType: '',
        urgency: 'normal',
        status: 'scheduled',
        remarks: '',
      );
      server.on('/judge/docket', 201, {'id': 1});
      await source.createEntry(payload);
      expect(server.lastMethod, 'POST');
      expect(server.lastBody, payload.toJson());

      server.on('/judge/docket', 409, {
        'error': 'conflict',
        'message': 'Overlaps with case X at 2099-01-01 10:10',
      });
      await expectLater(
        source.createEntry(payload),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'Overlaps with case X at 2099-01-01 10:10',
          ),
        ),
      );

      // PUT on someone else's entry: `{error: "not_found"}` and no message —
      // the page prints "not_found".
      server.on('/judge/docket/9', 404, {'error': 'not_found'});
      await expectLater(
        source.updateEntry(9, payload),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'not_found'),
        ),
      );

      // A Flask error page: the page's own sentence.
      server.fallback = (500, '<html>boom</html>');
      server.replies.remove('/judge/docket');
      await expectLater(
        source.createEntry(payload),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'Could not save hearing.'),
        ),
      );
    });

    test('delete uses the entry route', () async {
      server.on('/judge/docket/4', 200, {'deleted': 4});
      await source.deleteEntry(4);
      expect(server.lastMethod, 'DELETE');
      expect(server.lastPath, '/judge/docket/4');
    });

    test('an FIR that cannot be read is "no linked FIR"', () async {
      server.on('/api/fir-records/F1', 200, judgeFirRow(firNo: 'F1'));
      expect((await source.fir('F1')).firNo, 'F1');
      server
          .on('/api/fir-records/F2', 404, {'error': 'FIR record F2 not found'});
      await expectLater(
        source.fir('F2'),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'No linked FIR record found for this Case ID.',
          ),
        ),
      );
    });

    test('the FIR list keeps the server\'s order', () async {
      server.on('/api/fir-records', 200, [
        judgeFirRow(firNo: 'B'),
        judgeFirRow(firNo: 'A'),
      ]);
      expect((await source.firOptions()).map((f) => f.firNo), ['B', 'A']);
    });

    test('research: a JSON error is shown as is; HTML is the catch-all',
        () async {
      server.on('/judge/precedents', 200, {
        'current_law': {
          'topic_label': 'Anticipatory Bail',
          'current': {'act': 'BNSS', 'section': '482', 'subject': 'S'},
          'historical': {'act': 'CrPC', 'section': '438'},
        },
        'directly_relevant': [
          {'case': 'Sibbia', 'citation': '(1980) 2 SCC 565'},
        ],
        'synthesis': null,
        'sources': [],
      });
      final r = await source.research('anticipatory bail');
      expect(server.lastBody, {'query': 'anticipatory bail'});
      expect(nested(r.currentLaw!, 'current', 'section'), '482');
      expect(r.directlyRelevant.single['case'], 'Sibbia');
      expect(r.synthesis, isNull);
      expect(r.isEmpty, isFalse);

      server.on('/judge/precedents', 401, {'error': 'Unauthorized'});
      await expectLater(
        source.research('x'),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'Unauthorized'),
        ),
      );

      server.on('/judge/precedents', 500, '<html>boom</html>');
      server.replies['/judge/precedents'] = (500, '<html>boom</html>');
      await expectLater(
        source.research('x'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Something went wrong. Please try again.',
          ),
        ),
      );
    });
  });

  group('bookmarks (localStorage on the website, device storage here)', () {
    test('round-trip under the page\'s key; junk reads as empty', () async {
      final storage = InMemorySecureStorage();
      final store = JudgeBookmarkStore(storage);
      expect(await store.read(), isEmpty);

      final saved = await store.write(const [
        JudgeBookmark(act: 'IPC', section: '379', title: 'Theft'),
      ]);
      expect(saved.single.title, 'Theft');
      expect(storage.values.keys, ['nyayaai_judge_bookmarks']);
      expect(
        jsonDecode(storage.values['nyayaai_judge_bookmarks']!),
        [
          {'act': 'IPC', 'section': '379', 'title': 'Theft'},
        ],
      );

      storage.values['nyayaai_judge_bookmarks'] = '{not json';
      expect(await store.read(), isEmpty);
    });
  });
}

/// A server that answers each path with a canned reply and remembers the last
/// request.
class _Server {
  _Server() {
    dio.httpClientAdapter = _Adapter(this);
  }

  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000'));
  final Map<String, (int, String)> replies = {};
  (int, String) fallback = (404, '<html>not found</html>');

  String? lastPath;
  String? lastQuery;
  String? lastMethod;
  Object? lastBody;

  void on(String path, int status, Object body) =>
      replies[path] = (status, body is String ? body : jsonEncode(body));
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.server);

  final _Server server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    server
      ..lastPath = path
      ..lastQuery = options.uri.query
      ..lastMethod = options.method
      ..lastBody = options.data;
    final (status, body) = server.replies[path] ?? server.fallback;
    final isJson =
        body.trimLeft().startsWith('{') || body.trimLeft().startsWith('[');
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [
          isJson ? Headers.jsonContentType : 'text/html; charset=utf-8',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

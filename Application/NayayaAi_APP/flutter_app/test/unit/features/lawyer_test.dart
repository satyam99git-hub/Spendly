import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/lawyer/data/datasources/lawyer_remote_data_source.dart';
import 'package:nayaya_app/features/lawyer/data/models/lawyer_models.dart';
import 'package:nayaya_app/features/lawyer/domain/entities/lawyer_content.dart';

import '../../helpers/fake_lawyer_repository.dart';

/// The Lawyer Portal's contract with the website: the same requests, the same
/// words, the same handling of what comes back. Line references are to
/// `website/templates/lawyer_dashboard.html` unless they say `app.py`.
void main() {
  group('prompts (template literals, lines 1218-1260)', () {
    final row = firRow();

    test('the AI summary query is the page\'s, word for word', () {
      expect(
        LawyerContent.summaryQuery(row),
        'Summarize this case for the assigned lawyer: FIR FIR001, sections: '
        'BNS 303, accused: Unknown male, about 30, narrative: Phone snatched '
        'near the bus stop.. Give: key facts, applicable sections explained '
        'briefly, and immediate next steps for the defense/prosecution. Only '
        'cite specific case names/citations if you are confident they are real '
        '— otherwise describe the general legal principle without attributing '
        'it to a specific case. If key details (dates, complainant name, etc.) '
        "are missing from what I've given you, say so explicitly rather than "
        'inventing placeholder values.',
      );
    });

    test('the bail prompt carries the fixed court and grounds', () {
      expect(
        LawyerContent.bailPrompt(row),
        'Accused: Unknown male, about 30\nCourt: SESSIONS COURT\nFIR: FIR001\n'
        'Section Charged: BNS 303\n'
        'Grounds: First-time offender, investigation complete',
      );
    });

    test('the general document prompt', () {
      expect(
        LawyerContent.documentPrompt(row),
        'Draft a legal document based on FIR FIR001. Sections: BNS 303. '
        'Facts: Phone snatched near the bus stop.',
      );
    });

    test('a null prints "null", a missing key "undefined", as in JS', () {
      final c = {'fir_no': 'FIR9', 'act_sections': null};
      expect(
        LawyerContent.documentPrompt(c),
        'Draft a legal document based on FIR FIR9. Sections: null. Facts: ',
      );
      expect(LawyerContent.bailPrompt(c), startsWith('Accused: undefined\n'));
    });

    test('the narrative is cut at 500 characters', () {
      final c = {...row, 'statement': 'x' * 700};
      expect(
        LawyerContent.documentPrompt(c),
        endsWith('Facts: ${'x' * 500}'),
      );
    });
  });

  group('case cards and stats (lines 438-454, 1423-1471)', () {
    LawyerCase c(Map<String, dynamic> json) => LawyerCase.fromJson(json);

    test('no status reads "Active"; the key is lower-case and hyphenated', () {
      final none = c(firRow(status: null));
      expect(none.statusLabel, 'Active');
      expect(none.statusKey, 'active');
      expect(
        c(firRow(status: 'Court Proceedings')).statusKey,
        'court-proceedings',
      );
    });

    test('Jinja prints a null as None on the card', () {
      final card = c({'fir_no': 'FIR2', 'complainant_name': null});
      expect(card.jinja('complainant_name'), 'None');
      expect(card.jinja('act_sections'), '');
      expect(card.nextHearingLabel, '—');
    });

    test('search matches what the card shows', () {
      final card = c(firRow(complainant: 'Ravi Kumar', nextHearing: null));
      expect(card.searchText, contains('client: ravi kumar'));
      expect(card.searchText, contains('fir: fir001'));
      expect(card.searchText, contains('next hearing: —'));
    });

    test('only Investigation and Court Proceedings are counted', () {
      final stats = LawyerCaseStats.of([
        c(firRow(status: 'Investigation')),
        c(firRow(status: 'Court Proceedings')),
        c(firRow(status: 'Trial')),
        c(firRow(status: 'Closed')),
        c(firRow(status: null)),
      ]);
      expect(stats.total, 5);
      expect(stats.investigation, 1);
      expect(stats.courtProceedings, 1);
    });

    test('a hearing counts when it falls between now and a week ahead', () {
      final now = DateTime.utc(2026, 9, 28, 9);
      final stats = LawyerCaseStats.of(
        [
          c(firRow(firNo: 'B', nextHearing: '2026-10-03')),
          c(firRow(firNo: 'A', nextHearing: '2026-09-30')),
          c(firRow(firNo: 'late', nextHearing: '2026-10-06')),
          c(firRow(firNo: 'past', nextHearing: '2026-09-27')),
          c(firRow(firNo: 'bad', nextHearing: 'soon')),
        ],
        now: now,
      );
      expect(stats.upcomingHearings.map((h) => h.firNo), ['A', 'B']);
    });

    // `new Date('YYYY-MM-DD')` is UTC midnight, already behind "now" by the
    // time anyone opens the page that day.
    test('today\'s hearing is left out, as on the website', () {
      final now = DateTime.utc(2026, 9, 28, 9);
      final stats = LawyerCaseStats.of(
        [c(firRow(nextHearing: '2026-09-28'))],
        now: now,
      );
      expect(stats.upcomingHearings, isEmpty);
    });
  });

  group('deadlines (lines 1090-1110, 1184-1195)', () {
    test('today is the UTC date', () {
      // 23:30 in India on the 28th is still the 28th in UTC… at 18:00Z.
      expect(jsTodayUtc(now: DateTime.utc(2026, 9, 28, 18)), '2026-09-28');
      expect(jsTodayUtc(now: DateTime.utc(2026, 9, 29, 0, 5)), '2026-09-29');
    });

    test('overdue is a string comparison with that date', () {
      const d = CaseDeadline(
        id: 1,
        firNo: 'F',
        deadlineType: 'Custom',
        dueDate: '2026-09-27',
        note: '',
        completed: false,
      );
      expect(d.isPastDue('2026-09-28'), isTrue);
      expect(d.isPastDue('2026-09-27'), isFalse);
    });

    test('the six types, Chargesheet Filing first', () {
      expect(LawyerContent.deadlineTypes, hasLength(6));
      expect(LawyerContent.deadlineTypes.first, 'Chargesheet Filing');
    });
  });

  group('profile validation (saveProfile, lines 1685-1697)', () {
    LawyerProfileUpdate u({String phone = '', String years = ''}) =>
        LawyerProfileUpdate(
          phone: phone,
          officeAddress: '',
          barEnrollmentNo: '',
          yearsExperience: years,
          practiceArea: '',
          bio: '',
        );

    test('a phone, when given, is exactly ten digits', () {
      expect(
        u(phone: '98765').validate(),
        'Phone number must be exactly 10 digits.',
      );
      expect(u(phone: '9876543210').validate(), isNull);
      expect(u().validate(), isNull);
    });

    test('years is a whole number up to 60', () {
      expect(
        u(years: '61').validate(),
        'Years of experience must be a number up to 60.',
      );
      expect(u(years: '60').validate(), isNull);
    });

    test('the phone is checked first', () {
      expect(
        u(phone: '1', years: '99').validate(),
        'Phone number must be exactly 10 digits.',
      );
    });

    test('all six fields are always sent', () {
      expect(u().toJson().keys, {
        'phone',
        'office_address',
        'bar_enrollment_no',
        'years_experience',
        'practice_area',
        'bio',
      });
    });

    test('kind is capitalised as CSS capitalize does', () {
      const d = CaseDraft(
        id: 1,
        firNo: 'F',
        kind: 'bail',
        content: '',
        createdAt: '',
      );
      expect(d.kindLabel, 'Bail');
    });
  });

  group('LawyerRemoteDataSource', () {
    late _Server server;
    late LawyerRemoteDataSource source;

    setUp(() {
      server = _Server();
      source = LawyerRemoteDataSource(server.dio);
    });

    test('my cases are the FIRs assigned to the /api/me user', () async {
      server
        ..on('/api/me', 200, {'logged_in': true, 'user_id': 'U1'})
        ..on('/api/fir-records', 200, [
          firRow(firNo: 'A', assignedTo: 'U1'),
          firRow(firNo: 'B', assignedTo: 'U2'),
          firRow(firNo: 'C', assignedTo: 'U1'),
        ]);
      final cases = await source.cases();
      expect(cases.map((c) => c.firNo), ['A', 'C']);
    });

    test('an ended session is an AuthFailure', () async {
      server
        ..on('/api/me', 200, {'logged_in': false})
        ..on('/api/fir-records', 200, <Object>[]);
      await expectLater(source.cases(), throwsA(isA<AuthFailure>()));
    });

    test('claim posts to assign-lawyer with the number encoded', () async {
      server.on(
        '/api/fir-records/FIR%2001/assign-lawyer',
        200,
        {'message': 'Case added to your dashboard'},
      );
      await source.claim('FIR 01');
      expect(server.lastMethod, 'POST');
    });

    test('a refused claim shows the server error', () async {
      server.fallback = (404, jsonEncode({'error': 'FIR not found'}));
      await expectLater(
        source.claim('FIR404'),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'FIR not found'),
        ),
      );
    });

    test('a claim answered with no JSON is the page\'s network text', () async {
      server.fallback = (404, '<!doctype html><title>404</title>');
      await expectLater(
        source.claim('FIR/2026/1'),
        throwsA(
          isA<NetworkFailure>().having(
            (f) => f.message,
            'message',
            'Something went wrong. Please try again.',
          ),
        ),
      );
    });

    test('status change sends {status}; a refusal shows its error', () async {
      server.on('/api/case/F1/status', 200, {'message': 'Status updated'});
      await source.updateStatus('F1', 'Trial');
      expect(server.lastBody, {'status': 'Trial'});
      expect(server.lastMethod, 'PATCH');

      server.fallback = (400, jsonEncode({}));
      await expectLater(
        source.updateStatus('F9', 'Trial'),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'Could not update status.'),
        ),
      );
    });

    test('client visibility sends {visible, note}', () async {
      server.on('/api/case/F1/client-visibility', 200, {'visible': true});
      await source.setClientVisibility('F1', visible: true, note: 'Hi');
      expect(server.lastBody, {'visible': true, 'note': 'Hi'});
    });

    test('hearings, deadlines and drafts post the page\'s keys', () async {
      server.fallback = (201, jsonEncode({'message': 'ok'}));
      await source.addHearing('F1', '2026-10-01', 'bail');
      expect(server.lastPath, '/api/case/F1/hearings');
      expect(server.lastBody, {'hearing_date': '2026-10-01', 'note': 'bail'});

      await source.addDeadline(
        'F1',
        deadlineType: 'Custom',
        dueDate: '2026-10-02',
        note: '',
      );
      expect(server.lastBody, {
        'deadline_type': 'Custom',
        'due_date': '2026-10-02',
        'note': '',
      });

      await source.setDeadlineCompleted('F1', 7, completed: true);
      expect(server.lastPath, '/api/case/F1/deadlines/7');
      expect(server.lastBody, {'completed': true});

      await source.saveDraft('F1', 'bail', 'text');
      expect(server.lastBody, {'kind': 'bail', 'content': 'text'});

      await source.deleteDraft('F1', 3);
      expect(server.lastPath, '/api/case/F1/drafts/3');
      expect(server.lastMethod, 'DELETE');
    });

    test('a list endpoint answering with an object is an empty list', () async {
      server.fallback = (403, jsonEncode({'error': 'Forbidden'}));
      expect(await source.hearings('F1'), isEmpty);
      expect(await source.allDrafts(), isEmpty);
    });

    test('a list endpoint answering with HTML is a silent failure', () async {
      server.fallback = (500, '<html>boom</html>');
      await expectLater(
        source.deadlines('F1'),
        throwsA(isA<LawyerSilentFailure>()),
      );
    });

    test('find-precedents sends type "laws" and returns the answer', () async {
      server.on('/api/lawyer/find-precedents', 200, {'answer': '## A'});
      expect(await source.findPrecedents('q'), '## A');
      expect(server.lastBody, {'query': 'q', 'type': 'laws'});
    });

    // LL-2: the handler returns None when Groq answers (app.py:1294-1303).
    test('find-precedents answered by a 500 page throws', () async {
      server.fallback = (500, '<!doctype html><title>500</title>');
      await expectLater(
        source.findPrecedents('q'),
        throwsA(isA<LawyerSilentFailure>()),
      );
    });

    test('a draft without text reads "No draft returned."', () async {
      server.fallback = (400, jsonEncode({'error': 'Prompt required'}));
      expect(
        await source.generateDraft(bail: true, prompt: 'p'),
        'No draft returned.',
      );
      expect(server.lastPath, '/api/lawyer/bail-draft');
    });

    test('a refused profile load leaves the fields as they were', () async {
      server.fallback = (401, jsonEncode({'error': 'Unauthorized'}));
      expect(await source.profile(), isNull);
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
  String? lastMethod;
  Object? lastBody;

  void on(String path, int status, Object body) =>
      replies[path] = (status, jsonEncode(body));
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

@Tags(['live'])
library;

import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/constants/api_endpoints.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:nayaya_app/features/authentication/data/models/auth_models.dart';
import 'package:nayaya_app/features/citizen/data/datasources/citizen_remote_data_sources.dart';
import 'package:nayaya_app/features/fir/data/datasources/fir_remote_data_source.dart';
import 'package:nayaya_app/features/fir/data/models/fir_models.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/lawyer/data/datasources/lawyer_remote_data_source.dart';
import 'package:nayaya_app/features/lawyer/data/models/lawyer_models.dart';
import 'package:nayaya_app/features/lawyer/domain/entities/lawyer_content.dart';

import 'live_dio.dart';

/// The Lawyer Portal's data layer against a REAL NyayaAI server.
///
/// Runs `LawyerRemoteDataSource` — the code the lawyer screens call — over a
/// cookie-carrying Dio configured as `DioClient` is.
///
/// Known backend limitations (LL-1..LL-3) are exercised and their observed
/// behaviour printed as `[observed]`, never "fixed": the backend is out of
/// scope (Rule 0).
///
/// WRITES TO THE SHARED DATABASES. Everything it creates is marked and is
/// LEFT IN PLACE on purpose, for reproducing the integration later:
///   - Mongo users `zz.flutter.lawyer.<stamp>@example.com` (LAWZZ<n>) and
///     `zz.flutter.lawyer2.<stamp>@example.com` (LAWZZB<n>)
///   - Supabase `firs` row `FIRZZFLUTTERL<n>` (+ its PDF in bucket `firs`),
///     assigned in the end to the second lawyer by the takeover probe
///   - rows in `case_hearings`, `case_deadlines`, `case_drafts` for that FIR
///
///   flutter test test_live/lawyer_live_test.dart \
///       --dart-define=API_BASE_URL=http://127.0.0.1:5000
void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final tail = '$stamp'.substring('$stamp'.length - 10);
  final firNo = 'FIRZZFLUTTERL$tail';
  final email = 'zz.flutter.lawyer.$stamp@example.com';
  final email2 = 'zz.flutter.lawyer2.$stamp@example.com';
  final lawyerId = 'LAWZZ$tail';
  final lawyer2Id = 'LAWZZB$tail';
  const password = 'LiveProbe123!';

  late Dio dio;
  late AuthRemoteDataSource auth;
  late LawyerRemoteDataSource lawyer;

  void observed(String line) => stdout.writeln('[observed] $line');

  /// A session of its own, as a second handset would have.
  Dio sessionDio() {
    final d = createLiveDio()
      ..options.receiveTimeout = const Duration(seconds: 180);
    d.interceptors.insert(0, CookieManager(CookieJar(ignoreExpires: true)));
    return d;
  }

  setUpAll(() {
    dio = sessionDio();
    auth = AuthRemoteDataSource(dio);
    lawyer = LawyerRemoteDataSource(dio);
  });

  tearDownAll(() {
    stdout.writeln(
      'Live lawyer records left in place: users $email ($lawyerId), '
      '$email2 ($lawyer2Id); FIR $firNo and its hearings/deadlines/drafts.',
    );
  });

  group('L-1..L-3 registration, login, session', () {
    test('a lawyer registers with a LAW ID', () async {
      final r = await auth.signup(
        SignupRequest(
          fullName: 'ZZ Flutter Lawyer',
          email: email,
          password: password,
          role: UserRole.lawyer,
          uniqueId: lawyerId,
        ),
      );
      expect(r.uniqueId, lawyerId);
    });

    test('signs in and the session is a lawyer\'s', () async {
      final login =
          await auth.login(LoginRequest(email: email, password: password));
      expect(login.role, UserRole.lawyer);
      final me = await auth.me();
      expect(me.loggedIn, isTrue);
      expect(me.role, UserRole.lawyer);
    });

    test('the profile carries the account name (the greeting)', () async {
      final p = await lawyer.profile();
      expect(p, isNotNull);
      expect(p!.fullname, 'ZZ Flutter Lawyer');
      expect(p.uniqueId, lawyerId);
    });
  });

  group('test FIR (Police flow)', () {
    test('files FIR $firNo through the police data source', () async {
      final receipt = await FirRemoteDataSource(createLiveDio()).register(
        FirSubmission(
          FirDraft(
            firNo: firNo,
            district: 'Delhi',
            policeStation: 'North Delhi PS',
            firDate: '2026-09-20',
            occurrenceDate: '2026-09-19',
            complainantName: 'ZZ Flutter Complainant',
            detailsOfAccused: 'ZZ unknown accused',
            statement: 'ZZ lawyer live probe: a phone was snatched near the '
                'bus stand at noon.',
            sections: const [ActSection(act: 'IPC', section: '379')],
          ),
        ),
      );
      expect(receipt.firNo, firNo);
      expect(receipt.status, 'Saved to Police Records');
    });
  });

  group('L-10, L-11 My Cases and claiming', () {
    test('before claiming, the FIR is not among my cases', () async {
      final cases = await lawyer.cases();
      expect(cases.map((c) => c.firNo), isNot(contains(firNo)));
    });

    test('an unknown FIR cannot be claimed: "FIR not found"', () async {
      await expectLater(
        lawyer.claim('FIRZZNOSUCH$tail'),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'FIR not found'),
        ),
      );
    });

    test('claims the test FIR', () async {
      await lawyer.claim(firNo);
    });

    // LL-1: the list is every FIR filtered on the phone.
    test('it is now my only case; the list came from all FIRs', () async {
      final cases = await lawyer.cases();
      expect(cases.map((c) => c.firNo), [firNo]);
      final all = await dio.get<dynamic>(ApiEndpoints.firRecords);
      observed(
        'LL-1: /api/fir-records returned ${(all.data as List).length} FIRs '
        'to show this lawyer ${cases.length}.',
      );
    });
  });

  group('L-13..L-15 workspace: overview, status, share with client', () {
    test('overview reads the FIR row with the lawyer columns', () async {
      final c = await lawyer.caseDetail(firNo);
      expect(c.complainantName, 'ZZ Flutter Complainant');
      expect(c.statusLabel, 'Saved to Police Records');
      expect(c.visibleToClient, isFalse);
      const lawyerColumns = [
        'assigned_lawyer_id',
        'visible_to_client',
        'client_note',
        'next_hearing_date',
      ];
      final present = lawyerColumns.where(c.raw.containsKey).join(', ');
      observed('lawyer columns present: $present');
    });

    test('an unshared case is not visible to a citizen', () async {
      await expectLater(
        CaseStatusRemoteDataSource(createLiveDio()).lookup(firNo),
        throwsA(isA<Failure>()),
      );
    });

    test('an invalid status is refused: "Invalid status"', () async {
      await expectLater(
        lawyer.updateStatus(firNo, 'Won'),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'Invalid status'),
        ),
      );
    });

    test('status → Court Proceedings', () async {
      await lawyer.updateStatus(firNo, 'Court Proceedings');
      expect((await lawyer.caseDetail(firNo)).status, 'Court Proceedings');
    });

    test('Police now read the lawyer\'s status on the record', () async {
      final record = await FirRemoteDataSource(createLiveDio()).record(firNo);
      expect(record.status, 'Court Proceedings');
      observed('cross-role: Police FIR record status is now '
          '"${record.status}" (was "Saved to Police Records").');
    });

    test('Send to Client → the citizen sees status and note', () async {
      await lawyer.setClientVisibility(
        firNo,
        visible: true,
        note: 'ZZ probe: chargesheet filed.',
      );
      final seen =
          await CaseStatusRemoteDataSource(createLiveDio()).lookup(firNo);
      expect(seen.status, 'Court Proceedings');
      expect(seen.clientNote, 'ZZ probe: chargesheet filed.');
      expect(seen.clientNoteUpdatedAt, isNotEmpty);
    });

    test('Stop sharing → the citizen no longer sees it', () async {
      await lawyer.setClientVisibility(
        firNo,
        visible: false,
        note: 'ZZ probe: chargesheet filed.',
      );
      await expectLater(
        CaseStatusRemoteDataSource(createLiveDio()).lookup(firNo),
        throwsA(isA<Failure>()),
      );
      // Shared again, so the record stays useful for a later citizen check.
      await lawyer.setClientVisibility(
        firNo,
        visible: true,
        note: 'ZZ probe: chargesheet filed.',
      );
    });
  });

  group('L-17 documents', () {
    test('the evidence list answers (empty for a new FIR)', () async {
      expect(await lawyer.documents(firNo), isEmpty);
    });
  });

  group('L-18 hearings', () {
    test('adds a hearing; next_hearing_date follows it', () async {
      await lawyer.addHearing(firNo, '2099-01-15', 'ZZ probe hearing');
      final hearings = await lawyer.hearings(firNo);
      expect(hearings.single.hearingDate, startsWith('2099-01-15'));
      expect(hearings.single.note, 'ZZ probe hearing');
      final c = await lawyer.caseDetail(firNo);
      expect(c.nextHearingDate, startsWith('2099-01-15'));
    });
  });

  group('L-19 deadlines', () {
    test('adds, completes and deletes; Home lists the open ones', () async {
      await lawyer.addDeadline(
        firNo,
        deadlineType: 'Bail Application',
        dueDate: '2000-01-01',
        note: 'ZZ overdue probe',
      );
      await lawyer.addDeadline(
        firNo,
        deadlineType: 'Custom',
        dueDate: '2099-12-31',
        note: 'ZZ kept',
      );
      final list = await lawyer.deadlines(firNo);
      expect(list.map((d) => d.dueDate), ['2000-01-01', '2099-12-31']);

      final overdue = list.first;
      expect(overdue.isPastDue(jsTodayUtc()), isTrue);
      final home = await lawyer.upcomingDeadlines();
      expect(home.map((d) => d.dueDate), contains('2000-01-01'));
      expect(home.map((d) => d.dueDate), isNot(contains('2099-12-31')));

      await lawyer.setDeadlineCompleted(firNo, overdue.id, completed: true);
      expect((await lawyer.deadlines(firNo)).first.completed, isTrue);
      expect(
        (await lawyer.upcomingDeadlines()).where((d) => d.firNo == firNo),
        isEmpty,
      );

      await lawyer.deleteDeadline(firNo, overdue.id);
      expect(
        (await lawyer.deadlines(firNo)).map((d) => d.note),
        ['ZZ kept'],
      );
    });
  });

  group('L-20, L-22 drafts', () {
    late String generated;

    test(
      'generates a bail draft from the page\'s prompt',
      () async {
        final c = await lawyer.caseDetail(firNo);
        generated = await lawyer.generateDraft(
          bail: true,
          prompt: LawyerContent.bailPrompt(c.raw),
        );
        expect(generated, isNotEmpty);
        expect(generated, isNot('No draft returned.'));
        observed('bail draft: ${generated.length} chars, starts '
            '"${generated.split('\n').first}"');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test('saves it, lists it per case and across cases, deletes it', () async {
      await lawyer.saveDraft(firNo, 'bail', generated);
      await lawyer.saveDraft(firNo, 'document', 'ZZ probe kept draft');
      final saved = await lawyer.drafts(firNo);
      expect(saved.map((d) => d.kind), containsAll(['bail', 'document']));
      final all = await lawyer.allDrafts();
      expect(all.where((d) => d.firNo == firNo), hasLength(2));

      final bail = saved.firstWhere((d) => d.kind == 'bail');
      await lawyer.deleteDraft(firNo, bail.id);
      expect(
        (await lawyer.drafts(firNo)).map((d) => d.content),
        ['ZZ probe kept draft'],
      );
    });

    test(
      'a general document draft',
      () async {
        final c = await lawyer.caseDetail(firNo);
        final text = await lawyer.generateDraft(
          bail: false,
          prompt: LawyerContent.documentPrompt(c.raw),
        );
        expect(text, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  // LL-2: app.py:1294-1303 returns None whenever Groq answers. Recorded, not
  // fixed; the app shows the website's own error sentence in that case.
  group('L-16, L-21 find-precedents (LL-2)', () {
    Future<void> probe(String label, String query) async {
      try {
        final answer = await lawyer.findPrecedents(query);
        observed('LL-2 $label: HTTP 200 with an answer '
            '(${answer?.length ?? 0} chars) — Groq fallback path.');
      } on LawyerSilentFailure catch (e) {
        observed('LL-2 $label: no JSON answer (${e.debugDetail}) — '
            'the app shows the website\'s error sentence.');
      }
    }

    test(
      'Legal Assistant chip question',
      () async {
        await probe('assistant', 'What is a caveat and how do I file one?');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test(
      'AI Summary query',
      () async {
        final c = await lawyer.caseDetail(firNo);
        await probe('summary', LawyerContent.summaryQuery(c.raw));
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  group('L-23 profile', () {
    test('saves the six fields and reads them back', () async {
      await lawyer.saveProfile(
        const LawyerProfileUpdate(
          phone: '9876543210',
          officeAddress: 'ZZ probe office',
          barEnrollmentNo: 'ZZ/1234/2020',
          yearsExperience: '7',
          practiceArea: 'Criminal Law',
          bio: 'ZZ Flutter live probe account.',
        ),
      );
      final p = await lawyer.profile();
      expect(p!.phone, '9876543210');
      expect(p.yearsExperience, '7');
      expect(p.barEnrollmentNo, 'ZZ/1234/2020');
      expect(p.practiceArea, 'Criminal Law');
    });
  });

  // LL-3: assign-lawyer does not check for an existing assignee. Exercised on
  // the test FIR only; afterwards it belongs to the second test lawyer.
  group('LL-3 takeover probe (test FIR only)', () {
    test('a second lawyer can claim an already-assigned FIR', () async {
      final dio2 = sessionDio();
      final auth2 = AuthRemoteDataSource(dio2);
      final lawyer2 = LawyerRemoteDataSource(dio2);
      await auth2.signup(
        SignupRequest(
          fullName: 'ZZ Flutter Lawyer Two',
          email: email2,
          password: password,
          role: UserRole.lawyer,
          uniqueId: lawyer2Id,
        ),
      );
      await auth2.login(LoginRequest(email: email2, password: password));

      Object? refusal;
      try {
        await lawyer2.claim(firNo);
      } catch (e) {
        refusal = e;
      }
      final firstNow = (await lawyer.cases()).map((c) => c.firNo);
      final secondNow = (await lawyer2.cases()).map((c) => c.firNo);
      observed(
          'LL-3: second claim ${refusal == null ? 'ACCEPTED' : 'refused ($refusal)'}; '
          'first lawyer now has $firstNow, second has $secondNow.');

      // The first lawyer has lost access to its own case's workspace.
      await expectLater(
        lawyer.hearings(firNo),
        completion(isEmpty),
        reason: 'a 403 {error} body reads as an empty list, as on the page',
      );
      expect(await lawyer2.hearings(firNo), isNotEmpty);
    });
  });
}

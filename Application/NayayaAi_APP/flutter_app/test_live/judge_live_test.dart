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
import 'package:nayaya_app/features/judge/data/datasources/judge_remote_data_source.dart';
import 'package:nayaya_app/features/judge/data/models/judge_models.dart';
import 'package:nayaya_app/features/legal/data/datasources/legal_remote_data_source.dart';

import 'live_dio.dart';

/// The Judge Portal's data layer against a REAL NyayaAI server.
///
/// Runs `JudgeRemoteDataSource` — the code the judge screens call — over a
/// cookie-carrying Dio configured as `DioClient` is. Behaviour the analysis
/// could not settle from source (GJ-1: how `case_docket.hearing_date` comes
/// back) is printed as `[observed]`.
///
/// WRITES TO THE SHARED DATABASES, and only these marked records:
///   - Mongo users `zz.flutter.judge.<stamp>@example.com` (JUDZZ<n>) and
///     `zz.flutter.judge2.<stamp>@example.com` (JUDZZB<n>) — LEFT IN PLACE:
///     the app has no supported way to delete an account.
///   - Supabase `case_docket` rows for case IDs `ZZFLUTTER-J<n>…`, owned by the
///     first test judge — DELETED at the end through `DELETE /judge/docket/<id>`.
/// No FIR, hearing, draft or any other role's record is written.
///
///   flutter test test_live/judge_live_test.dart \
///       --dart-define=API_BASE_URL=http://127.0.0.1:5000
void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final tail = '$stamp'.substring('$stamp'.length - 10);
  final email = 'zz.flutter.judge.$stamp@example.com';
  final email2 = 'zz.flutter.judge2.$stamp@example.com';
  final judgeId = 'JUDZZ$tail';
  final judge2Id = 'JUDZZB$tail';
  final caseA = 'ZZFLUTTER-J$tail';
  final caseB = 'ZZFLUTTER-J$tail-B';
  const password = 'LiveProbe123!';

  // A year ahead, on the hour, so no real hearing is near it.
  final when = DateTime.now().add(const Duration(days: 400));
  String at(int hour, int minute) => localInputValue(
        DateTime(when.year, when.month, when.day, hour, minute),
      ).replaceFirst('T', ' ');

  late JudgeRemoteDataSource judge;
  late JudgeRemoteDataSource judge2;
  late JudgeRemoteDataSource signedOut;
  final createdIds = <int>{};

  void observed(String line) => stdout.writeln('[observed] $line');

  Dio sessionDio() {
    final d = createLiveDio()
      ..options.receiveTimeout = const Duration(seconds: 180);
    d.interceptors.insert(0, CookieManager(CookieJar(ignoreExpires: true)));
    return d;
  }

  DocketPayload payload(
    String caseId,
    String hearingDate, {
    String status = 'scheduled',
    String remarks = 'ZZ live probe',
  }) =>
      DocketPayload(
        caseId: caseId,
        hearingDate: hearingDate,
        caseType: 'Criminal',
        urgency: 'normal',
        status: status,
        remarks: remarks,
      );

  Future<Failure> failureOf(Future<void> call) async {
    try {
      await call;
    } on Failure catch (f) {
      return f;
    }
    fail('expected the server to refuse');
  }

  final dio1 = sessionDio();
  final dio2 = sessionDio();

  setUpAll(() {
    judge = JudgeRemoteDataSource(dio1);
    judge2 = JudgeRemoteDataSource(dio2);
    signedOut = JudgeRemoteDataSource(sessionDio());
  });

  tearDownAll(() async {
    // Remove every docket row this run created, through the supported route.
    for (final id in createdIds) {
      try {
        await judge.deleteEntry(id);
      } catch (e) {
        stdout.writeln('[cleanup] could not delete docket entry $id: $e');
      }
    }
    final left = await judge.docket().catchError((_) => <DocketEntry>[]);
    stdout.writeln(
      'Live judge records: users $email ($judgeId), $email2 ($judge2Id) left '
      'in place; docket rows created ${createdIds.toList()}, remaining after '
      'cleanup: ${left.map((e) => e.id).toList()}.',
    );
  });

  group('J-1..J-3 registration, login, session', () {
    test('two judges register with JUD IDs', () async {
      for (final (d, e, id, name) in [
        (dio1, email, judgeId, 'ZZ Flutter Judge'),
        (dio2, email2, judge2Id, 'ZZ Flutter Judge Two'),
      ]) {
        final r = await AuthRemoteDataSource(d).signup(
          SignupRequest(
            fullName: name,
            email: e,
            password: password,
            role: UserRole.judge,
            uniqueId: id,
          ),
        );
        expect(r.uniqueId, id);
      }
    });

    test('sign in; the session is a judge\'s', () async {
      for (final (d, e) in [(dio1, email), (dio2, email2)]) {
        final auth = AuthRemoteDataSource(d);
        final login =
            await auth.login(LoginRequest(email: e, password: password));
        expect(login.role, UserRole.judge);
        final me = await auth.me();
        expect(me.role, UserRole.judge);
      }
    });
  });

  group('authorization', () {
    test('signed out: the docket is refused as a lost judge session', () async {
      final f = await failureOf(signedOut.docket());
      expect(f, isA<AuthFailure>());
      expect((f as AuthFailure).sessionExpired, isTrue);
    });

    test('signed out: research answers "Unauthorized"', () async {
      final f = await failureOf(signedOut.research('anticipatory bail'));
      expect(f.message, 'Unauthorized');
    });

    test('a new judge\'s docket is empty', () async {
      expect(await judge.docket(), isEmpty);
    });
  });

  group('J-9..J-13 docket against the server', () {
    test('create; read back; record how the date is stored (GJ-1)', () async {
      await judge.createEntry(
        payload(caseA, at(10, 0), status: 'completed'),
      );
      final list = await judge.docket();
      final mine = list.where((e) => e.caseId == caseA).toList();
      expect(mine, hasLength(1));
      createdIds.add(mine.single.id!);
      observed('sent hearing_date "${at(10, 0)}", server returned '
          '"${mine.single.hearingDate}"');
      observed('raw row keys: ${mine.single.raw.keys.toList()}');
      // GJ-3: POST stores `scheduled` whatever status was sent.
      expect(mine.single.status, 'scheduled');
    });

    test('duplicate case → the page\'s 409 sentence', () async {
      final f = await failureOf(judge.createEntry(payload(caseA, at(15, 0))));
      expect(f.message, 'Case $caseA is already in your docket.');
    });

    test('a hearing within 30 minutes of another (GJ-1)', () async {
      try {
        await judge.createEntry(payload(caseB, at(10, 10)));
        final list = await judge.docket();
        for (final e in list.where((e) => e.caseId == caseB)) {
          createdIds.add(e.id!);
        }
        observed('conflict check did NOT fire for a hearing 10 min away');
      } on ValidationFailure catch (f) {
        observed('conflict check fired: "${f.message}"');
        expect(f.message, startsWith('Overlaps with case $caseA at '));
      }
    });

    test('a past date → "Hearing date cannot be in the past."', () async {
      final f = await failureOf(
        judge.createEntry(payload('$caseA-PAST', '2020-01-01 10:00')),
      );
      expect(f.message, 'Hearing date cannot be in the past.');
    });

    test('edit through PUT as the page sends it; filters', () async {
      final entry = (await judge.docket()).firstWhere((e) => e.caseId == caseA);
      final sent = editInputValue(entry.hearingDate).replaceFirst('T', ' ');
      observed('edit form would hold "$sent" for stored '
          '"${entry.hearingDate}" (equal: ${sent == entry.hearingDate})');
      await judge.updateEntry(
        entry.id!,
        payload(caseA, sent, status: 'adjourned', remarks: 'ZZ adjourned'),
      );
      final adjourned = await judge.docket(status: 'adjourned');
      expect(adjourned.map((e) => e.caseId), contains(caseA));
      expect(
        adjourned.firstWhere((e) => e.caseId == caseA).remarks,
        'ZZ adjourned',
      );
      expect(
        (await judge.docket(status: 'completed')).map((e) => e.caseId),
        isNot(contains(caseA)),
      );
      expect(
        (await judge.docket(urgency: 'normal')).map((e) => e.caseId),
        contains(caseA),
      );
    });

    test('another judge cannot see, edit or delete it', () async {
      final id =
          (await judge.docket()).firstWhere((e) => e.caseId == caseA).id!;
      expect(await judge2.docket(), isEmpty);
      final put = await failureOf(
        judge2.updateEntry(id, payload(caseA, at(11, 0))),
      );
      expect(put.message, 'not_found');
      final del = await failureOf(judge2.deleteEntry(id));
      expect(del.message, 'not_found');
      expect(
        (await judge.docket()).map((e) => e.id),
        contains(id),
      );
    });
  });

  group('J-11, J-15 FIR records (read only)', () {
    test('the FIR list and one record; an unknown ID is "no linked FIR"',
        () async {
      final firs = await judge.firOptions();
      observed('${firs.length} FIRs in /api/fir-records');
      if (firs.isNotEmpty) {
        final first = firs.firstWhere((f) => f.firNo.isNotEmpty);
        final one = await judge.fir(first.firNo);
        expect(one.firNo, first.firNo);
      }
      final f = await failureOf(judge.fir(caseA));
      expect(f.message, 'No linked FIR record found for this Case ID.');
    });
  });

  group('J-16..J-21 law library', () {
    test('acts, 15 sections a page, section detail', () async {
      final legal = LegalRemoteDataSource(dio1);
      final acts = await legal.acts();
      expect(acts, ['IPC', 'CRPC', 'NIA', 'IEA', 'HMA', 'CPC', 'IDA', 'MVA']);
      final page = await legal.sections('IPC', limit: 15);
      expect(page.sections, hasLength(15));
      observed('IPC: ${page.total} sections, ${page.pages} pages of 15');
      final s = await legal.section('IPC', page.sections.first.section);
      expect(s.title, isNotEmpty);
    });

    test('open-bare-act redirects to India Code (or says it cannot)', () async {
      final d = createLiveDio()..options.followRedirects = false;
      try {
        final r = await d.get<dynamic>(ApiEndpoints.openBareAct('BNS'));
        observed('open-bare-act/BNS → HTTP ${r.statusCode} '
            '${r.headers.value('location') ?? ''}');
        expect(r.statusCode, anyOf(302, 503));
      } on DioException catch (e) {
        observed('open-bare-act/BNS → HTTP ${e.response?.statusCode}');
        expect(e.response?.statusCode, anyOf(302, 503));
      }
    });

    test('precedent research: a topic, an explicit section, off-topic',
        () async {
      final r = await judge.research(
        'Supreme Court precedents on anticipatory bail',
      );
      expect(nested(r.currentLaw!, 'current', 'act'), 'BNSS');
      expect(nested(r.currentLaw!, 'current', 'section'), '482');
      expect(r.directlyRelevant, isNotEmpty);
      observed('anticipatory bail: ${r.directlyRelevant.length} precedents, '
          'synthesis ${r.synthesis == null ? 'null (Groq unavailable)' : 'present'}');

      final explicit = await judge.research('section 302 ipc');
      observed('"section 302 ipc": statutory '
          '${explicit.statutorySections.map((s) => '${s['act']} ${s['section']}').toList()}, '
          'notice "${explicit.noResultNotice}"');

      final off = await judge.research('what is the weather like today');
      expect(off.noResultNotice, contains('does not appear to be'));
      expect(off.synthesis, isNull);
    });
  });

  group('cleanup', () {
    test('delete removes the probe rows', () async {
      for (final id in createdIds.toList()) {
        await judge.deleteEntry(id);
        createdIds.remove(id);
      }
      final left = await judge.docket();
      expect(
        left.where((e) => e.caseId.startsWith('ZZFLUTTER-J$tail')),
        isEmpty,
      );
    });
  });
}

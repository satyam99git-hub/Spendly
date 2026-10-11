import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/di/providers.dart';
import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/authentication/domain/entities/auth_user.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/citizen/presentation/screens/citizen_shell.dart';
import 'package:nayaya_app/features/complaints/presentation/controllers/complaint_providers.dart';
import 'package:nayaya_app/features/evidence/presentation/controllers/evidence_providers.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_form_controller.dart';
import 'package:nayaya_app/features/judge/data/models/judge_models.dart';
import 'package:nayaya_app/features/judge/presentation/controllers/judge_providers.dart';
import 'package:nayaya_app/features/judge/presentation/screens/hearing_form_sheet.dart';
import 'package:nayaya_app/features/judge/presentation/screens/judge_shell.dart';
import 'package:nayaya_app/features/lawyer/presentation/controllers/lawyer_providers.dart';
import 'package:nayaya_app/features/lawyer/presentation/screens/lawyer_shell.dart';
import 'package:nayaya_app/features/legal/presentation/controllers/legal_providers.dart';
import 'package:nayaya_app/features/missing_persons/presentation/controllers/missing_person_providers.dart';
import 'package:nayaya_app/routes/app_router.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_complaint_repository.dart';
import '../../helpers/fake_evidence_repository.dart';
import '../../helpers/fake_fir_repository.dart';
import '../../helpers/fake_judge_repository.dart';
import '../../helpers/fake_lawyer_repository.dart';
import '../../helpers/fake_legal_repository.dart';
import '../../helpers/fake_missing_person_repository.dart';
import '../../helpers/in_memory_secure_storage.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_judge_app.dart';

/// The Judge Portal against judge_dashboard.html: the same sections, words,
/// rules and requests, over fakes for every endpoint.
void main() {
  Finder rich(String text) => find.textContaining(text, findRichText: true);

  group('shell and Home', () {
    testWidgets('lands on Home with the page\'s greeting, stats and upcoming',
        (tester) async {
      final judge = FakeJudgeRepository(
        docketRows: [
          docketRow(id: 1, caseId: 'FIR001', urgency: 'urgent'),
          docketRow(id: 2, caseId: 'FIR002', status: 'adjourned'),
        ],
      );
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));

      expect(rich('Welcome back, Judge.'), findsOneWidget);
      expect(find.text('Powered by NyayaAI · Judge Portal'), findsOneWidget);
      expect(find.text('TOTAL HEARINGS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // total
      // Upcoming lists the scheduled one only.
      expect(find.text('FIR001'), findsOneWidget);
      expect(find.text('FIR002'), findsNothing);
      // The FIR list for the hearing form loads with the page, once.
      expect(judge.firOptionsCalls, 1);
    });

    testWidgets('empty docket: zeros and "No upcoming hearings"',
        (tester) async {
      await pumpJudgeApp(
        tester,
        harness: JudgeHarness(judge: FakeJudgeRepository(docketRows: [])),
      );
      expect(find.text('No upcoming hearings'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(4));
    });

    testWidgets('a failed load says so and retries', (tester) async {
      final judge = FakeJudgeRepository()
        ..docketFailure = const NetworkFailure();
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));

      expect(
        find.textContaining('Cannot reach the NyayaAI server'),
        findsOneWidget,
      );
      judge.docketFailure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('FIR001'), findsOneWidget);
    });

    testWidgets(
        'a session the server no longer treats as a judge\'s offers '
        'signing in again', (tester) async {
      final judge = FakeJudgeRepository()
        ..docketFailure = const AuthFailure.sessionExpired(
          message: 'Your judge session has ended. Please sign in again.',
        );
      final h = await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));

      expect(
        find.text('Your judge session has ended. Please sign in again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();
      expect(h.auth.logoutCount, 1);
    });

    testWidgets(
        'the drawer lists the page\'s five entries; Orders & Drafts '
        'does nothing', (tester) async {
      await pumpJudgeApp(tester);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      for (final label in [
        'Home',
        'Case Docket',
        'Case Workspace',
        'Law Library',
        'Orders & Drafts',
      ]) {
        expect(
          find.descendant(of: find.byType(Drawer), matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(find.text('Judge Portal'), findsOneWidget);
      await tester.tap(find.text('Orders & Drafts'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      // Still on Home.
      expect(rich('Welcome back, Judge.'), findsOneWidget);
    });

    testWidgets('"Add a Hearing" opens the docket and its form',
        (tester) async {
      await pumpJudgeApp(tester);
      await tester.tap(find.text('Add a Hearing'));
      await tester.pumpAndSettle();
      expect(find.text('New Hearing'), findsOneWidget);
    });

    testWidgets('sign-out asks first, then signs out', (tester) async {
      final h = await pumpJudgeApp(tester);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(h.auth.logoutCount, 1);
    });
  });

  group('Case Docket', () {
    testWidgets(
        'lists entries; filters reload with the chosen values; '
        'empty state', (tester) async {
      final judge = FakeJudgeRepository(
        docketRows: [
          docketRow(id: 1, caseId: 'FIR001', remarks: null, caseType: null),
          docketRow(id: 2, caseId: 'FIR002', status: 'completed'),
        ],
      );
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));
      await openJudgeSection(tester, 'Case Docket');

      expect(find.text('FIR002'), findsOneWidget);
      expect(rich('Type: -'), findsOneWidget);
      expect(rich('Remarks: -'), findsOneWidget);

      await tester.tap(find.byKey(const Key('judge-status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled').last);
      await tester.pumpAndSettle();
      expect(judge.docketCalls.last, (status: 'cancelled', urgency: ''));
      expect(find.text('No hearings found'), findsOneWidget);
    });

    testWidgets('delete confirms with the page\'s question, then reloads',
        (tester) async {
      final judge = FakeJudgeRepository();
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));
      await openJudgeSection(tester, 'Case Docket');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this hearing entry?'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(judge.deleted, [1]);
      expect(find.text('No hearings found'), findsOneWidget);
    });

    testWidgets('edit refetches the docket and saves through PUT',
        (tester) async {
      final judge = FakeJudgeRepository();
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));
      await openJudgeSection(tester, 'Case Docket');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Hearing'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('judge-remarks')), 'Moved');
      await tester.tap(find.byKey(const Key('judge-save')));
      await tester.pumpAndSettle();

      expect(judge.updated.single.$1, 1);
      expect(judge.updated.single.$2.remarks, 'Moved');
      // The stored date went back unchanged, in the page's format.
      expect(judge.updated.single.$2.hearingDate, '2099-01-15 10:30');
      expect(find.text('Edit Hearing'), findsNothing);
      expect(rich('Remarks: Moved'), findsOneWidget);
    });
  });

  group('the hearing form', () {
    final now = DateTime(2030, 1, 1, 9);

    Future<FakeJudgeRepository> pumpForm(
      WidgetTester tester, {
      FakeJudgeRepository? judge,
      DocketEntry? entry,
      List<bool?>? results,
    }) async {
      final repo = judge ?? FakeJudgeRepository();
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(400, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [judgeRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final r = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          HearingFormSheet(entry: entry, now: () => now),
                    );
                    results?.add(r);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> pickDate(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('judge-hearing-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    String warning(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const Key('judge-form-warning')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    testWidgets('validates in the page\'s order with the page\'s words',
        (tester) async {
      final repo = await pumpForm(tester);
      final save = find.byKey(const Key('judge-save'));

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(warning(tester), 'Case ID is required.');

      await tester.enterText(find.byKey(const Key('judge-case-id')), 'FIR001');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(warning(tester), 'Hearing date & time is required.');

      await pickDate(tester);
      expect(find.text('2030-01-01 09:00'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      // FIR001 is already in the docket — checked before anything is sent.
      expect(warning(tester), 'Case FIR001 is already in your docket.');
      expect(repo.created, isEmpty);
    });

    testWidgets('saves a new hearing with the page\'s payload', (tester) async {
      final results = <bool?>[];
      final repo = await pumpForm(tester, results: results);

      await tester.enterText(find.byKey(const Key('judge-case-id')), ' NEW1 ');
      await pickDate(tester);
      await tester.enterText(
        find.byKey(const Key('judge-case-type')),
        'Criminal',
      );
      await tester.tap(find.byKey(const Key('judge-urgency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Urgent').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('judge-save')));
      await tester.pumpAndSettle();

      expect(repo.created.single.toJson(), {
        'case_id': 'NEW1',
        'hearing_date': '2030-01-01 09:00',
        'case_type': 'Criminal',
        'urgency': 'urgent',
        'status': 'scheduled',
        'remarks': '',
      });
      expect(results, [true]);
    });

    testWidgets(
        'a refusal is shown and nothing typed is lost; Save is '
        'blocked while sending', (tester) async {
      final repo = FakeJudgeRepository(docketRows: [])
        ..saveFailure = const ValidationFailure(
          'Overlaps with case FIR009 at 2030-01-01 09:15',
        );
      final gate = Completer<void>();
      await pumpForm(tester, judge: repo);
      await tester.enterText(find.byKey(const Key('judge-case-id')), 'NEW2');
      await pickDate(tester);

      repo.gate = gate.future;
      await tester.tap(find.byKey(const Key('judge-save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('judge-save')));
      await tester.pump();
      gate.complete();
      repo.gate = null;
      await tester.pumpAndSettle();

      expect(repo.created, hasLength(1));
      expect(warning(tester), 'Overlaps with case FIR009 at 2030-01-01 09:15');
      expect(find.text('NEW2'), findsOneWidget);
      expect(find.text('2030-01-01 09:00'), findsOneWidget);
    });

    testWidgets('FIR suggestions, pick, and the two preview lines',
        (tester) async {
      final repo = FakeJudgeRepository(
        firRows: [
          judgeFirRow(firNo: 'FIR001'),
          judgeFirRow(firNo: 'FIR002', complainant: 'Ravi', dist: 'Nagpur'),
        ],
      );
      await pumpForm(tester, judge: repo);
      final box = find.byKey(const Key('judge-case-id'));

      await tester.enterText(box, 'nagpur');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('judge-fir-suggestions')), findsOneWidget);
      expect(find.text('Ravi — Nagpur'), findsOneWidget);
      await tester.tap(find.text('FIR002'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('judge-fir-suggestions')), findsNothing);
      expect(find.text('✓ Ravi · Nagpur · BNS 303'), findsOneWidget);

      await tester.enterText(box, 'nothing-like-it');
      await tester.pumpAndSettle();
      expect(find.text('No matching FIR found'), findsOneWidget);
      expect(
        find.textContaining('No matching FIR record found'),
        findsOneWidget,
      );
    });

    testWidgets(
        'editing: an unchanged date is not re-checked, a stored ISO '
        'value counts as changed (as on the page)', (tester) async {
      final past = DocketEntry.fromJson(
        docketRow(id: 3, hearingDate: '2029-12-31 10:00'),
      );
      var repo = await pumpForm(tester, entry: past);
      await tester.tap(find.byKey(const Key('judge-save')));
      await tester.pumpAndSettle();
      expect(repo.updated.single.$1, 3);

      final iso = DocketEntry.fromJson(
        docketRow(id: 4, hearingDate: '2029-12-31T10:00:00'),
      );
      repo = await pumpForm(tester, entry: iso);
      await tester.tap(find.byKey(const Key('judge-save')));
      await tester.pumpAndSettle();
      expect(warning(tester), 'Hearing date cannot be in the past.');
      expect(repo.updated, isEmpty);
    });
  });

  group('Case Workspace', () {
    testWidgets('cards per case; detail shows FIR details and the timeline',
        (tester) async {
      final judge = FakeJudgeRepository(
        docketRows: [
          docketRow(id: 1, caseId: 'FIR001', remarks: null),
          docketRow(id: 2, caseId: 'ZZ-NOFIR', caseType: null),
        ],
      );
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));
      await openJudgeSection(tester, 'Case Workspace');

      expect(find.text('Criminal · 1 hearing'), findsOneWidget);
      expect(find.text('General · 1 hearing'), findsOneWidget);

      await tester.tap(find.text('FIR001'));
      await tester.pumpAndSettle();
      expect(find.text('FIR DETAILS'), findsOneWidget);
      expect(rich('Complainant: Asha Rao'), findsOneWidget);
      expect(rich('Police Station: Shivajinagar PS'), findsOneWidget);
      expect(find.text('HEARING TIMELINE'), findsOneWidget);
      expect(find.text('No remarks'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to cases'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZZ-NOFIR'));
      await tester.pumpAndSettle();
      expect(
        find.text('No linked FIR record found for this Case ID.'),
        findsOneWidget,
      );
    });

    testWidgets('empty docket', (tester) async {
      await pumpJudgeApp(
        tester,
        harness: JudgeHarness(judge: FakeJudgeRepository(docketRows: [])),
      );
      await openJudgeSection(tester, 'Case Workspace');
      expect(find.text('No cases in your docket yet.'), findsOneWidget);
    });
  });

  group('Law Library', () {
    testWidgets('nothing is fetched until the library is opened',
        (tester) async {
      final h = await pumpJudgeApp(tester);
      expect(h.legal.pagesAsked, isEmpty);
      await openJudgeSection(tester, 'Law Library');
      expect(find.text('IPC'), findsOneWidget);
      expect(find.text('Repealed — see BNS'), findsOneWidget);
      expect(find.text('Open Current Law (BNS) ↗'), findsOneWidget);
      expect(find.text('Current law'), findsOneWidget); // NIA
      expect(find.text('Select an act to browse its sections'), findsOneWidget);
    });

    testWidgets('browse 15 a page, page through, bookmark, list, remove',
        (tester) async {
      final h = await pumpJudgeApp(tester);
      await openJudgeSection(tester, 'Law Library');

      await tester.tap(find.byKey(const Key('judge-act-IPC')));
      await tester.pumpAndSettle();
      expect(h.legal.pagesAsked.last, (act: 'IPC', search: '', page: 1));
      expect(find.text('Section 15'), findsOneWidget);
      expect(find.text('Section 16'), findsNothing);
      expect(find.text('Page 1 of 4'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Section 16'), findsOneWidget);
      expect(find.text('Page 2 of 4'), findsOneWidget);

      await tester.tap(find.text('Section 16'));
      await tester.pumpAndSettle();
      expect(find.text('IPC § 16 — IPC section 16'), findsOneWidget);
      await tester.tap(find.text('☆ Bookmark'));
      await tester.pumpAndSettle();
      expect(find.text('★ Bookmarked'), findsOneWidget);
      expect(
        jsonDecode(h.storage.values['nyayaai_judge_bookmarks']!),
        [
          {'act': 'IPC', 'section': '16', 'title': 'IPC section 16'},
        ],
      );
      Navigator.of(tester.element(find.text('★ Bookmarked'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('★'), findsOneWidget);

      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      expect(find.text('IPC § 16'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('No bookmarked sections yet'), findsOneWidget);
      expect(
        jsonDecode(h.storage.values['nyayaai_judge_bookmarks']!),
        isEmpty,
      );
    });

    testWidgets('search waits 350 ms and only runs with an act chosen',
        (tester) async {
      final h = await pumpJudgeApp(tester);
      await openJudgeSection(tester, 'Law Library');

      await tester.enterText(
        find.byKey(const Key('judge-section-search')),
        'theft',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.legal.pagesAsked, isEmpty);

      await tester.tap(find.byKey(const Key('judge-act-IPC')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('judge-section-search')),
        'theft',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.legal.pagesAsked.length, 1);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(h.legal.pagesAsked.last, (act: 'IPC', search: 'theft', page: 1));
      expect(find.text('Punishment for theft'), findsOneWidget);
    });

    testWidgets('a stored bookmark opens through section-detail',
        (tester) async {
      final storage = InMemorySecureStorage({
        'nyayaai_judge_bookmarks': jsonEncode([
          {'act': 'CRPC', 'section': '41', 'title': 'Arrest'},
          {'act': 'IPC', 'section': '9999', 'title': 'Missing'},
        ]),
      });
      await pumpJudgeApp(tester, harness: JudgeHarness(storage: storage));
      await openJudgeSection(tester, 'Law Library');
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CRPC § 41'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Any police officer may'), findsOneWidget);
      expect(find.text('★ Bookmarked'), findsOneWidget);
      Navigator.of(tester.element(find.text('★ Bookmarked'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('IPC § 9999'));
      await tester.pumpAndSettle();
      expect(find.text('Section not found'), findsOneWidget);
    });

    testWidgets('precedent research renders the reply\'s blocks in order',
        (tester) async {
      final judge = FakeJudgeRepository()
        ..researchResult = PrecedentResearch.fromJson({
          'current_law': {
            'topic_label': 'Anticipatory Bail',
            'current': {
              'act': 'BNSS',
              'section': '482',
              'subject': 'Direction for grant of bail',
            },
            'historical': {'act': 'CrPC', 'section': '438'},
          },
          'directly_relevant': [
            {
              'case': 'Gurbaksh Singh Sibbia v. State of Punjab',
              'citation': '(1980) 2 SCC 565',
              'court': 'Supreme Court of India',
              'bench': 'Constitution Bench',
              'year': 1980,
              'statute_then': {'act': 'CrPC', 'section': '438'},
              'key_holding': 'Discretion is judicial.',
              'why_relevant': 'Foundational.',
              'verification_status': 'Verified',
              'source_url': 'https://indiankanoon.org/doc/548421/',
              'later_development_text': null,
            },
          ],
          'related_authorities': [],
          'principles': [
            {'principle': 'Nature', 'explanation': 'Pre-arrest protection.'},
          ],
          'statutory_sections': [
            {
              'act': 'BNSS',
              'section': '482',
              'subject': 'S',
              'status': 'Current',
            },
          ],
          'synthesis': {
            'summary': 'Short summary.',
            'current_position': 'Now.',
            'historical_position': '',
            'qualification': '',
          },
          'sources': [
            {
              'case': 'Gurbaksh Singh Sibbia v. State of Punjab',
              'citation': '(1980) 2 SCC 565',
              'verification_status': 'Verified',
            },
          ],
          'no_result_notice': null,
          'ai_notice': 'AI-generated summary.',
        });
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));
      await openJudgeSection(tester, 'Law Library');
      await tester.tap(find.text('Precedent Research'));
      await tester.pumpAndSettle();

      // An empty question sends nothing.
      await tester.tap(find.byKey(const Key('judge-research-run')));
      await tester.pumpAndSettle();
      expect(judge.researchQueries, isEmpty);

      await tester.enterText(
        find.byKey(const Key('judge-research-query')),
        'anticipatory bail',
      );
      await tester.tap(find.byKey(const Key('judge-research-run')));
      await tester.pumpAndSettle();

      expect(judge.researchQueries, ['anticipatory bail']);
      for (final heading in [
        'CURRENT LAW',
        'DIRECTLY RELEVANT PRECEDENTS',
        'KEY LEGAL PRINCIPLES',
        'RELEVANT STATUTORY PROVISIONS',
        'AI-GENERATED RESEARCH SYNTHESIS',
        'SOURCES & VERIFICATION',
      ]) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text('Section 482 — BNSS'), findsOneWidget);
      expect(rich('Key Holding: Discretion is judicial.'), findsOneWidget);
      expect(find.text('Source ↗'), findsOneWidget);
      expect(find.text('AI-generated summary.'), findsOneWidget);
      expect(rich('Historical-law position'), findsNothing);
    });

    testWidgets('research: the off-topic notice, and an error', (tester) async {
      final judge = FakeJudgeRepository()
        ..researchResult = PrecedentResearch.fromJson(const {
          'directly_relevant': [],
          'no_result_notice': 'This does not appear to be an Indian legal '
              'research query.',
          'synthesis': null,
        });
      await pumpJudgeApp(tester, harness: JudgeHarness(judge: judge));
      await openJudgeSection(tester, 'Law Library');
      await tester.tap(find.text('Precedent Research'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('judge-research-query')),
        'weather',
      );
      await tester.tap(find.byKey(const Key('judge-research-run')));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not appear to be'), findsOneWidget);

      judge.researchFailure = const ServerFailure(
        message: 'Something went wrong. Please try again.',
      );
      await tester.tap(find.byKey(const Key('judge-research-run')));
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('every section lays out at 320 px wide', (tester) async {
    await pumpJudgeApp(tester, size: const Size(320, 2000));
    for (final s in ['Case Docket', 'Case Workspace', 'Law Library', 'Home']) {
      await openJudgeSection(tester, s);
      expect(tester.takeException(), isNull, reason: s);
    }
    await openJudgeSection(tester, 'Case Docket');
    await tester.tap(find.text('+ New Hearing'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('role routing (real router)', () {
    Future<void> pumpSignedIn(WidgetTester tester, UserRole role) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(400, 1400);
      addTearDown(tester.view.reset);
      final auth = FakeAuthRepository()
        ..restoreResult = AuthUser(
          role: role,
          uniqueId: '${role.idPrefix}001',
          fullName: 'Test ${role.label}',
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            firRepositoryProvider.overrideWithValue(FakeFirRepository()),
            evidenceRepositoryProvider
                .overrideWithValue(FakeEvidenceRepository()),
            complaintRepositoryProvider
                .overrideWithValue(FakeComplaintRepository()),
            missingPersonRepositoryProvider
                .overrideWithValue(FakeMissingPersonRepository()),
            lawyerRepositoryProvider.overrideWithValue(FakeLawyerRepository()),
            judgeRepositoryProvider.overrideWithValue(FakeJudgeRepository()),
            legalRepositoryProvider.overrideWithValue(FakeLegalRepository()),
            secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: ref.watch(appRouterProvider),
            ),
          ),
        ),
      );
      await settleStartup(tester);
      await tester.pumpAndSettle();
    }

    testWidgets('a judge lands on the Judge Portal', (tester) async {
      await pumpSignedIn(tester, UserRole.judge);
      expect(find.byType(JudgeShell), findsOneWidget);
    });

    for (final path in [
      '/law',
      '/evidence/add',
      '/complaints/CMP-1',
      '/missing-persons',
      '/citizen/missing-persons/MP_1',
    ]) {
      testWidgets('a judge sent to $path stays on the Judge Portal',
          (tester) async {
        await pumpSignedIn(tester, UserRole.judge);
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
        await tester.pumpAndSettle();
        expect(find.byType(JudgeShell), findsOneWidget);
      });
    }

    for (final role in [UserRole.police, UserRole.citizen, UserRole.lawyer]) {
      testWidgets('a ${role.wireValue} never sees the Judge Portal',
          (tester) async {
        await pumpSignedIn(tester, role);
        expect(find.byType(JudgeShell), findsNothing);
        if (role == UserRole.citizen) {
          expect(find.byType(CitizenShell), findsOneWidget);
        }
        if (role == UserRole.lawyer) {
          expect(find.byType(LawyerShell), findsOneWidget);
        }
      });
    }

    testWidgets('signing out from the Judge Portal returns to sign-in',
        (tester) async {
      await pumpSignedIn(tester, UserRole.judge);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(JudgeShell)),
      );
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(container.read(authControllerProvider).isSignedIn, isFalse);
      expect(find.text('Email address'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/lawyer/data/datasources/lawyer_remote_data_source.dart';
import 'package:nayaya_app/features/lawyer/data/models/lawyer_models.dart';

import '../../helpers/fake_lawyer_repository.dart';
import '../../helpers/pump_lawyer_app.dart';

/// The Lawyer Portal, section by section, against
/// `website/templates/lawyer_dashboard.html`. Every string asserted here is the
/// page's own.
void main() {
  LawyerHarness harnessWith(List<Map<String, dynamic>> rows) => LawyerHarness(
        lawyer: FakeLawyerRepository(
          cases: [for (final r in rows) LawyerCase.fromJson(r)],
        ),
      );

  Future<void> openCase(WidgetTester tester, String firNo) async {
    await openLawyerSection(tester, 'My Cases');
    await tester.tap(find.text('FIR: $firNo'));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    // The tab bar scrolls; the later tabs start off-screen on a phone.
    await tester.ensureVisible(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
  }

  group('shell (lines 216-284)', () {
    testWidgets('five sections in the sidebar\'s order, and the badge', (
      tester,
    ) async {
      await pumpLawyerApp(tester);
      expect(find.text('Lawyer'), findsOneWidget);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Lawyer Portal'), findsOneWidget);
      final labels = [
        'Home',
        'My Cases',
        'Case Workspace',
        'Legal Assistant',
        'Drafts',
      ];
      final ys = [
        for (final l in labels)
          tester
              .getTopLeft(
                find.descendant(
                  of: find.byType(Drawer),
                  matching: find.text(l),
                ),
              )
              .dy,
      ];
      expect([...ys]..sort(), ys);
      // The account's name, from the server, at the foot.
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Meera Iyer'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sign out is immediate, as the page\'s link is', (
      tester,
    ) async {
      final h = await pumpLawyerApp(tester);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(h.auth.logoutCount, 1);
    });
  });

  group('Home (lines 287-393)', () {
    testWidgets('greets by name and counts the cases', (tester) async {
      await pumpLawyerApp(
        tester,
        harness: harnessWith([
          firRow(firNo: 'A', status: 'Investigation'),
          firRow(firNo: 'B', status: 'Court Proceedings'),
          firRow(firNo: 'C', status: 'Trial'),
        ]),
      );
      expect(find.textContaining('Welcome back, '), findsOneWidget);
      expect(find.textContaining('Meera Iyer.'), findsOneWidget);
      expect(find.text('TOTAL CASES'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('No upcoming hearings scheduled.'), findsOneWidget);
      expect(
        find.text('No deadlines due in the next 14 days.'),
        findsOneWidget,
      );
    });

    testWidgets('a deadline opens its case', (tester) async {
      final h = harnessWith([firRow(firNo: 'FIR7')]);
      h.lawyer.upcoming = [
        const CaseDeadline(
          id: 1,
          firNo: 'FIR7',
          deadlineType: 'Bail Application',
          dueDate: '2000-01-01',
          note: '',
          completed: false,
        ),
      ];
      await pumpLawyerApp(tester, harness: h);
      expect(find.text('2000-01-01 — OVERDUE'), findsOneWidget);

      await tester.tap(find.text('2000-01-01 — OVERDUE'));
      await tester.pumpAndSettle();
      expect(find.text('FIR: FIR7'), findsOneWidget);
      expect(find.text('DISTRICT'), findsOneWidget);
    });

    testWidgets('"Add a Case" goes to My Cases', (tester) async {
      await pumpLawyerApp(tester);
      await tester.tap(find.text('Add a Case'));
      await tester.pumpAndSettle();
      expect(find.text('ADD A CASE'), findsOneWidget);
    });
  });

  group('My Cases (lines 396-463, 1478-1517)', () {
    testWidgets('cards, search and the empty state', (tester) async {
      await pumpLawyerApp(
        tester,
        harness: harnessWith([
          firRow(firNo: 'FIR1', complainant: 'Asha Rao'),
          firRow(firNo: 'FIR2', complainant: 'Ravi Kumar'),
        ]),
      );
      await openLawyerSection(tester, 'My Cases');
      expect(find.text('Client: Asha Rao'), findsOneWidget);
      expect(find.text('Next Hearing: —'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, 'ravi');
      await tester.pumpAndSettle();
      expect(find.text('Client: Asha Rao'), findsNothing);
      expect(find.text('Client: Ravi Kumar'), findsOneWidget);
    });

    testWidgets('no cases', (tester) async {
      await pumpLawyerApp(tester, harness: harnessWith([]));
      await openLawyerSection(tester, 'My Cases');
      expect(
        find.text('No cases yet. Add one above using an FIR number.'),
        findsOneWidget,
      );
    });

    testWidgets('an empty FIR number is refused before any request', (
      tester,
    ) async {
      final h = await pumpLawyerApp(tester);
      await openLawyerSection(tester, 'My Cases');
      await tester.tap(find.text('Add Case'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an FIR number.'), findsOneWidget);
      expect(h.lawyer.claimed, isEmpty);
    });

    testWidgets('a refused claim shows the server\'s reason', (tester) async {
      final h = LawyerHarness();
      h.lawyer.claimFailure = const ValidationFailure('FIR not found');
      await pumpLawyerApp(tester, harness: h);
      await openLawyerSection(tester, 'My Cases');
      await tester.enterText(find.byType(TextField).at(1), 'FIR404');
      await tester.tap(find.text('Add Case'));
      await tester.pumpAndSettle();
      expect(find.text('FIR not found'), findsOneWidget);
    });

    testWidgets('a claim reloads the portal onto Home', (tester) async {
      final h = await pumpLawyerApp(tester);
      final loadsBefore = h.lawyer.caseLoads;
      await openLawyerSection(tester, 'My Cases');
      await tester.enterText(find.byType(TextField).at(1), '  FIR0008 ');
      await tester.tap(find.text('Add Case'));
      await tester.pump();
      expect(h.lawyer.claimed, ['FIR0008']);
      expect(find.text('Case added. Refreshing…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome back, '), findsOneWidget);
      expect(h.lawyer.caseLoads, greaterThan(loadsBefore));
    });
  });

  group('Case Workspace (lines 546-748)', () {
    testWidgets('empty until a case is opened', (tester) async {
      await pumpLawyerApp(tester);
      await openLawyerSection(tester, 'Case Workspace');
      expect(find.text('Select a case from '), findsOneWidget);
    });

    testWidgets('Overview shows the FIR and changes its status', (
      tester,
    ) async {
      final h = await pumpLawyerApp(tester);
      await openCase(tester, 'FIR001');
      expect(find.text('Client: Asha Rao'), findsOneWidget);
      expect(find.text('Shivajinagar PS'), findsOneWidget);
      expect(find.text('Not shared'), findsOneWidget);

      await tester.tap(find.text('Change status…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trial').last);
      await tester.pump();
      expect(h.lawyer.statusChanges, [('FIR001', 'Trial')]);
      expect(find.text('✓ Updated'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('✓ Updated'), findsNothing);
    });

    testWidgets('a refused status change shows its reason', (tester) async {
      final h = LawyerHarness();
      h.lawyer.statusFailure = const ValidationFailure('Forbidden');
      await pumpLawyerApp(tester, harness: h);
      await openCase(tester, 'FIR001');
      await tester.tap(find.text('Change status…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Closed').last);
      await tester.pumpAndSettle();
      expect(find.text('Forbidden'), findsOneWidget);
    });

    testWidgets('Send to Client shares it; Stop sharing hides it', (
      tester,
    ) async {
      final h = await pumpLawyerApp(tester);
      await openCase(tester, 'FIR001');

      await tester.enterText(find.byType(TextField).last, ' Hearing moved ');
      await tester.tap(find.text('Send to Client'));
      await tester.pumpAndSettle();
      expect(
        h.lawyer.visibilityChanges.last,
        ('FIR001', true, 'Hearing moved'),
      );
      expect(find.text('✓ Sent — visible to client now.'), findsOneWidget);
      expect(find.text('Visible to client'), findsOneWidget);

      await tester.tap(find.text('Stop sharing with client'));
      await tester.pumpAndSettle();
      expect(h.lawyer.visibilityChanges.last.$2, isFalse);
      expect(find.text('✓ Hidden from client.'), findsOneWidget);
      expect(find.text('Not shared'), findsOneWidget);
    });

    testWidgets('a failed share reads "Could not send. <reason>"', (
      tester,
    ) async {
      final h = LawyerHarness();
      h.lawyer.visibilityFailure = const ValidationFailure('Forbidden');
      await pumpLawyerApp(tester, harness: h);
      await openCase(tester, 'FIR001');
      await tester.tap(find.text('Send to Client'));
      await tester.pumpAndSettle();
      expect(find.text('Could not send. Forbidden'), findsOneWidget);
    });

    testWidgets('AI Summary sends the page\'s query and renders Markdown', (
      tester,
    ) async {
      final h = await pumpLawyerApp(tester);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'AI Summary');
      await tester.tap(find.text('Generate Case Summary'));
      await tester.pumpAndSettle();
      expect(
        h.lawyer.precedentQueries.single,
        startsWith('Summarize this case for the assigned lawyer: FIR FIR001'),
      );
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    // LL-2: the endpoint 500s whenever Groq answers.
    testWidgets('a failed summary reads the page\'s sentence', (tester) async {
      final h = LawyerHarness();
      h.lawyer.precedentFailure = const LawyerSilentFailure('HTTP 500');
      await pumpLawyerApp(tester, harness: h);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'AI Summary');
      await tester.tap(find.text('Generate Case Summary'));
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong generating the summary.'),
        findsOneWidget,
      );
    });

    testWidgets('Documents lists the locker\'s files', (tester) async {
      final h = LawyerHarness();
      h.lawyer.documentsByFir['FIR001'] = const [
        CaseDocument(
          filename: 'scene.jpg',
          fileType: 'image',
          fileUrl: '/evidence-file/FIR001/scene.jpg',
        ),
      ];
      await pumpLawyerApp(tester, harness: h);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'Documents');
      expect(find.text('scene.jpg'), findsOneWidget);
      expect(find.text('IMAGE'), findsOneWidget);
      expect(find.text('VIEW'), findsOneWidget);
    });

    testWidgets('Documents: empty', (tester) async {
      await pumpLawyerApp(tester);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'Documents');
      expect(
        find.text('No documents uploaded for this case yet.'),
        findsOneWidget,
      );
    });

    testWidgets('Hearings: nothing is sent without a date', (tester) async {
      final h = await pumpLawyerApp(tester);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'Hearings');
      expect(find.text('No hearings scheduled yet.'), findsOneWidget);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(h.lawyer.hearingsAdded, isEmpty);
    });

    testWidgets('Deadlines: overdue, complete and delete', (tester) async {
      final h = LawyerHarness();
      h.lawyer.deadlinesByFir['FIR001'] = [
        const CaseDeadline(
          id: 5,
          firNo: 'FIR001',
          deadlineType: 'Appeal Limitation',
          dueDate: '2000-01-01',
          note: 'file early',
          completed: false,
        ),
      ];
      await pumpLawyerApp(tester, harness: h);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'Deadlines');
      expect(find.text('2000-01-01 — OVERDUE'), findsOneWidget);
      expect(find.text('file early'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(h.lawyer.deadlineToggles, [('FIR001', 5, true)]);

      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(h.lawyer.deadlinesDeleted, [('FIR001', 5)]);
      expect(find.text('No deadlines tracked yet.'), findsOneWidget);
    });

    testWidgets('Drafts: generate, save, view and delete', (tester) async {
      final h = await pumpLawyerApp(tester);
      await openCase(tester, 'FIR001');
      await openTab(tester, 'Drafts');
      expect(find.text('No saved drafts for this case yet.'), findsOneWidget);

      await tester.tap(find.text('Bail Application'));
      await tester.pumpAndSettle();
      expect(h.lawyer.draftPrompts.single.$1, isTrue);
      expect(
        h.lawyer.draftPrompts.single.$2,
        contains('Court: SESSIONS COURT'),
      );

      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      expect(h.lawyer.draftsSaved.single.$2, 'bail');
      expect(find.text('✓ Draft saved.'), findsOneWidget);
      expect(find.textContaining('Bail  2026'), findsOneWidget);

      await tester.tap(find.text('VIEW'));
      await tester.pumpAndSettle();
      expect(find.text('Save Draft'), findsNothing);

      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(h.lawyer.draftsDeleted, hasLength(1));
      expect(find.text('No saved drafts for this case yet.'), findsOneWidget);
    });
  });

  group('Legal Assistant (lines 466-514, 1569-1605)', () {
    testWidgets('a chip asks its question', (tester) async {
      final h = await pumpLawyerApp(tester);
      await openLawyerSection(tester, 'Legal Assistant');
      await tester.tap(find.text('Filing a caveat'));
      await tester.pumpAndSettle();
      expect(
        h.lawyer.precedentQueries,
        ['What is a caveat and how do I file one?'],
      );
      expect(find.text('Answer'), findsOneWidget);
    });

    testWidgets('an empty question does nothing', (tester) async {
      final h = await pumpLawyerApp(tester);
      await openLawyerSection(tester, 'Legal Assistant');
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(h.lawyer.precedentQueries, isEmpty);
    });

    testWidgets('"Thinking…" while waiting, then the failure sentence', (
      tester,
    ) async {
      final h = LawyerHarness();
      h.lawyer.precedentFailure = const LawyerSilentFailure('HTTP 500');
      await pumpLawyerApp(tester, harness: h);
      await openLawyerSection(tester, 'Legal Assistant');
      await tester.enterText(find.byType(TextField), 'How do I file?');
      await tester.tap(find.text('Ask'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('Drafts (lines 518-543, 1520-1566)', () {
    testWidgets('lists every draft; VIEW previews; OPEN CASE opens it', (
      tester,
    ) async {
      final h = LawyerHarness();
      h.lawyer.allDraftList = const [
        CaseDraft(
          id: 1,
          firNo: 'FIR001',
          kind: 'document',
          content: '# Petition',
          createdAt: '2026-09-27',
        ),
      ];
      await pumpLawyerApp(tester, harness: h);
      await openLawyerSection(tester, 'Drafts');
      expect(find.text('All Drafts'), findsOneWidget);
      expect(find.textContaining('Document  2026-09-27'), findsOneWidget);

      await tester.tap(find.text('VIEW'));
      await tester.pumpAndSettle();
      expect(find.text('Draft Preview'), findsOneWidget);

      await tester.tap(find.text('OPEN CASE'));
      await tester.pumpAndSettle();
      expect(find.text('FIR: FIR001'), findsOneWidget);
    });

    testWidgets('no drafts', (tester) async {
      await pumpLawyerApp(tester);
      await openLawyerSection(tester, 'Drafts');
      expect(
        find.text(
          "No drafts saved yet. Open a case's workspace to generate and save "
          'one.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Profile (lines 751-832, 1607-1731)', () {
    Future<void> openProfile(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Meera Iyer'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('loads, validates and saves', (tester) async {
      final h = await pumpLawyerApp(tester);
      await openProfile(tester);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('LAW001'), findsOneWidget);
      expect(find.text('meera@example.com'), findsOneWidget);

      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '98765');
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();
      expect(
        find.text('Phone number must be exactly 10 digits.'),
        findsOneWidget,
      );
      expect(h.lawyer.profileSaves, isEmpty);

      await tester.enterText(fields.at(0), '9876543210');
      await tester.enterText(fields.at(1), '12');
      await tester.tap(find.text('Save Profile'));
      await tester.pump();
      expect(h.lawyer.profileSaves.single.phone, '9876543210');
      expect(h.lawyer.profileSaves.single.yearsExperience, '12');
      expect(find.text('✓ Profile saved.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('every section fits a 320-wide phone', (tester) async {
    final h = harnessWith([
      firRow(
        firNo: 'FIR-2026-000123',
        status: 'Court Proceedings',
        complainant: 'Venkatanarasimharajuvaripeta Subrahmanyam',
        sections: 'BNS 303, BNS 318(4), BNS 61(2), IT Act 66D',
        nextHearing: '2099-01-01',
      ),
    ]);
    const deadline = CaseDeadline(
      id: 1,
      firNo: 'FIR-2026-000123',
      deadlineType: 'Discharge Application',
      dueDate: '2000-01-01',
      note: 'Long note about what must be filed and where',
      completed: false,
    );
    h.lawyer
      ..upcoming = [deadline]
      ..deadlinesByFir['FIR-2026-000123'] = [deadline]
      ..hearingsByFir['FIR-2026-000123'] = const [
        CaseHearing(hearingDate: '2026-10-01', note: 'Arguments on bail'),
      ]
      ..allDraftList = const [
        CaseDraft(
          id: 1,
          firNo: 'FIR-2026-000123',
          kind: 'document',
          content: '| A | B |\n|---|---|\n| 1 | 2 |',
          createdAt: '2026-09-27T10:11:12.123456+00:00',
        ),
      ];
    await pumpLawyerApp(tester, harness: h, size: const Size(320, 2400));

    for (final section in ['My Cases', 'Legal Assistant', 'Drafts']) {
      await openLawyerSection(tester, section);
    }
    await openCase(tester, 'FIR-2026-000123');
    for (final tab in [
      'AI Summary',
      'Documents',
      'Hearings',
      'Deadlines',
      'Drafts',
    ]) {
      await openTab(tester, tab);
    }
    expect(tester.takeException(), isNull);
  });
}

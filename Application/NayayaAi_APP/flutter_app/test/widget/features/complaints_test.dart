import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_category.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_status.dart';
import 'package:nayaya_app/features/complaints/domain/entities/escalation_desk.dart';
import 'package:nayaya_app/features/complaints/presentation/widgets/complaint_keys.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';
import 'package:nayaya_app/features/fir/presentation/controllers/fir_form_controller.dart';
import 'package:nayaya_app/features/fir/presentation/widgets/fir_field_keys.dart';

import '../../helpers/complaints.dart';
import '../../helpers/fake_complaint_repository.dart';
import '../../helpers/fake_fir_repository.dart';
import '../../helpers/pump_complaints_app.dart';

void main() {
  late FakeComplaintRepository repository;

  setUp(() => repository = FakeComplaintRepository());

  group('the inbox', () {
    testWidgets('shows every complaint the station has', (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-ONE', fullName: 'Asha Menon'),
        aComplaint(trackingId: 'CMP-TWO', fullName: 'Vikram Rao'),
      ];

      await pumpComplaints(tester, repository: repository);

      expect(find.byKey(ComplaintKeys.tile('CMP-ONE')), findsOneWidget);
      expect(find.byKey(ComplaintKeys.tile('CMP-TWO')), findsOneWidget);
      expect(find.text('2 complaints'), findsOneWidget);
    });

    testWidgets('an empty table reads as an empty inbox, not a fault',
        (tester) async {
      await pumpComplaints(tester, repository: repository);

      expect(find.text('No complaints have been filed'), findsOneWidget);
    });

    testWidgets('shows the failure the server gave', (tester) async {
      repository.allFailure = const ServerFailure(
        message: 'The server ran into a problem. Please try again later.',
      );

      await pumpComplaints(tester, repository: repository);

      expect(find.text('Complaints could not be loaded'), findsOneWidget);
      expect(
        find.text('The server ran into a problem. Please try again later.'),
        findsOneWidget,
      );
    });

    testWidgets('the search box narrows the list to what matches',
        (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-SCOOTER',
          incidentDescription: 'Scooter taken from the market gate.',
        ),
        aComplaint(
          trackingId: 'CMP-NOISE',
          incidentDescription: 'Loud music from the hall next door.',
        ),
      ];

      await pumpComplaints(tester, repository: repository);
      await searchComplaints(tester, 'scooter');

      expect(find.byKey(ComplaintKeys.tile('CMP-SCOOTER')), findsOneWidget);
      expect(find.byKey(ComplaintKeys.tile('CMP-NOISE')), findsNothing);
    });

    // "Active" is the chip an officer lives on: everything still theirs to do.
    testWidgets('the Active chip hides what the desk has finished with',
        (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-OPEN', status: ComplaintStatus.pending),
        aComplaint(trackingId: 'CMP-DONE', status: ComplaintStatus.closed),
      ];

      await pumpComplaints(tester, repository: repository);
      await selectStage(tester, 'open');

      expect(find.byKey(ComplaintKeys.tile('CMP-OPEN')), findsOneWidget);
      expect(find.byKey(ComplaintKeys.tile('CMP-DONE')), findsNothing);
    });

    // The distinction the empty state has to get right: an inbox with nothing
    // in it and an inbox with a filter on it need different sentences, because
    // only one of them has an action attached.
    testWidgets('says when a filter is what emptied the list', (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-DONE', status: ComplaintStatus.closed),
      ];

      await pumpComplaints(tester, repository: repository);
      await selectStage(tester, 'pending');

      expect(find.text('Nothing matches these filters'), findsOneWidget);
      expect(find.text('No complaints have been filed'), findsNothing);
    });

    testWidgets('a date filter cuts on the day the complaint arrived',
        (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-TODAY', createdAt: '2026-08-09 01:00:00'),
        aComplaint(
          trackingId: 'CMP-LASTWEEK',
          createdAt: '2026-08-01 01:00:00',
        ),
      ];

      await pumpComplaints(tester, repository: repository);
      await selectDatePreset(tester, 'today');

      expect(find.byKey(ComplaintKeys.tile('CMP-TODAY')), findsOneWidget);
      expect(find.byKey(ComplaintKeys.tile('CMP-LASTWEEK')), findsNothing);
    });

    // Triage is deciding which of forty rows to open, so the row has to carry
    // enough to decide with. A tracking ID identifies nothing to anybody.
    testWidgets('the row carries what the complaint is about', (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-ONE',
          incidentDescription: 'Scooter taken from the market gate.',
        ),
      ];

      await pumpComplaints(tester, repository: repository);

      expect(find.text('Scooter taken from the market gate.'), findsOneWidget);
    });

    testWidgets('clearing the filters takes the search box with it',
        (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-OPEN', status: ComplaintStatus.pending),
        aComplaint(trackingId: 'CMP-DONE', status: ComplaintStatus.closed),
      ];

      await pumpComplaints(tester, repository: repository);
      await selectStage(tester, 'closed');
      await searchComplaints(tester, 'nothing matches this');

      await tester.tap(find.byKey(ComplaintKeys.filterButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ComplaintKeys.clearFilters));
      await tester.pumpAndSettle();

      // A "clear" that left the query behind would show another empty list,
      // immediately after the officer asked for the inbox back.
      expect(find.text('2 complaints'), findsOneWidget);
    });

    // The filter is the officer's place in the inbox. Losing it on every
    // navigation turns a triage session into re-filtering.
    testWidgets('the filter survives opening a complaint and coming back',
        (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-OPEN', status: ComplaintStatus.pending),
        aComplaint(trackingId: 'CMP-DONE', status: ComplaintStatus.closed),
      ];

      await pumpComplaints(tester, repository: repository);
      await selectStage(tester, 'closed');

      await openComplaint(tester, 'CMP-DONE');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // With the denominator, so a filtered inbox never reads as a station with
      // one complaint in it.
      expect(find.text('1 of 2 complaints'), findsOneWidget);
      expect(find.byKey(ComplaintKeys.tile('CMP-OPEN')), findsNothing);
    });

    testWidgets('opening a row shows that complaint', (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-ONE', fullName: 'Asha Menon'),
        aComplaint(trackingId: 'CMP-TWO', fullName: 'Vikram Rao'),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-TWO');

      expect(find.byKey(ComplaintKeys.detail), findsOneWidget);
      expect(find.text('Vikram Rao'), findsOneWidget);
    });
  });

  // The website's console carries the same four counts above its complaints
  // panel, and a pending count on its sidebar. Neither was in the app.
  group('the stat row', () {
    void seedMixed() {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-P1', status: ComplaintStatus.pending),
        aComplaint(trackingId: 'CMP-P2', status: ComplaintStatus.pending),
        aComplaint(trackingId: 'CMP-R1', status: ComplaintStatus.underReview),
        aComplaint(trackingId: 'CMP-F1', status: ComplaintStatus.firFiled),
        aComplaint(trackingId: 'CMP-C1', status: ComplaintStatus.closed),
      ];
    }

    testWidgets('counts the whole table by status', (tester) async {
      seedMixed();
      await pumpComplaints(tester, repository: repository);

      final stats = find.byKey(ComplaintKeys.stats);
      expect(stats, findsOneWidget);
      expect(
        find.descendant(of: stats, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stats, matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('a tile is a filter', (tester) async {
      seedMixed();
      await pumpComplaints(tester, repository: repository);

      await tester.tap(find.byKey(ComplaintKeys.stat('pending')));
      await tester.pumpAndSettle();

      expect(find.byKey(ComplaintKeys.tile('CMP-P1')), findsOneWidget);
      expect(find.byKey(ComplaintKeys.tile('CMP-C1')), findsNothing);
    });

    // The count under the list already moves with the filter. A header that
    // moved too would be the same number said twice.
    testWidgets('the counts do not move when a filter narrows the list', (
      tester,
    ) async {
      seedMixed();
      await pumpComplaints(tester, repository: repository);

      await tester.tap(find.byKey(ComplaintKeys.stat('pending')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(ComplaintKeys.stats),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the selected tile clears back to all', (tester) async {
      seedMixed();
      await pumpComplaints(tester, repository: repository);

      await tester.tap(find.byKey(ComplaintKeys.stat('pending')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ComplaintKeys.stat('pending')));
      await tester.pumpAndSettle();

      expect(find.byKey(ComplaintKeys.tile('CMP-C1')), findsOneWidget);
    });
  });

  group('grouping by kind of offence', () {
    void seedCategories() {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-THEFT',
          category: ComplaintCategory.theft,
        ),
        aComplaint(
          trackingId: 'CMP-MURDER',
          category: ComplaintCategory.murder,
        ),
        aComplaint(
          trackingId: 'CMP-NONE',
          category: null,
          categoryRaw: '',
        ),
      ];
    }

    testWidgets('the inbox is one flat list until it is toggled', (
      tester,
    ) async {
      seedCategories();
      await pumpComplaints(tester, repository: repository);

      expect(find.text('THEFT / ROBBERY · 1'), findsNothing);
    });

    testWidgets('grouping heads each kind with a count', (tester) async {
      seedCategories();
      await pumpComplaints(tester, repository: repository);

      await tester.tap(find.byKey(ComplaintKeys.viewToggle));
      await tester.pumpAndSettle();

      expect(find.text('MURDER / HOMICIDE · 1'), findsOneWidget);
      expect(find.text('THEFT / ROBBERY · 1'), findsOneWidget);
      // The three unclassifiable buckets and everything unclassified, collapsed
      // exactly as the website's board collapses them.
      expect(find.text('NEEDS A READ · 1'), findsOneWidget);
      // Every row is still there.
      expect(find.byKey(ComplaintKeys.tile('CMP-NONE')), findsOneWidget);
    });

    // A desktop board draws all eight columns; an empty heading on a phone is
    // something to scroll past.
    testWidgets('a kind with nothing in it gets no heading', (tester) async {
      seedCategories();
      await pumpComplaints(tester, repository: repository);

      await tester.tap(find.byKey(ComplaintKeys.viewToggle));
      await tester.pumpAndSettle();

      expect(find.textContaining('SEXUAL OFFENCE'), findsNothing);
    });

    testWidgets('toggling back returns the flat list', (tester) async {
      seedCategories();
      await pumpComplaints(tester, repository: repository);

      await tester.tap(find.byKey(ComplaintKeys.viewToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ComplaintKeys.viewToggle));
      await tester.pumpAndSettle();

      expect(find.text('THEFT / ROBBERY · 1'), findsNothing);
      expect(find.byKey(ComplaintKeys.tile('CMP-THEFT')), findsOneWidget);
    });
  });

  group('the detail screen', () {
    // The whole argument for resolving a complaint out of the list rather than
    // from `GET /api/complaint/<id>`: that handler does not select `phone`, and
    // ringing the complainant is the first thing an officer does.
    testWidgets('shows the complainant\'s phone number', (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-ONE', phone: '9876543210'),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      expect(find.text('9876543210'), findsOneWidget);
    });

    testWidgets('an untouched complaint says its trail is empty',
        (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      expect(
        find.text('Nothing has been recorded against this complaint yet.'),
        findsOneWidget,
      );
    });

    // One appended entry per action, so three decisions taken a week apart do
    // not run together into one paragraph.
    testWidgets('each entry in the trail is its own line', (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-ONE',
          officerNotes: '[8 Aug 2026, 10:00 UTC · Insp. N. Rao] Took a look.\n'
              '[9 Aug 2026, 04:00 UTC · Insp. N. Rao] Statement recorded.',
        ),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      expect(find.textContaining('Took a look.'), findsOneWidget);
      expect(find.textContaining('Statement recorded.'), findsOneWidget);
    });

    // A 404 here is an answer, not a fault. Saying "something went wrong" would
    // send an officer looking for a problem with the app rather than at the ID.
    testWidgets('a tracking ID that names nothing says so plainly',
        (tester) async {
      await pumpComplaints(
        tester,
        repository: repository,
        initialLocation: '/complaints/CMP-NOSUCH',
      );

      expect(find.text('No complaint with that tracking ID'), findsOneWidget);
      expect(
        find.text('Complaint not found. Check your tracking ID.'),
        findsOneWidget,
      );
    });
  });

  group('responding', () {
    testWidgets('writes a signed note and moves the complaint on',
        (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.respondAction));
      await tester.pumpAndSettle();

      await tester.enterText(
        complaintInput(ComplaintKeys.respondNote),
        'Rang the complainant and recorded a statement.',
      );
      await tester.tap(
        find.byKey(
          ComplaintKeys.respondStatus(ComplaintStatus.underReview.name),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ComplaintKeys.respondSubmit));
      await tester.pumpAndSettle();

      final write = repository.updates.single;
      expect(write.status, ComplaintStatus.underReview);
      expect(write.officerNotes, contains('Rang the complainant'));
      expect(write.officerNotes, contains(testOfficer));
      // Stamped from the pinned clock, not from the wall clock.
      expect(write.officerNotes, contains('9 Aug 2026, 06:30 UTC'));
    });

    // The failure this whole feature is arranged around: the PATCH overwrites
    // all three columns, so a response that did not carry the existing notes
    // would delete them.
    testWidgets('keeps the trail and the FIR number it was not asked to change',
        (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-ONE',
          status: ComplaintStatus.firFiled,
          firNo: 'FIR/2026/114',
          officerNotes: '[8 Aug 2026, 10:00 UTC · Insp. N. Rao] Took a look.',
        ),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.respondAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        complaintInput(ComplaintKeys.respondNote),
        'Charge sheet filed.',
      );
      await tester.tap(find.byKey(ComplaintKeys.respondSubmit));
      await tester.pumpAndSettle();

      final write = repository.updates.single;
      expect(write.officerNotes, contains('Took a look.'));
      expect(write.officerNotes, contains('Charge sheet filed.'));
      expect(write.firNo, 'FIR/2026/114');
    });

    // An empty write still stamps `updated_at`, which is the signal the inbox
    // uses to show a complaint has been dealt with.
    testWidgets('refuses a save that would change nothing', (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.respondAction));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ComplaintKeys.respondSubmit));
      await tester.pumpAndSettle();

      expect(repository.updates, isEmpty);
      expect(
        find.text('Write something, or move the complaint on.'),
        findsOneWidget,
      );
    });

    // "FIR filed" with no number records that something happened and destroys
    // the only pointer to what.
    testWidgets('will not mark an FIR filed without its number',
        (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.respondAction));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ComplaintKeys.respondStatus(ComplaintStatus.firFiled.name)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ComplaintKeys.respondSubmit));
      await tester.pumpAndSettle();

      expect(repository.updates, isEmpty);
      expect(
        find.text('Enter the FIR number, or choose another status.'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the sheet and the typing when the server refuses',
        (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];
      repository.updateFailure = const ValidationFailure('Invalid status');

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.respondAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        complaintInput(ComplaintKeys.respondNote),
        'Rang the complainant.',
      );
      await tester.tap(find.byKey(ComplaintKeys.respondSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(ComplaintKeys.respondSheet), findsOneWidget);
      expect(find.text('Invalid status'), findsOneWidget);
      expect(find.text('Rang the complainant.'), findsOneWidget);
    });
  });

  group('escalating', () {
    testWidgets('records where it is going and why, under review',
        (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.escalateAction));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ComplaintKeys.escalateDesk(EscalationDesk.cyber.name)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        complaintInput(ComplaintKeys.escalateReason),
        'The money left through a payments app.',
      );
      await tester.tap(find.byKey(ComplaintKeys.escalateSubmit));
      await tester.pumpAndSettle();

      final write = repository.updates.single;
      // Under Review because the server has no "escalated" status to move to.
      expect(write.status, ComplaintStatus.underReview);
      // The wording is fixed on purpose, so the inbox can be searched for it.
      expect(
        write.officerNotes,
        contains('Escalated to ${EscalationDesk.cyber.label}.'),
      );
      expect(
        write.officerNotes,
        contains('The money left through a payments app.'),
      );
    });

    testWidgets('an escalation without a reason is refused', (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.escalateAction));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ComplaintKeys.escalateDesk(EscalationDesk.sho.name)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ComplaintKeys.escalateSubmit));
      await tester.pumpAndSettle();

      expect(repository.updates, isEmpty);
      expect(find.text('An escalation needs a reason.'), findsOneWidget);
    });

    // Nothing is pre-selected, so a hurried tap on Escalate cannot send a
    // complaint to whichever desk happened to be first in the list.
    testWidgets('an escalation with no desk chosen is refused', (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.escalateAction));
      await tester.pumpAndSettle();
      await tester.enterText(
        complaintInput(ComplaintKeys.escalateReason),
        'Complainant says the accused is a serving officer.',
      );
      await tester.tap(find.byKey(ComplaintKeys.escalateSubmit));
      await tester.pumpAndSettle();

      expect(repository.updates, isEmpty);
      expect(find.text('Choose where this is going.'), findsOneWidget);
    });

    // The most important sentence on the sheet. An officer who believes they
    // have forwarded a complaint to the Superintendent, and has not, stops
    // thinking about it — which leaves the complaint worse off than if it had
    // never been escalated.
    testWidgets('says plainly that nothing is actually sent', (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.escalateAction));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing is sent'), findsOneWidget);
    });
  });

  group('registering an FIR', () {
    testWidgets('carries the complaint into the FIR form', (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-ONE',
          fullName: 'Asha Menon',
          incidentDescription: 'Scooter taken from the market gate.',
        ),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      await tester.tap(find.byKey(ComplaintKeys.convertAction));
      await tester.pumpAndSettle();

      // The wizard opens on step 1, so the seeded entries are two and three
      // steps in. Asserted on the draft rather than by walking there: what this
      // test is about is what the conversion carried over, not the form's
      // navigation, which fir_form_screen_test owns.
      final draft =
          complaintsContainer(tester).read(firFormControllerProvider).draft;
      expect(draft.complainantName, 'Asha Menon');
      expect(draft.statement, 'Scooter taken from the market gate.');

      // And it did open the form rather than only mutating state.
      expect(
        find.byKey(FirFieldKeys.step(FirFormStep.registration)),
        findsOneWidget,
      );
      // Nothing has been written to the complaint yet: there is no FIR number to
      // record until the server has accepted one.
      expect(repository.updates, isEmpty);
    });

    // `incident_date` is free text a citizen typed. The FIR's occurrence date is
    // a `yyyy-MM-dd` column that both the year and the day of the week are
    // derived from, so prose copied into it would put a malformed date into a
    // statutory record. Asserted on the draft rather than on the form: the
    // occurrence date is a picker, and an empty one renders as its placeholder,
    // which proves nothing about what would be submitted.
    testWidgets('carries the incident date when it is a date', (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-ONE', incidentDate: '2026-08-07'),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');
      await tester.tap(find.byKey(ComplaintKeys.convertAction));
      await tester.pumpAndSettle();

      expect(
        complaintsContainer(tester)
            .read(firFormControllerProvider)
            .draft
            .occurrenceDate,
        '2026-08-07',
      );
    });

    testWidgets('leaves it blank when the citizen wrote prose', (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-ONE', incidentDate: 'last Tuesday'),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');
      await tester.tap(find.byKey(ComplaintKeys.convertAction));
      await tester.pumpAndSettle();

      expect(
        complaintsContainer(tester)
            .read(firFormControllerProvider)
            .draft
            .occurrenceDate,
        isEmpty,
      );
    });

    // The draft outlives the screen, so it may hold an unrelated FIR somebody is
    // part-way through. Seeding replaces it, and this is the only moment anyone
    // can ask.
    testWidgets('asks before discarding an FIR already being written',
        (tester) async {
      repository.complaints = [
        aComplaint(trackingId: 'CMP-ONE', fullName: 'Asha Menon'),
      ];

      await pumpComplaints(tester, repository: repository);

      // An unrelated FIR, part-written and left on the form. Put there through
      // the controller rather than by driving the form: what this test is about
      // is the question the complaint screen asks, not how the entries got in.
      final container = complaintsContainer(tester);
      container.read(firFormControllerProvider.notifier);
      await tester.pumpAndSettle();
      container
          .read(firFormControllerProvider.notifier)
          .edit((draft) => draft.copyWith(firNo: 'FIR/2026/900'));
      // Past the autosave debounce, so no timer is left pending at teardown.
      await tester.pump(const Duration(seconds: 2));

      await openComplaint(tester, 'CMP-ONE');
      await tester.tap(find.byKey(ComplaintKeys.convertAction));
      await tester.pumpAndSettle();

      expect(find.text('Replace the FIR you started?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      // Still on the complaint: nothing was thrown away.
      expect(find.byKey(ComplaintKeys.detail), findsOneWidget);
    });

    // The point of the whole conversion flow, and the part no single screen can
    // do on its own: the link is written when `/generate_fir` answers, which may
    // be long after the complaint screen is gone.
    testWidgets('links the complaint once the server accepts the FIR',
        (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-ONE',
          officerNotes: '[8 Aug 2026, 10:00 UTC · Insp. N. Rao] Took a look.',
        ),
      ];
      final firRepository = FakeFirRepository();

      await pumpComplaints(
        tester,
        repository: repository,
        firRepository: firRepository,
      );
      await openComplaint(tester, 'CMP-ONE');
      await tester.tap(find.byKey(ComplaintKeys.convertAction));
      await tester.pumpAndSettle();

      // The three entries the officer still has to supply — the station's, not
      // the citizen's. Filled through the controller rather than by driving the
      // form: how the FIR form collects them is the FIR suite's business.
      final container = complaintsContainer(tester);
      container.read(firFormControllerProvider.notifier).edit(
            (draft) => draft.copyWith(
              firNo: 'FIR/2026/114',
              district: 'Maharashtra',
              policeStation: 'North Delhi PS',
              sections: const [ActSection(act: 'IPC', section: '379')],
            ),
          );
      await tester.pumpAndSettle();

      await container.read(firFormControllerProvider.notifier).submit();
      await tester.pumpAndSettle();

      final write = repository.updates.single;
      expect(write.base.trackingId, 'CMP-ONE');
      expect(write.status, ComplaintStatus.firFiled);
      expect(write.firNo, 'FIR/2026/114');
      expect(write.officerNotes, contains('Registered as FIR FIR/2026/114.'));
      // And the trail it already had is still there.
      expect(write.officerNotes, contains('Took a look.'));
    });

    // Nothing should be linked to a complaint the officer never converted.
    testWidgets('an FIR filed on its own links nothing', (tester) async {
      repository.complaints = [aComplaint(trackingId: 'CMP-ONE')];
      final firRepository = FakeFirRepository();

      await pumpComplaints(
        tester,
        repository: repository,
        firRepository: firRepository,
      );

      final container = complaintsContainer(tester);
      container.read(firFormControllerProvider.notifier).edit(
            (draft) => draft.copyWith(
              firNo: 'FIR/2026/200',
              district: 'Maharashtra',
              policeStation: 'North Delhi PS',
              complainantName: 'Someone Else',
              statement: 'Unrelated offence.',
              sections: const [ActSection(act: 'IPC', section: '379')],
            ),
          );
      await tester.pumpAndSettle();

      await container.read(firFormControllerProvider.notifier).submit();
      await tester.pumpAndSettle();

      expect(repository.updates, isEmpty);
    });

    testWidgets('a complaint that already has an FIR offers to open it',
        (tester) async {
      repository.complaints = [
        aComplaint(
          trackingId: 'CMP-ONE',
          status: ComplaintStatus.firFiled,
          firNo: 'FIR/2026/114',
        ),
      ];

      await pumpComplaints(tester, repository: repository);
      await openComplaint(tester, 'CMP-ONE');

      // Filing a second FIR for one offence would be a duplicate record.
      expect(find.byKey(ComplaintKeys.convertAction), findsNothing);

      await tester.tap(find.byKey(ComplaintKeys.openFirAction));
      await tester.pumpAndSettle();

      expect(find.text('FIR RECORD FIR/2026/114'), findsOneWidget);
    });
  });
}

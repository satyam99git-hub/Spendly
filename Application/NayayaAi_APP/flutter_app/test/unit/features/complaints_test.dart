import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/complaints/data/datasources/complaint_remote_data_source.dart';
import 'package:nayaya_app/features/complaints/data/models/complaint_models.dart';
import 'package:nayaya_app/features/complaints/data/repositories/complaint_repository_impl.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_category.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_filter.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_note.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_status.dart';

import '../../helpers/complaints.dart';

/// The complaints feature below the widgets: the server's contract, the rules
/// the inbox is filtered by, and the two things about the PATCH that are easy to
/// get wrong and impossible to notice in the field.
void main() {
  /// Fixed, because every relative window is a function of the clock.
  final now = DateTime.utc(2026, 8, 9, 6, 30);

  group('ComplaintStatus', () {
    // These four strings are the server's, not the app's:
    // `valid_statuses = ['Pending', 'Under Review', 'FIR Filed', 'Closed']`.
    // Anything else is HTTP 400, so a "tidied" value here is a feature that
    // cannot save.
    test('wire values are exactly what the handler accepts', () {
      expect(
        ComplaintStatus.values.map((s) => s.wireValue),
        ['Pending', 'Under Review', 'FIR Filed', 'Closed'],
      );
    });

    test('reads the column, whatever case it is stored in', () {
      expect(
        ComplaintStatus.fromWire('Under Review'),
        ComplaintStatus.underReview,
      );
      expect(
        ComplaintStatus.fromWire('  fir filed '),
        ComplaintStatus.firFiled,
      );
    });

    // Not coerced to Pending: the row would then be reported as untouched when
    // somebody has in fact been working on it.
    test('an unrecognised value is null, not a guess', () {
      expect(ComplaintStatus.fromWire('Escalated'), isNull);
      expect(ComplaintStatus.fromWire(''), isNull);
      expect(ComplaintStatus.fromWire(null), isNull);
    });

    test('only the first two are still the desk’s to act on', () {
      expect(ComplaintStatus.pending.isOpen, isTrue);
      expect(ComplaintStatus.underReview.isOpen, isTrue);
      expect(ComplaintStatus.firFiled.isOpen, isFalse);
      expect(ComplaintStatus.closed.isOpen, isFalse);
    });
  });

  group('Complaint', () {
    test('created_at is read as UTC, not as the handset’s local time', () {
      final complaint = aComplaint(createdAt: '2026-08-09 02:31:00');

      expect(complaint.receivedAt, DateTime.utc(2026, 8, 9, 2, 31));
      expect(complaint.receivedAtDisplay, '9 Aug 2026, 02:31 UTC');
      expect(complaint.receivedOnDisplay, '9 Aug 2026');
    });

    // The insert writes both columns from one CURRENT_TIMESTAMP, so equal
    // timestamps are what an untouched complaint looks like. Printing "updated"
    // for that would tell an officer the desk had acted when it had not.
    test('is not "updated" until something has actually changed it', () {
      expect(aComplaint().wasUpdated, isFalse);
      expect(
        aComplaint(updatedAt: '2026-08-09 09:00:00').wasUpdated,
        isTrue,
      );
    });

    test('shows an unreadable status rather than swallowing it', () {
      final complaint = aComplaint(statusRaw: 'Escalated');

      expect(complaint.status, isNull);
      expect(complaint.statusLabel, 'Escalated');
      // Kept in the inbox: nobody can prove it has been dealt with, and hiding
      // it is how a complaint gets lost.
      expect(complaint.isOpen, isTrue);
    });

    test('an empty status column says so instead of printing nothing', () {
      expect(aComplaint(statusRaw: '').statusLabel, 'No status');
    });

    // The description is searched here and deliberately not in FIR history —
    // an officer working the inbox is looking for "the one about the scooter".
    test('search covers the narrative, the ID and the FIR number', () {
      final complaint = aComplaint(
        incidentDescription: 'Scooter taken from the market gate.',
        firNo: 'FIR/2026/114',
      );

      expect(complaint.matches('scooter'), isTrue);
      expect(complaint.matches('cmp-1a2b'), isTrue);
      expect(complaint.matches('fir/2026'), isTrue);
      expect(complaint.matches('bicycle'), isFalse);
      expect(complaint.matches(''), isTrue);
    });
  });

  // The category the server derives from the narrative, and the cognizable flag
  // that comes with it. Both are shown on the website's board and were missing
  // from this app entirely, so an officer moving between the two saw a triage
  // decision on one screen and not the other.
  group('ComplaintCategory', () {
    // These strings are `complaint_categorizer.py`'s, and the website's board
    // groups its columns by comparing them literally. A "tidied" value here
    // would put a complaint in a column neither client agrees on.
    test('wire values are exactly what the categoriser writes', () {
      expect(
        ComplaintCategory.values.map((c) => c.wireValue),
        containsAll([
          'Murder / Homicide',
          'Sexual Offence',
          'Kidnapping / Missing Person',
          'Assault / Violence',
          'Theft / Robbery',
          'Cybercrime / Fraud',
          'Financial Fraud / Cheating',
          'Other (Non-Cognizable)',
          'Other / Needs Review',
          'Other / Unclassified',
        ]),
      );
    });

    test(
        'the seven crime categories are cognizable and the three Others are '
        'not', () {
      for (final category in ComplaintCategory.values) {
        expect(
          category.isCognizable,
          !category.isUnclassified,
          reason: '${category.wireValue} disagrees with the categoriser',
        );
      }
    });

    // A row from before the categoriser existed, or one whose category the app
    // has not been taught. Reporting either as "Needs review" would claim a
    // triage decision nobody made.
    test('an unknown or empty column parses to null, not to a bucket', () {
      expect(ComplaintCategory.fromWire(null), isNull);
      expect(ComplaintCategory.fromWire(''), isNull);
      expect(ComplaintCategory.fromWire('Traffic Offence'), isNull);
    });

    test('a complaint with no category says so rather than guessing', () {
      final complaint = aComplaint(category: null, categoryRaw: '');

      expect(complaint.hasCategory, isFalse);
      expect(complaint.categoryLabel, 'Not categorised');
      expect(complaint.isCognizable, isFalse);
    });

    test('an unrecognised category is shown as written', () {
      final complaint = aComplaint(categoryRaw: 'Traffic Offence');

      expect(complaint.hasCategory, isTrue);
      expect(complaint.category, isNull);
      expect(complaint.categoryLabel, 'Traffic Offence');
    });

    // The row's own column wins. Both come from the same keyword table, but
    // only the row was written by the version of it that actually ran.
    test('the row\'s is_cognizable outranks the category default', () {
      expect(
        aComplaint(category: ComplaintCategory.theft, isCognizable: false)
            .isCognizable,
        isFalse,
      );
      expect(
        aComplaint(category: ComplaintCategory.needsReview, isCognizable: true)
            .isCognizable,
        isTrue,
      );
    });

    test('with no column of its own it falls back to the category', () {
      expect(
        aComplaint(category: ComplaintCategory.murder).isCognizable,
        isTrue,
      );
      expect(
        aComplaint(category: ComplaintCategory.nonCognizable).isCognizable,
        isFalse,
      );
    });

    // Searching the category is what makes "theft" find the thefts even when
    // the complainant wrote "took my phone".
    test('the category is searched along with the narrative', () {
      expect(
        aComplaint(category: ComplaintCategory.theft).matches('robbery'),
        isTrue,
      );
    });
  });

  group('ComplaintCategoryFilter', () {
    final theft = aComplaint(
      trackingId: 'CMP-THEFT',
      category: ComplaintCategory.theft,
    );
    final murder = aComplaint(
      trackingId: 'CMP-MURDER',
      category: ComplaintCategory.murder,
    );
    final needsReview = aComplaint(
      trackingId: 'CMP-REVIEW',
      category: ComplaintCategory.needsReview,
    );
    final uncategorised = aComplaint(
      trackingId: 'CMP-NONE',
      category: null,
      categoryRaw: '',
    );
    final unknownWord = aComplaint(
      trackingId: 'CMP-ODD',
      categoryRaw: 'Traffic Offence',
    );
    final all = [theft, murder, needsReview, uncategorised, unknownWord];

    List<String> idsFor(ComplaintCategoryFilter choice) =>
        all.where(choice.accepts).map((c) => c.trackingId).toList();

    test('all admits everything', () {
      expect(idsFor(ComplaintCategoryFilter.all).length, all.length);
    });

    test('cognizable is the officer\'s "can I file an FIR on this"', () {
      expect(
        idsFor(ComplaintCategoryFilter.cognizable),
        ['CMP-THEFT', 'CMP-MURDER'],
      );
    });

    test('a single category selects only its own', () {
      expect(idsFor(ComplaintCategoryFilter.theft), ['CMP-THEFT']);
    });

    // The three Other buckets, plus the rows nobody classified at all. The last
    // two are the point: a complaint no categoriser has read is exactly the one
    // that needs an officer, and the only filter that can surface it is this.
    test('other gathers the unclassifiable and the unclassified', () {
      expect(
        idsFor(ComplaintCategoryFilter.other),
        ['CMP-REVIEW', 'CMP-NONE', 'CMP-ODD'],
      );
    });

    test('the filter counts as one of the active filters', () {
      const filter = ComplaintFilter(
        category: ComplaintCategoryFilter.cognizable,
      );

      expect(filter.isActive, isTrue);
      expect(filter.activeCount, 1);
    });

    test('it narrows the inbox alongside the other three', () {
      const filter = ComplaintFilter(
        category: ComplaintCategoryFilter.cognizable,
      );

      expect(
        filter.apply(all, now: now).map((c) => c.trackingId),
        ['CMP-THEFT', 'CMP-MURDER'],
      );
    });
  });

  group('ComplaintStage', () {
    final pending = aComplaint(status: ComplaintStatus.pending);
    final review = aComplaint(status: ComplaintStatus.underReview);
    final filed = aComplaint(status: ComplaintStatus.firFiled);
    final closed = aComplaint(status: ComplaintStatus.closed);
    final unknown = aComplaint(statusRaw: 'Escalated');

    test('"Active" is the two open statuses plus anything unreadable', () {
      expect(ComplaintStage.open.accepts(pending), isTrue);
      expect(ComplaintStage.open.accepts(review), isTrue);
      expect(ComplaintStage.open.accepts(unknown), isTrue);
      expect(ComplaintStage.open.accepts(filed), isFalse);
      expect(ComplaintStage.open.accepts(closed), isFalse);
    });

    test('"All" hides nothing at all', () {
      for (final complaint in [pending, review, filed, closed, unknown]) {
        expect(ComplaintStage.all.accepts(complaint), isTrue);
      }
    });

    test('a named stage is exactly its own status', () {
      expect(ComplaintStage.pending.accepts(pending), isTrue);
      expect(ComplaintStage.pending.accepts(review), isFalse);
      expect(ComplaintStage.firFiled.accepts(filed), isTrue);
      expect(ComplaintStage.closed.accepts(closed), isTrue);
    });
  });

  group('ComplaintFilter dates', () {
    // One complaint per day, counting back from the pinned clock.
    Complaint on(String timestamp) =>
        aComplaint(trackingId: 'CMP-$timestamp', createdAt: timestamp);

    final today = on('2026-08-09 01:00:00');
    final laterToday = on('2026-08-09 23:59:59');
    final yesterday = on('2026-08-08 12:00:00');
    final sixDaysAgo = on('2026-08-03 12:00:00');
    final tenDaysAgo = on('2026-07-30 12:00:00');
    final all = [today, laterToday, yesterday, sixDaysAgo, tenDaysAgo];

    List<Complaint> filtered(ComplaintDatePreset preset) =>
        ComplaintFilter(datePreset: preset).apply(all, now: now);

    test('Any time is the whole inbox', () {
      expect(filtered(ComplaintDatePreset.anyTime), all);
    });

    // The whole UTC day, not "the last 24 hours": a complaint filed at 23:59 on
    // the 9th is still today's, even though the clock says 06:30.
    test('Today is the whole UTC day the clock is in', () {
      expect(
        filtered(ComplaintDatePreset.today),
        [today, laterToday],
      );
    });

    test('Yesterday is the day before, and only that day', () {
      expect(filtered(ComplaintDatePreset.yesterday), [yesterday]);
    });

    // Inclusive of today: seven dates on a calendar, which is what an officer
    // counting back means.
    test('Last 7 days is today and the six before it', () {
      expect(
        filtered(ComplaintDatePreset.last7Days),
        [today, laterToday, yesterday, sixDaysAgo],
      );
    });

    test('Last 30 days reaches back far enough to include all of these', () {
      expect(filtered(ComplaintDatePreset.last30Days), all);
    });

    test('a custom range includes both of the days chosen', () {
      final range = ComplaintFilter(
        datePreset: ComplaintDatePreset.custom,
        customFrom: DateTime.utc(2026, 8, 3),
        customTo: DateTime.utc(2026, 8, 8),
      );

      expect(range.apply(all, now: now), [yesterday, sixDaysAgo]);
    });

    // Better than hiding the whole inbox behind a choice the officer has not
    // finished making.
    test('a half-chosen custom range narrows nothing', () {
      final half = ComplaintFilter(
        datePreset: ComplaintDatePreset.custom,
        customFrom: DateTime.utc(2026, 8, 3),
      );

      expect(half.apply(all, now: now), all);
    });

    // Showing it under every range would put the same row in "Today" and in
    // "Yesterday" and make both counts lie. It is still visible under Any time.
    test('a complaint with no readable timestamp is hidden by a date filter',
        () {
      final undated = aComplaint(trackingId: 'CMP-NODATE', createdAt: '');
      final list = [today, undated];

      expect(
        const ComplaintFilter(datePreset: ComplaintDatePreset.today)
            .apply(list, now: now),
        [today],
      );
      expect(const ComplaintFilter().apply(list, now: now), list);
    });
  });

  group('ComplaintFilter', () {
    test('an empty filter is not "on", and hides nothing', () {
      const filter = ComplaintFilter();

      expect(filter.isActive, isFalse);
      expect(filter.activeCount, 0);
    });

    test('counts each kind of narrowing once, search included', () {
      const filter = ComplaintFilter(
        query: 'scooter',
        stage: ComplaintStage.open,
        datePreset: ComplaintDatePreset.today,
      );

      expect(filter.isActive, isTrue);
      expect(filter.activeCount, 3);
    });

    test('whitespace in the search box is not a filter', () {
      expect(const ComplaintFilter(query: '   ').isActive, isFalse);
    });

    test('the three rules compose, and the given order survives', () {
      final wanted = aComplaint(
        trackingId: 'CMP-WANTED',
        status: ComplaintStatus.pending,
        incidentDescription: 'Scooter taken from the market gate.',
        createdAt: '2026-08-09 01:00:00',
      );
      final wrongStatus = aComplaint(
        trackingId: 'CMP-CLOSED',
        status: ComplaintStatus.closed,
        incidentDescription: 'Scooter taken from the market gate.',
        createdAt: '2026-08-09 01:00:00',
      );
      final wrongDay = aComplaint(
        trackingId: 'CMP-OLD',
        status: ComplaintStatus.pending,
        incidentDescription: 'Scooter taken from the market gate.',
        createdAt: '2026-07-01 01:00:00',
      );
      final wrongWords = aComplaint(
        trackingId: 'CMP-OTHER',
        status: ComplaintStatus.pending,
        incidentDescription: 'Noise from the hall next door.',
        createdAt: '2026-08-09 01:00:00',
      );

      const filter = ComplaintFilter(
        query: 'SCOOTER',
        stage: ComplaintStage.open,
        datePreset: ComplaintDatePreset.today,
      );

      expect(
        filter.apply([wrongStatus, wanted, wrongDay, wrongWords], now: now),
        [wanted],
      );
    });
  });

  group('ComplaintNote', () {
    final at = DateTime.utc(2026, 8, 9, 2, 31);

    test('stamps in UTC, the same way every other time is shown', () {
      expect(ComplaintNote.stamp(at), '9 Aug 2026, 02:31 UTC');
    });

    test('signs the entry with the officer', () {
      expect(
        ComplaintNote.append(
          '',
          body: 'Rang the complainant.',
          officer: 'SI K. Deshmukh',
          at: at,
        ),
        '[9 Aug 2026, 02:31 UTC · SI K. Deshmukh] Rang the complainant.',
      );
    });

    // The whole reason this file exists: the PATCH overwrites the column, so
    // anything that did not append would delete the last officer's reasoning.
    test('adds to the trail instead of replacing it', () {
      final first = ComplaintNote.append(
        '',
        body: 'Rang the complainant.',
        officer: 'SI K. Deshmukh',
        at: at,
      );
      final second = ComplaintNote.append(
        first,
        body: 'Escalated to Cyber Cell.',
        officer: 'Insp. N. Rao',
        at: at.add(const Duration(hours: 2)),
      );

      expect(ComplaintNote.lines(second), hasLength(2));
      expect(second.startsWith(first), isTrue);
      expect(second, contains('Escalated to Cyber Cell.'));
    });

    test('an empty body adds nothing at all', () {
      expect(
        ComplaintNote.append('existing', body: '   ', officer: 'X', at: at),
        'existing',
      );
    });

    test('an unsigned entry says so rather than borrowing the name above', () {
      expect(
        ComplaintNote.append('', body: 'Closed.', officer: '', at: at),
        contains(ComplaintNote.unknownOfficer),
      );
    });

    // Notes the website's console wrote have no stamps and no structure.
    test('free text written elsewhere reads as one entry', () {
      expect(ComplaintNote.lines('spoke to the complainant'), hasLength(1));
      expect(ComplaintNote.lines(''), isEmpty);
    });
  });

  group('the wire contract', () {
    test('reads the row the list endpoint sends', () {
      final complaint = ComplaintResponse.fromJson(aComplaintRow());

      expect(complaint.trackingId, 'CMP-1A2B3C4D');
      expect(complaint.fullName, 'R. Iyer');
      expect(complaint.phone, '9876543210');
      expect(complaint.status, ComplaintStatus.pending);
      expect(complaint.receivedAt, DateTime.utc(2026, 8, 9, 6, 30));
    });

    // `fir_no` and `officer_notes` are NULL on every complaint nobody has
    // touched, which is most of the table.
    test('a NULL column is empty, not a crash', () {
      final complaint = ComplaintResponse.fromJson(aComplaintRow());

      expect(complaint.firNo, '');
      expect(complaint.officerNotes, '');
      expect(complaint.hasFir, isFalse);
      expect(complaint.hasNotes, isFalse);
    });

    test('reads the category and the cognizable flag', () {
      final complaint = ComplaintResponse.fromJson(aComplaintRow());

      expect(complaint.category, ComplaintCategory.theft);
      expect(complaint.isCognizable, isTrue);
    });

    // SQLite has no boolean. The column is an INTEGER, `jsonify` sends the int,
    // and a row edited by hand in a SQLite browser can hold the string.
    test('is_cognizable is read as 0/1, as a bool and as text', () {
      bool? read(Object? value) =>
          ComplaintResponse.fromJson(aComplaintRow(isCognizable: value))
              .isCognizableRaw;

      expect(read(1), isTrue);
      expect(read(0), isFalse);
      expect(read(true), isTrue);
      expect(read('true'), isTrue);
      expect(read('0'), isFalse);
    });

    // Not the same fact as "the server said no". One is a triage decision and
    // the other is a row filed before there was a categoriser to make one.
    test('a missing is_cognizable stays null rather than becoming false', () {
      final row = aComplaintRow()..remove('is_cognizable');

      expect(ComplaintResponse.fromJson(row).isCognizableRaw, isNull);
    });

    test('a tracking ID is upper-cased on the way in', () {
      final complaint =
          ComplaintResponse.fromJson(aComplaintRow(trackingId: 'cmp-abc123'));

      expect(complaint.trackingId, 'CMP-ABC123');
    });

    // The single-complaint handler's SELECT has no `phone`, so the key is
    // genuinely absent rather than null.
    test('a missing column is empty too', () {
      final row = aComplaintRow()..remove('phone');

      expect(ComplaintResponse.fromJson(row).phone, '');
    });

    // Sending fewer than three keys is how closing a complaint silently deletes
    // the notes on it: the handler writes each column from `data.get(...)`.
    test('the PATCH body always carries all three columns', () {
      final body = const ComplaintUpdate(
        status: ComplaintStatus.closed,
        firNo: '',
        officerNotes: '',
      ).toJson();

      expect(body.keys, containsAll(['status', 'fir_no', 'officer_notes']));
      expect(body['status'], 'Closed');
    });
  });

  group('ComplaintRepositoryImpl', () {
    late _FakeServer server;
    late ComplaintRepositoryImpl repository;

    setUp(() {
      server = _FakeServer();
      repository = ComplaintRepositoryImpl(
        remote: ComplaintRemoteDataSource(server.dio),
      );
    });

    // The handler's ORDER BY is a string sort over a TEXT column. It holds for
    // the timestamps the default writes and stops holding for anything else, so
    // the app sorts on the parsed instant and does not depend on it.
    test('puts the inbox newest first whatever order the server sent',
        () async {
      server.rows = [
        aComplaintRow(trackingId: 'CMP-OLD'),
        aComplaintRow(trackingId: 'CMP-NEW'),
      ];
      server.rows[0]['created_at'] = '2026-08-01 06:30:00';
      server.rows[1]['created_at'] = '2026-08-09 06:30:00';

      final inbox = await repository.all();

      expect(inbox.map((c) => c.trackingId), ['CMP-NEW', 'CMP-OLD']);
    });

    test('a row with no readable timestamp sinks rather than floats', () async {
      server.rows = [
        aComplaintRow(trackingId: 'CMP-UNDATED'),
        aComplaintRow(trackingId: 'CMP-DATED'),
      ];
      server.rows[0]['created_at'] = null;

      final inbox = await repository.all();

      expect(inbox.map((c) => c.trackingId), ['CMP-DATED', 'CMP-UNDATED']);
    });

    // A row with no tracking ID cannot be opened, updated or converted — the ID
    // is what both write routes are keyed on — so it is dropped rather than
    // shown as a row that does nothing when tapped.
    test('a row with no tracking ID is skipped, not fatal', () async {
      server.rows = [
        aComplaintRow(trackingId: ''),
        aComplaintRow(trackingId: 'CMP-REAL'),
      ];

      expect((await repository.all()).map((c) => c.trackingId), ['CMP-REAL']);
    });

    test('a body that is not a JSON array is a server failure', () async {
      server.listBody = '{"error": "boom"}';

      expect(repository.all(), throwsA(isA<ServerFailure>()));
    });

    // The load-bearing one. `SET status = ?, fir_no = ?, officer_notes = ?`
    // runs unconditionally, so a body carrying only the status stores NULL over
    // the other two — closing a complaint would delete its FIR link and every
    // note on it.
    test('an update sends the columns it was not asked to change', () async {
      final current = aComplaint(
        firNo: 'FIR/2026/114',
        officerNotes: '[9 Aug 2026, 02:31 UTC · SI K. Deshmukh] Rang her.',
      );
      server.rows = [aComplaintRow()];

      await repository.update(current, status: ComplaintStatus.closed);

      expect(server.patched, hasLength(1));
      expect(server.patched.single['status'], 'Closed');
      expect(server.patched.single['fir_no'], 'FIR/2026/114');
      expect(
        server.patched.single['officer_notes'],
        contains('Rang her.'),
      );
    });

    // The status has to be one of the four or the PATCH is a 400, so a row
    // holding something else cannot simply be echoed back.
    test('an unreadable status becomes Under Review rather than a 400',
        () async {
      server.rows = [aComplaintRow()];

      await repository.update(aComplaint(statusRaw: 'Escalated'));

      expect(server.patched.single['status'], 'Under Review');
    });

    // The handler answers `{message, tracking_id}`, not the row, so the only way
    // to learn the new `updated_at` is to read it back.
    test('reads the complaint back, keeping the phone number it had', () async {
      // What `GET /api/complaint/<id>` returns: no `phone` column at all.
      server.oneBody = jsonEncode(
        aComplaintRow(status: 'Closed')..remove('phone'),
      );

      final updated = await repository.update(
        aComplaint(phone: '9876543210'),
        status: ComplaintStatus.closed,
      );

      expect(updated.status, ComplaintStatus.closed);
      expect(updated.phone, '9876543210');
    });

    // The write already landed. Reporting a failed read-back as a failed update
    // would send an officer to write the same response twice.
    test('a failed read-back does not turn a successful write into an error',
        () async {
      server.oneStatus = 500;

      final updated = await repository.update(
        aComplaint(),
        status: ComplaintStatus.closed,
        officerNotes: 'Closed.',
      );

      expect(updated.status, ComplaintStatus.closed);
      expect(updated.officerNotes, 'Closed.');
    });

    test('a 404 on the PATCH surfaces the server’s own wording', () async {
      server.patchStatus = 404;
      server.patchBody = '{"error": "Complaint not found"}';

      expect(
        repository.update(aComplaint(), status: ComplaintStatus.closed),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'Complaint not found',
          ),
        ),
      );
    });
  });
}

/// A Dio whose adapter answers the three complaints endpoints from memory.
///
/// Written here rather than pulled in as a mocking package: this is the only
/// place in the suite that needs one, the adapter interface is two methods, and
/// what these tests are really asserting is the shape of the bytes on the wire —
/// which a fake at this level shows and a fake at the repository level hides.
class _FakeServer {
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000'));

  /// What `GET /api/complaints/all` answers with, unless [listBody] overrides it.
  List<Map<String, dynamic>> rows = [];

  String? listBody;

  /// What `GET /api/complaint/<id>` answers with. Defaults to the first row.
  String? oneBody;
  int oneStatus = 200;

  int patchStatus = 200;
  String patchBody = '{"message": "Updated successfully"}';

  /// Every PATCH body the app sent, decoded.
  final List<Map<String, dynamic>> patched = [];

  _FakeServer() {
    dio.httpClientAdapter = _Adapter(this);
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.server);

  final _FakeServer server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(String body, int status) => ResponseBody.fromString(
          body,
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    if (options.method == 'PATCH') {
      server.patched.add(
        Map<String, dynamic>.from(options.data as Map),
      );
      return json(server.patchBody, server.patchStatus);
    }

    if (options.path.startsWith('/api/complaints/all')) {
      return json(server.listBody ?? jsonEncode(server.rows), 200);
    }

    // `GET /api/complaint/<tracking_id>`.
    final body = server.oneBody ??
        jsonEncode(
          server.rows.isEmpty ? <String, dynamic>{} : server.rows.first,
        );
    return json(
      server.oneStatus == 200 ? body : '{"error": "Complaint not found."}',
      server.oneStatus,
    );
  }

  @override
  void close({bool force = false}) {}
}

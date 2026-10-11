import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/core/utils/form_dates.dart';
import 'package:nayaya_app/features/fir/data/models/fir_models.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/fir_draft.dart';

/// Pins the short FIR form's rules and its contract with `POST /generate_fir`.
///
/// The wire keys below are taken from the handler in `app.py`, not invented. The
/// server reads each with `data.get(key, "")` and stores whatever it finds, so a
/// key spelt wrong here does not fail — it silently files an FIR with a blank
/// column, and nobody notices until the record is needed.
void main() {
  /// A draft with every required entry filled, plus the two optional ones.
  FirDraft minimal() => const FirDraft(
        firNo: 'FIR001',
        district: 'Delhi',
        policeStation: 'North Delhi PS',
        firDate: '2026-08-09',
        occurrenceDate: '2026-08-07',
        placeOfOccurrence: 'Sector 14 market',
        complainantName: 'A. Sharma',
        statement: 'Two-wheeler taken from outside the market.',
        sections: [ActSection(act: 'IPC', section: '379')],
      );

  group('FirSubmission — the wire contract', () {
    // The form collects twenty-five entries; the record keeps all 27 columns
    // (`year` and `occurrence_day` are derived at submission). Dropping
    // the eighteen blanks would store the same values but change the shape of a
    // document the website's console and the generated PDF both read back.
    test('still sends all 27 keys the handler reads, and no others', () {
      final json = FirSubmission(minimal()).toJson();

      expect(
        json.keys.toSet(),
        {
          'fir_no', 'dist', 'ps', 'year', 'fir_date', //
          'act_sections', 'occurrence_day', 'occurrence_date',
          'occurrence_time', 'info_received_date', 'info_received_time',
          'gdr_entry_no', 'type_of_information', 'place_of_occurrence',
          'complainant_name', 'father_husband_name', 'dob', 'nationality',
          'passport_no', 'date_of_issue', 'place_of_issue', 'occupation',
          'address', 'details_of_accused', 'reasons_for_delay',
          'property_particulars', 'statement',
        },
      );
      expect(json, hasLength(27));
    });

    test('the eighteen entries the short form drops go as empty strings', () {
      final json = FirSubmission(minimal()).toJson();

      const notCollected = [
        'occurrence_time', 'info_received_date', 'info_received_time', //
        'gdr_entry_no', 'type_of_information', 'father_husband_name', 'dob',
        'nationality', 'passport_no', 'date_of_issue', 'place_of_issue',
        'occupation', 'address', 'details_of_accused', 'reasons_for_delay',
        'property_particulars',
      ];

      for (final key in notCollected) {
        expect(json[key], '', reason: key);
      }
    });

    // The server's column names are its own and are not tidy. These are the ones
    // a reasonable person would spell differently.
    test('uses the server\'s spelling for the abbreviated keys', () {
      final json = FirSubmission(minimal()).toJson();

      expect(json['dist'], 'Delhi');
      expect(json['ps'], 'North Delhi PS');
      expect(json['gdr_entry_no'], '');
      expect(json['dob'], '');
    });

    // An empty act_sections makes the server infer the charges from the
    // narrative. The form requires them precisely so that never happens.
    test('never sends an empty act_sections for a submittable draft', () {
      final draft = minimal();

      expect(draft.isSubmittable, isTrue);
      expect(FirSubmission(draft).toJson()['act_sections'], isNotEmpty);
    });

    test('joins sections the way the website does', () {
      final draft = minimal().copyWith(
        sections: const [
          ActSection(act: 'IPC', section: '379'),
          ActSection(act: 'CRPC', section: '41'),
        ],
      );

      expect(
        FirSubmission(draft).toJson()['act_sections'],
        'IPC Section 379, CRPC Section 41',
      );
    });

    test('derives the year from the FIR date rather than asking for it', () {
      expect(FirSubmission(minimal()).toJson()['year'], '2026');

      final december = minimal().copyWith(firDate: '2025-12-31');
      expect(FirSubmission(december).toJson()['year'], '2025');
    });

    test('derives the day of occurrence from its date', () {
      // 2026-08-07 is a Friday.
      expect(FirSubmission(minimal()).toJson()['occurrence_day'], 'Friday');
    });

    test('sends an empty day and year when the dates are missing', () {
      final draft = minimal().copyWith(occurrenceDate: '', firDate: '');

      expect(FirSubmission(draft).toJson()['occurrence_day'], '');
      expect(FirSubmission(draft).toJson()['year'], '');
    });

    test('trims what the officer typed', () {
      final draft = minimal().copyWith(complainantName: '  A. Sharma  ');

      expect(FirSubmission(draft).toJson()['complainant_name'], 'A. Sharma');
    });
  });

  group('FirReceiptResponse', () {
    // The handler echoes the whole stored document. This is its shape.
    final payload = <String, dynamic>{
      'fir_id': '17549023114567',
      'fir_no': 'FIR001',
      'dist': 'Delhi',
      'ps': 'North Delhi PS',
      'act_sections': 'IPC Section 379',
      'statement': 'Two-wheeler taken from outside the market.',
      'pdf_file': 'FIR_FIR001.pdf',
      'created_at': '2026-08-09 10:11:12.345678',
      'status': 'Saved to Police Records',
      'formatted_fir': 'FIR ID: 17549023114567\nFIR NO: FIR001\n…',
      'message':
          'FIR has been successfully registered and saved to police records.',
    };

    test('reads only what the client could not already know', () {
      final receipt = FirReceiptResponse.fromJson(payload);

      expect(receipt.firNo, 'FIR001');
      expect(receipt.firId, '17549023114567');
      expect(receipt.actSections, 'IPC Section 379');
      expect(receipt.pdfFile, 'FIR_FIR001.pdf');
      expect(receipt.createdAt, '2026-08-09 10:11:12.345678');
      expect(receipt.status, 'Saved to Police Records');
      expect(receipt.hasPdf, isTrue);
    });

    // What a current server actually replies with. PDF storage moved to
    // Supabase and the column moved with it; a receipt that reads only
    // `pdf_file` reports "no PDF" for every FIR filed since, including the one
    // the officer is looking at the receipt for.
    test('reads the PDF from pdf_url, showing its filename not the URL', () {
      final receipt = FirReceiptResponse.fromJson({
        ...payload,
        'pdf_file': null,
        'pdf_url': 'https://uafjhimjuyfqkqfnadei.supabase.co/storage/v1/object/'
            'public/firs/1787717861371606.pdf',
      });

      expect(receipt.hasPdf, isTrue);
      expect(receipt.pdfLabel, '1787717861371606.pdf');
      expect(receipt.pdfUrl, contains('supabase.co'));
    });

    test('a record naming no PDF at all claims none', () {
      final receipt = FirReceiptResponse.fromJson({
        ...payload,
        'pdf_file': null,
        'pdf_url': null,
      });

      expect(receipt.hasPdf, isFalse);
      expect(receipt.pdfLabel, isEmpty);
    });

    test('survives a field arriving as something other than a String', () {
      // `created_at` is a Python datetime stringified by hand, and the FIR
      // number is echoed from whatever the request sent.
      final receipt = FirReceiptResponse.fromJson({
        ...payload,
        'fir_no': 1234,
        'created_at': null,
      });

      expect(receipt.firNo, '1234');
      expect(receipt.createdAt, '');
    });

    test('an empty body parses rather than throwing', () {
      final receipt = FirReceiptResponse.fromJson(const {});

      expect(receipt.firNo, '');
      expect(receipt.hasPdf, isFalse);
    });
  });

  group('required entries', () {
    // Six of the twenty-five typed entries. The server insists on none of them,
    // so this list is the app's own judgement about what makes a record usable,
    // and it is worth pinning: each addition is another thing standing between
    // an officer and a registered FIR.
    //
    // The order is step order, and that is load-bearing — `submit` sends the
    // officer to the first step with something missing, so a list that did not
    // follow the wizard would send them to the wrong page.
    test('six entries are required, named and ordered as the wizard is', () {
      expect(
        const FirDraft().missing,
        [
          // Step 1 — registration. Acts and sections are NOT here: the server
          // fills them from the narrative when they arrive empty, and the
          // website's field is optional for the same reason.
          'FIR number', 'District / State', 'Police station', 'FIR date',
          // Step 3 — the complainant. Step 2 requires nothing at all.
          'Complainant name',
          // Step 4 — the complaint.
          'What happened',
        ],
      );
      expect(const FirDraft().isSubmittable, isFalse);
    });

    // The whole point of the optional eighteen: an FIR must stay fileable at a
    // counter when the complainant has no passport, no idea who the accused is,
    // and is not sure which day it happened.
    test('the other eighteen entries do not block filing', () {
      final draft = minimal();

      expect(draft.missing, isEmpty);
      expect(draft.isSubmittable, isTrue);
      // Filed with the whole of step 3's passport block and all of step 4's
      // optional entries left blank.
      expect(draft.passportNo, isEmpty);
      expect(draft.dateOfIssue, isEmpty);
      expect(draft.detailsOfAccused, isEmpty);
      expect(draft.propertyParticulars, isEmpty);
      expect(draft.reasonsForDelay, isEmpty);
    });

    test('each step reports only its own blanks', () {
      const draft = FirDraft();

      expect(draft.missingIn(FirFormStep.registration), hasLength(4));
      // Every entry on step 2 is one an officer may genuinely not have while
      // the complainant is still standing there.
      expect(draft.missingIn(FirFormStep.occurrence), isEmpty);
      expect(draft.missingIn(FirFormStep.complainant), ['Complainant name']);
      expect(draft.missingIn(FirFormStep.complaint), ['What happened']);
      expect(draft.missingIn(FirFormStep.review), isEmpty);
    });

    test('names exactly what is missing and nothing else', () {
      const draft = FirDraft(
        firNo: 'FIR001',
        district: 'Delhi',
        policeStation: 'North Delhi PS',
        firDate: '2026-08-09',
        complainantName: 'A. Sharma',
      );

      expect(draft.missing, ['What happened']);
    });

    test('whitespace does not count as an answer', () {
      expect(
        minimal().copyWith(complainantName: '   ').missing,
        ['Complainant name'],
      );
    });

    // The parity fix. The app used to demand sections the website's form left
    // optional, so an officer who did not know them could file at the desk and
    // not on the handset. `/generate_fir` reads an empty `act_sections` as
    // "work them out from the narrative" and files the record under what it
    // finds; the receipt then says what that was.
    test('sections are optional, because the server fills them in', () {
      final draft = minimal().copyWith(sections: const []);

      expect(draft.missing, isEmpty);
      expect(draft.isSubmittable, isTrue);
      // Sent as an empty string, which is the value the server's branch tests.
      expect(FirSubmission(draft).toJson()['act_sections'], '');
    });
  });

  group('derived entries', () {
    test('the year follows the FIR date, so the two cannot disagree', () {
      expect(minimal().copyWith(firDate: '2027-01-02').year, '2027');
      expect(minimal().copyWith(firDate: '').year, '');
      expect(minimal().copyWith(firDate: 'not a date').year, '');
    });

    test('the day of occurrence follows its date', () {
      expect(
        minimal().copyWith(occurrenceDate: '2026-08-09').occurrenceDay,
        'Sunday',
      );
      expect(minimal().copyWith(occurrenceDate: '').occurrenceDay, '');
    });
  });

  group('autosave round-trip', () {
    test('restores every entry', () {
      final draft = minimal().copyWith(
        sections: const [
          ActSection(act: 'IPC', section: '379'),
          ActSection(act: 'IPC', section: '411'),
        ],
      );

      final restored = FirDraft.fromJson(
        jsonDecode(jsonEncode(draft.toJson())) as Map<String, dynamic>,
      );

      expect(restored, draft);
      expect(restored.sections, hasLength(2));
    });

    test('a payload missing keys restores what it can', () {
      final restored = FirDraft.fromJson(const {'fir_no': 'FIR009'});

      expect(restored.firNo, 'FIR009');
      expect(restored.statement, '');
      expect(restored.sections, isEmpty);
    });

    // A draft written by the four-step build is still sitting in secure storage
    // on any handset that had it. Its address lived under a different key, and
    // losing it silently on upgrade is the one failure autosave exists to avoid.
    test('a draft saved by the long form keeps its address', () {
      final restored = FirDraft.fromJson(const {
        'fir_no': 'FIR009',
        'place_address': 'Sector 14 market',
        'complainant_name': 'A. Sharma',
      });

      expect(restored.placeOfOccurrence, 'Sector 14 market');
      expect(restored.complainantName, 'A. Sharma');
    });

    test('drops a half-written section rather than restoring a broken one', () {
      final restored = FirDraft.fromJson(const {
        'sections': [
          {'act': 'IPC', 'section': '379'},
          {'act': 'IPC'},
          {'section': '411'},
        ],
      });

      expect(restored.sections, [const ActSection(act: 'IPC', section: '379')]);
    });

    test('an empty draft is recognised as nothing worth restoring', () {
      expect(const FirDraft().isEmpty, isTrue);
      expect(const FirDraft(firDate: '2026-08-09').isEmpty, isFalse);
      expect(
        const FirDraft(sections: [ActSection(act: 'IPC', section: '379')])
            .isEmpty,
        isFalse,
      );
    });
  });

  group('FormDates', () {
    test('writes the format the website posts', () {
      expect(FormDates.toWireDate(DateTime(2026, 8, 9)), '2026-08-09');
      expect(FormDates.toWireTime(9, 5), '09:05');
      expect(FormDates.toWireTime(23, 59), '23:59');
    });

    test('displays dates unambiguously', () {
      expect(FormDates.displayDate('2026-08-09'), '9 Aug 2026');
      expect(FormDates.displayTime('14:05'), '14:05 hrs');
    });

    // A value typed on the website in some other format must still show.
    test('passes through what it cannot parse', () {
      expect(FormDates.displayDate('09/08/2026'), '09/08/2026');
      expect(FormDates.displayDate(''), '');
      expect(FormDates.displayTime('half past two'), 'half past two');
    });

    test('rejects an out-of-range time rather than wrapping it', () {
      expect(FormDates.parseWireTime('25:00'), isNull);
      expect(FormDates.parseWireTime('12:61'), isNull);
      expect(FormDates.parseWireTime('12'), isNull);
    });

    test('names the weekday', () {
      expect(FormDates.weekdayName('2026-08-09'), 'Sunday');
      expect(FormDates.weekdayName('2026-08-10'), 'Monday');
      expect(FormDates.weekdayName(''), '');
    });
  });

  group('ActSection', () {
    test('spells a pair the way the column stores it', () {
      expect(
        const ActSection(act: 'IPC', section: '376(2)').wire,
        'IPC Section 376(2)',
      );
    });

    test('an empty list joins to an empty string', () {
      expect(ActSection.wireList(const []), '');
    });
  });
}

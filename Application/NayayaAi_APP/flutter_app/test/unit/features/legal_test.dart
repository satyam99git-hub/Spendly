import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/features/legal/data/models/legal_models.dart';
import 'package:nayaya_app/features/legal/domain/entities/legal_section.dart';

/// The law library below the widgets.
///
/// Everything here is about one thing: the three endpoints that return a
/// section return it in three different shapes, and the app has one class for
/// all three. These are the differences that would otherwise show up as a blank
/// screen in the field.
void main() {
  group('the paginated envelope', () {
    Map<String, dynamic> aPage() => {
          'act': 'IPC',
          'page': 1,
          'limit': 20,
          'pages': 288,
          'total': 575,
          'results': [
            {
              // An INTEGER column. A model that cast this to String would throw
              // on the first row of the first page of the first act.
              'section': 379,
              'title': 'Punishment for theft',
              'description': 'Whoever commits theft shall be punished…',
            },
          ],
        };

    test('reads the rows and what the server said about the rest', () {
      final page = LegalSectionPageResponse.fromJson(
        aPage(),
        fallbackAct: 'IPC',
      );

      expect(page.act, 'IPC');
      expect(page.page, 1);
      expect(page.pages, 288);
      expect(page.total, 575);
      expect(page.hasMore, isTrue);
      expect(page.sections, hasLength(1));
    });

    test('a numeric section number is read as text', () {
      final page = LegalSectionPageResponse.fromJson(
        aPage(),
        fallbackAct: 'IPC',
      );

      expect(page.sections.single.section, '379');
    });

    // The act is on the envelope, not on the rows. A row that did not know its
    // own act could not be opened: /api/section-detail needs both halves.
    test('the envelope\'s act is pushed down onto every row', () {
      final page = LegalSectionPageResponse.fromJson(
        aPage(),
        fallbackAct: 'CRPC',
      );

      expect(page.sections.single.act, 'IPC');
      expect(page.sections.single.longLabel, 'IPC Section 379');
    });

    test('the requested act stands in when the server does not echo one', () {
      final page = LegalSectionPageResponse.fromJson(
        aPage()..remove('act'),
        fallbackAct: 'CRPC',
      );

      expect(page.act, 'CRPC');
      expect(page.sections.single.act, 'CRPC');
    });

    test('the last page knows it is the last', () {
      final page = LegalSectionPageResponse.fromJson(
        {...aPage(), 'page': 288},
        fallbackAct: 'IPC',
      );

      expect(page.hasMore, isFalse);
    });
  });

  group('a cross-act search hit', () {
    // /api/search-sections selects act, section and title — no description.
    // The tile omits the body rather than printing a placeholder on every row.
    test('carries its own act and no text, and says so', () {
      final hit = LegalSectionResponse.fromJson(
        {'act': 'CRPC', 'section': 41, 'title': 'When police may arrest'},
        fallbackAct: '',
      );

      expect(hit.act, 'CRPC');
      expect(hit.section, '41');
      expect(hit.isSummary, isTrue);
      expect(hit.label, 'CRPC 41');
    });

    test('a full row is not a summary', () {
      const full = LegalSection(
        act: 'IPC',
        section: '379',
        title: 'Punishment for theft',
        description: 'Whoever commits theft…',
      );

      expect(full.isSummary, isFalse);
    });
  });

  group('an outcome finding', () {
    Map<String, dynamic> aFinding() => {
          'act': 'IPC',
          'section': '378',
          'title': 'Theft',
          'description': 'Whoever intending to take dishonestly…',
          'punishment': 'Imprisonment up to 3 years or fine or both',
          'bns_equivalent': 'BNS Section 303',
          'sentencing_range': '6 months to 3 years',
          'cognizable': 'Yes',
          'bailable': 'Yes',
          'outcome_note': 'Police can arrest without warrant.',
          'score': 12.0,
        };

    test('reads every column the card shows', () {
      final finding = OutcomeFindingResponse.fromJson(aFinding());

      expect(finding.longLabel, 'IPC Section 378');
      expect(finding.punishment, isNotEmpty);
      expect(finding.bnsEquivalent, 'BNS Section 303');
      expect(finding.score, 12.0);
    });

    // The columns are free text out of a CSV, not booleans.
    test('cognizable and bailable are read from words', () {
      expect(OutcomeFindingResponse.fromJson(aFinding()).isCognizable, isTrue);
      expect(
        OutcomeFindingResponse.fromJson({...aFinding(), 'bailable': 'No'})
            .isBailable,
        isFalse,
      );
    });

    // A blank column is not a finding of "no". Reporting an offence as
    // non-cognizable because the dataset row was empty would be worse than
    // showing no flag at all, which is what null makes the card do.
    test('a column that says neither is null, not false', () {
      final finding = OutcomeFindingResponse.fromJson({
        ...aFinding(),
        'cognizable': '',
        'bailable': 'Depends on the value',
      });

      expect(finding.isCognizable, isNull);
      expect(finding.isBailable, isNull);
    });

    test('a row with no act is attributed to the IPC, as the dataset assumes',
        () {
      final finding =
          OutcomeFindingResponse.fromJson({...aFinding(), 'act': null});

      expect(finding.act, 'IPC');
    });
  });
}

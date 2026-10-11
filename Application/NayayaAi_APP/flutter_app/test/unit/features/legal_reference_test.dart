import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/features/legal/domain/entities/legal_reference.dart';

/// The two lookups the website keeps as hardcoded JavaScript objects.
///
/// These tests exist mostly to pin the transcription: the data has no server
/// behind it, so nothing else would notice if a definition were dropped or a
/// section renumbered wrongly on the way across.
void main() {
  group('the glossary', () {
    test('carries every term the website has', () {
      expect(legalGlossary, hasLength(23));
    });

    test('every entry has both halves', () {
      for (final term in legalGlossary) {
        expect(term.term.trim(), isNotEmpty);
        expect(term.definition.trim(), isNotEmpty, reason: term.term);
      }
    });

    test('terms are unique', () {
      final terms = legalGlossary.map((t) => t.term).toList();
      expect(terms.toSet(), hasLength(terms.length));
    });

    test('matches on the term', () {
      final hits = legalGlossary.where((t) => t.matches('cognizable')).toList();

      expect(
        hits.map((t) => t.term),
        containsAll(['cognizable', 'non-cognizable']),
      );
    });

    // The website matches only the term, so an officer who knows the idea but
    // not the word finds nothing. Searching the definition answers the question
    // they actually asked.
    test('matches on the definition too, unlike the website', () {
      final hits =
          legalGlossary.where((t) => t.matches('without a warrant')).toList();

      expect(hits, isNotEmpty);
      // None of these have "without a warrant" in the term itself.
      expect(
        hits.any((t) => !t.term.contains('without a warrant')),
        isTrue,
      );
    });

    test('an empty query matches everything', () {
      expect(
        legalGlossary.where((t) => t.matches('')).length,
        legalGlossary.length,
      );
    });
  });

  group('the 2023 renumbering', () {
    test('carries every mapping the website has', () {
      expect(lawAmendments, hasLength(13));
    });

    test('the ones an officer looks up most', () {
      String newFor(String old) =>
          lawAmendments.firstWhere((a) => a.oldSection == old).newSection;

      expect(newFor('ipc 302'), 'BNS Section 103');
      expect(newFor('crpc 154'), 'BNSS Section 173');
      expect(newFor('crpc 41'), 'BNSS Section 35');
      expect(newFor('ipc 420'), 'BNS Section 318');
    });

    test('every old section is keyed lower case, as the website keys them', () {
      for (final amendment in lawAmendments) {
        expect(amendment.oldSection, amendment.oldSection.toLowerCase());
        expect(
          amendment.oldSection,
          anyOf(startsWith('ipc '), startsWith('crpc ')),
        );
      }
    });

    test('the label reads the way an officer writes it', () {
      final murder = lawAmendments.firstWhere((a) => a.oldSection == 'ipc 302');

      expect(murder.oldLabel, 'IPC 302');
      expect(murder.note, 'Murder');
    });

    // An officer types "302", not "ipc 302".
    test('a bare number finds its section', () {
      final hits = lawAmendments.where((a) => a.matches('302')).toList();

      expect(hits.map((a) => a.oldSection), contains('ipc 302'));
    });

    test('it is searchable from the new side and from the note', () {
      expect(
        lawAmendments.where((a) => a.matches('bns section 103')).length,
        1,
      );
      expect(
        lawAmendments.where((a) => a.matches('anticipatory')).single.oldSection,
        'crpc 438',
      );
    });

    test('mappings are unique', () {
      final olds = lawAmendments.map((a) => a.oldSection).toList();
      expect(olds.toSet(), hasLength(olds.length));
    });
  });
}

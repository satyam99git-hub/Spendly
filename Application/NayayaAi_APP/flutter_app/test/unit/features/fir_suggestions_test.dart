import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/features/fir/data/models/fir_models.dart';
import 'package:nayaya_app/features/fir/domain/entities/act_section.dart';
import 'package:nayaya_app/features/fir/domain/entities/section_suggestion.dart';

void main() {
  group('SectionSuggestionsResponse', () {
    test('reads a full answer', () {
      final result = SectionSuggestionsResponse.fromJson({
        'suggestions': [
          {
            'act': 'IPC',
            'section': '390',
            'title': 'Robbery',
            'reason': 'Chain snatched with force',
            'confidence': 'high',
          },
        ],
        'source': 'groq',
        'note': 'May also attract the IT Act.',
      });

      expect(result.suggestions, hasLength(1));
      expect(result.source, SuggestionSource.groq);
      expect(result.note, 'May also attract the IT Act.');
      expect(result.isFallback, isFalse);

      final only = result.suggestions.single;
      expect(only.act, 'IPC');
      expect(only.section, '390');
      expect(only.title, 'Robbery');
      expect(only.reason, 'Chain snatched with force');
      expect(only.confidence, SuggestionConfidence.high);
      expect(only.asSection, const ActSection(act: 'IPC', section: '390'));
    });

    test('upper-cases the act, so chips match the ones typed by hand', () {
      final result = SectionSuggestionsResponse.fromJson({
        'suggestions': [
          {'act': 'ipc', 'section': '379'},
        ],
      });

      expect(result.suggestions.single.act, 'IPC');
    });

    test('drops a row with no act or no section', () {
      final result = SectionSuggestionsResponse.fromJson({
        'suggestions': [
          {'act': 'IPC', 'section': '379'},
          {'act': '', 'section': '379'},
          {'act': 'IPC', 'section': ''},
          {'reason': 'nothing else at all'},
        ],
      });

      // A row with no pair cannot become a chip on an FIR, so it is not offered
      // as one.
      expect(result.suggestions, hasLength(1));
      expect(result.suggestions.single.section, '379');
    });

    test('survives every field being absent', () {
      final result = SectionSuggestionsResponse.fromJson({
        'suggestions': [
          {'act': 'IPC', 'section': '379'},
        ],
      });

      final only = result.suggestions.single;
      expect(only.title, isEmpty);
      expect(only.reason, isEmpty);
      // Unlabelled reads as medium, never as high: a suggestion the server
      // could not rate is not one to present as certain.
      expect(only.confidence, SuggestionConfidence.medium);
      expect(result.source, SuggestionSource.none);
    });

    test('a non-list suggestions key is an empty answer, not a crash', () {
      expect(
        SectionSuggestionsResponse.fromJson({'suggestions': 'nope'})
            .suggestions,
        isEmpty,
      );
      expect(SectionSuggestionsResponse.fromJson({}).suggestions, isEmpty);
    });

    test('reads the keyword fallback as a fallback', () {
      final result = SectionSuggestionsResponse.fromJson({
        'suggestions': [
          {'act': 'IPC', 'section': '379', 'confidence': 'low'},
        ],
        'source': 'keyword',
      });

      expect(result.source, SuggestionSource.keyword);
      expect(result.isFallback, isTrue);
    });

    test('carries the server sentence for a narrative too short to work from',
        () {
      final result = SectionSuggestionsResponse.fromJson({
        'suggestions': <dynamic>[],
        'source': 'none',
        'message': 'Write a little more of the narrative first.',
      });

      expect(result.isEmpty, isTrue);
      expect(result.message, 'Write a little more of the narrative first.');
    });
  });

  group('SuggestionConfidence', () {
    test('reads the three the server sends, whatever the casing', () {
      expect(SuggestionConfidence.fromWire('HIGH'), SuggestionConfidence.high);
      expect(SuggestionConfidence.fromWire(' low '), SuggestionConfidence.low);
      expect(
        SuggestionConfidence.fromWire('medium'),
        SuggestionConfidence.medium,
      );
    });

    test('anything else is medium', () {
      expect(SuggestionConfidence.fromWire(null), SuggestionConfidence.medium);
      expect(
        SuggestionConfidence.fromWire('certain'),
        SuggestionConfidence.medium,
      );
    });
  });
}

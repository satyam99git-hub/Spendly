import 'act_section.dart';

/// How much the server stands behind one suggestion.
///
/// Three levels rather than a percentage. The number the model would produce is
/// not calibrated against anything — it is a word it chose, not a measurement —
/// and printing "87%" beside a charge would give an officer a precision that
/// does not exist. Three words are as much as the underlying answer supports.
enum SuggestionConfidence {
  high('High'),
  medium('Medium'),
  low('Low');

  const SuggestionConfidence(this.label);

  final String label;

  static SuggestionConfidence fromWire(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'high' => SuggestionConfidence.high,
        'low' => SuggestionConfidence.low,
        // Anything unrecognised reads as medium rather than as high: a
        // suggestion the server could not label is not one to present as
        // certain.
        _ => SuggestionConfidence.medium,
      };
}

/// Where a set of suggestions came from.
///
/// Reported to the officer, not hidden, because the two are not equally good.
/// [keyword] is the same keyword matcher `/generate_fir` has always used when
/// the sections field is left blank — it matches words, not meaning. Letting the
/// screen say which one answered is the difference between an officer trusting a
/// weak answer and knowing to check it.
enum SuggestionSource {
  /// The model read the narrative. Every section was verified against the
  /// statute database before it was sent.
  groq,

  /// The model was unreachable, so the keyword matcher answered instead.
  keyword,

  /// Nothing matched. Not a failure — some narratives disclose no offence.
  none;

  static SuggestionSource fromWire(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'groq' => SuggestionSource.groq,
        'keyword' => SuggestionSource.keyword,
        _ => SuggestionSource.none,
      };
}

/// One act and section the server thinks the narrative discloses, with its
/// reason for saying so.
class SectionSuggestion {
  const SectionSuggestion({
    required this.act,
    required this.section,
    this.title = '',
    this.reason = '',
    this.confidence = SuggestionConfidence.medium,
  });

  /// An act code — `IPC`, `CRPC`, `MVA`. The same spelling [ActSection] uses, so
  /// an accepted suggestion becomes a chip without translation.
  final String act;

  /// The section number, as text. `379`, `304A`, `498A`.
  final String section;

  /// The statutory title, read out of the server's own section tables rather
  /// than written by the model. Empty when the server could not find one, which
  /// is the normal case for a keyword-matcher answer naming an act the section
  /// tables do not carry (POCSO, NDPS, the IT Act).
  final String title;

  /// One clause naming the fact in the narrative that triggers this section.
  /// Empty for a [SuggestionSource.keyword] answer, which has no reasoning to
  /// report — it matched words.
  final String reason;

  final SuggestionConfidence confidence;

  /// The pair as the form stores it.
  ActSection get asSection => ActSection(act: act, section: section);

  /// True when there is nothing to add to the form — a row with no act or no
  /// section number cannot become a chip.
  bool get isEmpty => act.trim().isEmpty || section.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionSuggestion &&
          other.act == act &&
          other.section == section &&
          other.title == title &&
          other.reason == reason &&
          other.confidence == confidence;

  @override
  int get hashCode => Object.hash(act, section, title, reason, confidence);

  @override
  String toString() => 'SectionSuggestion($act $section, $confidence)';
}

/// What `POST /api/suggest-sections` answered.
class SectionSuggestions {
  const SectionSuggestions({
    this.suggestions = const [],
    this.source = SuggestionSource.none,
    this.note = '',
    this.message = '',
  });

  final List<SectionSuggestion> suggestions;
  final SuggestionSource source;

  /// The server's remark about an act its section tables do not carry — "this
  /// may also attract the IT Act". Prose for the officer to act on themselves,
  /// deliberately not a suggestion: nothing verified it, so it must not become a
  /// chip that looks as solid as the ones that were.
  final String note;

  /// The server's own sentence for a request it declined to answer — a narrative
  /// too short to work from. Shown instead of an empty state, because "write a
  /// little more first" is an instruction and "no suggestions" is a dead end.
  final String message;

  bool get isEmpty => suggestions.isEmpty;

  /// True when the answer came from the keyword matcher rather than the model,
  /// which the screen says out loud.
  bool get isFallback => source == SuggestionSource.keyword;
}

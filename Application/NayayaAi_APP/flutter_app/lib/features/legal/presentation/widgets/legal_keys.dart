import 'package:flutter/widgets.dart';

/// Widget keys for the law library and the two legal-AI surfaces.
///
/// Named rather than found by text for the same reason the rest of the app's
/// keys are: a test that taps `find.text('IPC')` starts failing the day a
/// section title contains the word.
abstract final class LegalKeys {
  const LegalKeys._();

  // ---- the library ----------------------------------------------------------

  static const library = Key('law-library');
  static const librarySearch = Key('law-library-search');
  static const actChips = Key('law-library-acts');

  static Key actChip(String act) => Key('law-act-$act');

  static Key sectionTile(String act, String section) =>
      Key('law-section-$act-$section');

  static const loadMore = Key('law-library-load-more');

  // ---- one section ----------------------------------------------------------

  static const sectionDetail = Key('law-section-detail');
  static const compareAction = Key('law-section-compare');
  static const comparePanel = Key('law-section-compare-panel');
  static const useInFir = Key('law-section-use-in-fir');

  // ---- ask the law ----------------------------------------------------------

  static const ask = Key('law-ask');
  static const askInput = Key('law-ask-input');
  static const askSubmit = Key('law-ask-submit');
  static const askAnswer = Key('law-ask-answer');

  // ---- terms and the new codes ----------------------------------------------

  static const reference = Key('law-reference');
  static const referenceSearch = Key('law-reference-search');

  static Key amendmentRow(String oldSection) =>
      Key('law-amendment-$oldSection');

  static Key glossaryRow(String term) => Key('law-term-$term');

  // ---- outcome --------------------------------------------------------------

  static const outcome = Key('law-outcome');
  static const outcomeInput = Key('law-outcome-input');
  static const outcomeSubmit = Key('law-outcome-submit');

  static Key outcomeCard(String act, String section) =>
      Key('law-outcome-$act-$section');
}

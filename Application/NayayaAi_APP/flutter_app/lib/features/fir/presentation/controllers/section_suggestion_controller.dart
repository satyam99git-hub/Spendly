import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/section_suggestion.dart';
import 'fir_providers.dart';

/// What the suggestion sheet is showing.
class SectionSuggestionState {
  const SectionSuggestionState({
    this.busy = false,
    this.result,
    this.failure,
  });

  final bool busy;

  /// Null until something has been asked. Distinguishes "not asked yet" from
  /// "asked, and the answer was nothing" — the sheet says different things for
  /// the two, and a bare empty list cannot tell them apart.
  final SectionSuggestions? result;

  final Failure? failure;

  bool get hasAsked => result != null || failure != null;
}

/// Asks the server what sections a narrative discloses.
///
/// Not `autoDispose`: the sheet is opened, closed and reopened while the officer
/// works through the suggestions, and re-asking the model on every reopen would
/// spend the station's quota to redisplay an answer it already had. The state is
/// cleared when the form is, by [reset].
class SectionSuggestionController extends Notifier<SectionSuggestionState> {
  @override
  SectionSuggestionState build() => const SectionSuggestionState();

  /// Asks about [narrative]. Safe to call again; the last answer wins.
  Future<void> ask(String narrative) async {
    if (state.busy) return;
    state = SectionSuggestionState(busy: true, result: state.result);

    try {
      final result =
          await ref.read(firRepositoryProvider).suggestSections(narrative);
      state = SectionSuggestionState(result: result);
    } on Failure catch (failure) {
      // Kept as a failure rather than swallowed into an empty list. The 403 a
      // non-police account gets is a real answer the officer needs to see, and
      // "no sections matched" would be a lie about it.
      state = SectionSuggestionState(failure: failure);
    }
  }

  /// Forgets the last answer. Called when the draft is discarded or filed, so a
  /// new FIR does not open onto the previous complaint's sections.
  void reset() => state = const SectionSuggestionState();
}

final sectionSuggestionControllerProvider =
    NotifierProvider<SectionSuggestionController, SectionSuggestionState>(
  SectionSuggestionController.new,
);

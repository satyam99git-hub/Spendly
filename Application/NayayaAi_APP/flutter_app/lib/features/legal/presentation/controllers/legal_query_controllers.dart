import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/outcome_finding.dart';
import 'legal_providers.dart';

/// One asked question and whatever came back.
///
/// Deliberately holds a single answer rather than a transcript. Neither
/// endpoint has any memory — every call is scored fresh against the section
/// tables, with no reference to what was asked before — so a chat-shaped screen
/// would promise a conversation the server cannot hold up its end of.
class LegalQueryState<T> {
  const LegalQueryState({
    this.asked = '',
    this.answer,
    this.busy = false,
    this.failure,
  });

  /// The question exactly as sent. Shown above the answer, because an officer
  /// who has scrolled a long answer needs to see what it is answering.
  final String asked;

  final T? answer;
  final bool busy;
  final Failure? failure;

  bool get hasAnswer => answer != null;

  LegalQueryState<T> copyWith({
    String? asked,
    T? answer,
    bool? busy,
    Failure? failure,
    bool clearAnswer = false,
    bool clearFailure = false,
  }) {
    return LegalQueryState<T>(
      asked: asked ?? this.asked,
      answer: clearAnswer ? null : (answer ?? this.answer),
      busy: busy ?? this.busy,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// A legal question, answered from the section tables.
final askLawControllerProvider =
    NotifierProvider.autoDispose<AskLawController, LegalQueryState<String>>(
  AskLawController.new,
);

class AskLawController extends AutoDisposeNotifier<LegalQueryState<String>> {
  @override
  LegalQueryState<String> build() => const LegalQueryState<String>();

  /// Sends [question]. A blank one is refused here rather than by the server:
  /// the 400 it would answer with says the same thing several seconds later.
  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || state.busy) return;

    state = state.copyWith(
      asked: text,
      busy: true,
      clearAnswer: true,
      clearFailure: true,
    );

    try {
      final answer = await ref.read(legalRepositoryProvider).ask(text);
      state = state.copyWith(answer: answer, busy: false);
    } catch (error) {
      state = state.copyWith(
        busy: false,
        failure: ErrorMapper.map(error, context: 'api/ask-law'),
      );
    }
  }

  void clear() => state = const LegalQueryState<String>();
}

/// A described situation, matched against the sentencing dataset.
final outcomeControllerProvider = NotifierProvider.autoDispose<
    OutcomeController, LegalQueryState<List<OutcomeFinding>>>(
  OutcomeController.new,
);

class OutcomeController
    extends AutoDisposeNotifier<LegalQueryState<List<OutcomeFinding>>> {
  @override
  LegalQueryState<List<OutcomeFinding>> build() =>
      const LegalQueryState<List<OutcomeFinding>>();

  /// Runs the search. An empty result is an answer — "nothing in the dataset
  /// matches those words" — and is stored as one rather than as a failure.
  Future<void> run(String situation) async {
    final text = situation.trim();
    if (text.isEmpty || state.busy) return;

    state = state.copyWith(
      asked: text,
      busy: true,
      clearAnswer: true,
      clearFailure: true,
    );

    try {
      final findings =
          await ref.read(legalRepositoryProvider).predictOutcome(text);
      state = state.copyWith(answer: findings, busy: false);
    } catch (error) {
      state = state.copyWith(
        busy: false,
        failure: ErrorMapper.map(error, context: 'api/predict-outcome'),
      );
    }
  }

  void clear() => state = const LegalQueryState<List<OutcomeFinding>>();
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/legal_section.dart';
import 'legal_providers.dart';

/// What the law library is showing: one act, one search, and however many pages
/// of it have been asked for.
class LawLibraryState {
  const LawLibraryState({
    this.act = '',
    this.query = '',
    this.sections = const [],
    this.page = 0,
    this.pages = 1,
    this.total = 0,
    this.loading = false,
    this.loadingMore = false,
    this.failure,
  });

  /// Which act is open. Empty before the act list has arrived.
  final String act;

  /// The search box, as last applied — not as currently typed. Typing is
  /// debounced, and a state that changed on every keystroke would refetch on
  /// every keystroke.
  final String query;

  /// Every section loaded so far for [act] and [query], in server order.
  ///
  /// Accumulated across pages rather than replaced, because the library is a
  /// scrolling list and IPC alone is 288 pages of it.
  final List<LegalSection> sections;

  /// The last page successfully loaded. Zero when none has been.
  final int page;

  /// How many pages the current query has, as the server counts them.
  final int pages;

  /// Matching sections across every page — what the header states, so an
  /// officer can see that "theft" narrowed 575 sections to nine.
  final int total;

  /// A first page is in flight: the list is empty and a spinner replaces it.
  final bool loading;

  /// A further page is in flight: the list is on screen and a spinner sits at
  /// the end of it. Kept apart from [loading] because they are different
  /// pictures, and using one flag for both makes the list disappear every time
  /// the officer reaches the bottom.
  final bool loadingMore;

  final Failure? failure;

  bool get hasMore => page < pages;
  bool get isEmpty => sections.isEmpty && !loading;

  LawLibraryState copyWith({
    String? act,
    String? query,
    List<LegalSection>? sections,
    int? page,
    int? pages,
    int? total,
    bool? loading,
    bool? loadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return LawLibraryState(
      act: act ?? this.act,
      query: query ?? this.query,
      sections: sections ?? this.sections,
      page: page ?? this.page,
      pages: pages ?? this.pages,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Browsing one act, a page at a time.
///
/// ---------------------------------------------------------------------------
/// WHY THIS PAGES AND THE OTHER LISTS IN THIS APP DO NOT
///
/// FIR history and the complaints inbox both fetch everything and filter in the
/// client, because their endpoints take no query and offer no page — the choice
/// there is between filtering locally and not at all.
///
/// `GET /api/sections/<act>` is the opposite: it pages, it searches, and the
/// thing being paged is 575 rows for the IPC and thousands across the eight
/// acts. Pulling all of it to filter locally would be a several-megabyte
/// download on a station link to answer "what is 379".
/// ---------------------------------------------------------------------------
final lawLibraryControllerProvider =
    NotifierProvider.autoDispose<LawLibraryController, LawLibraryState>(
  LawLibraryController.new,
);

class LawLibraryController extends AutoDisposeNotifier<LawLibraryState> {
  /// How long typing has to pause before the search is sent.
  ///
  /// Every keystroke is a query against a table of thousands. A quarter of a
  /// second is below the point a person notices a delay and above the point
  /// where "theft" is five separate searches.
  static const _debounce = Duration(milliseconds: 250);

  /// The server's own default, restated because the footer's arithmetic
  /// ("showing 40 of 575") depends on it.
  static const pageSize = 20;

  Timer? _debounceTimer;

  /// Bumped on every new act or query, and checked before a response is
  /// applied. Without it a slow answer for "the" lands after a fast one for
  /// "theft" and the list shows the wrong search.
  int _generation = 0;

  @override
  LawLibraryState build() {
    ref.onDispose(() => _debounceTimer?.cancel());
    return const LawLibraryState();
  }

  /// Opens an act, discarding whatever was on screen.
  ///
  /// The search box is deliberately kept: an officer comparing how two acts
  /// treat "cheating" switches act with the word still typed, and clearing it
  /// would make them type it again.
  Future<void> openAct(String act) async {
    if (act == state.act) return;
    state = state.copyWith(act: act);
    await _reload();
  }

  /// Called on every keystroke. Debounced; see [_debounce].
  void search(String query) {
    _debounceTimer?.cancel();
    if (query.trim() == state.query) return;
    _debounceTimer = Timer(_debounce, () {
      state = state.copyWith(query: query.trim());
      unawaited(_reload());
    });
  }

  /// Loads the next page onto the end of the list. A no-op while one is already
  /// in flight, so a fling at the bottom of the list asks once.
  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    if (state.act.isEmpty) return;

    final generation = _generation;
    state = state.copyWith(loadingMore: true, clearFailure: true);

    try {
      final next = await ref.read(legalRepositoryProvider).sections(
            state.act,
            search: state.query,
            page: state.page + 1,
            limit: pageSize,
          );
      if (generation != _generation) return;

      state = state.copyWith(
        sections: [...state.sections, ...next.sections],
        page: next.page,
        pages: next.pages,
        total: next.total,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        loadingMore: false,
        failure: ErrorMapper.map(error, context: 'api/sections'),
      );
    }
  }

  /// Re-runs the current act and query from page one.
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    if (state.act.isEmpty) return;

    final generation = ++_generation;
    state = state.copyWith(
      sections: const [],
      page: 0,
      loading: true,
      loadingMore: false,
      clearFailure: true,
    );

    try {
      final first = await ref.read(legalRepositoryProvider).sections(
            state.act,
            search: state.query,
            limit: pageSize,
          );
      if (generation != _generation) return;

      state = state.copyWith(
        sections: first.sections,
        page: first.page,
        pages: first.pages,
        total: first.total,
        loading: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        loading: false,
        failure: ErrorMapper.map(error, context: 'api/sections'),
      );
    }
  }
}

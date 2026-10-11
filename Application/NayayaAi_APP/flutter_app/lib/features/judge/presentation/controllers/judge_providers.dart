import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../legal/domain/entities/legal_section.dart';
import '../../../legal/presentation/controllers/legal_providers.dart';
import '../../data/datasources/judge_bookmark_store.dart';
import '../../data/datasources/judge_remote_data_source.dart';
import '../../data/models/judge_models.dart';
import '../../data/repositories/judge_repository_impl.dart';
import '../../domain/entities/judge_content.dart';
import '../../domain/repositories/judge_repository.dart';

final judgeRepositoryProvider = Provider<JudgeRepository>(
  (ref) => JudgeRepositoryImpl(
    remote: JudgeRemoteDataSource(ref.watch(dioClientProvider).dio),
  ),
);

final judgeBookmarkStoreProvider = Provider<JudgeBookmarkStore>(
  (ref) => JudgeBookmarkStore(ref.watch(secureStorageProvider)),
);

// ---- sections ----------------------------------------------------------------

/// The page's sidebar (judge_dashboard.html:68-88), in its order. The fifth
/// entry, "Orders & Drafts", has no section behind it on the website — no
/// `id`, no listener, no page (JD:85-87) — so it is an entry in the drawer and
/// not a value here.
enum JudgeSection {
  home('Home', Icons.dashboard_outlined),
  docket('Case Docket', Icons.folder_open_outlined),
  workspace('Case Workspace', Icons.work_outline_rounded),
  library('Law Library', Icons.gavel_rounded);

  const JudgeSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The page opens on Home (`showPage("home")`, JD:1192).
final judgeSectionProvider =
    StateProvider.autoDispose<JudgeSection>((ref) => JudgeSection.home);

/// Whether the Law Library has been opened yet. The page fetches the acts the
/// first time it is shown, not on load (JD:478-481).
final judgeLibraryOpenedProvider =
    StateProvider.autoDispose<bool>((ref) => false);

/// `showPage(page)` (JD:468-482), plus what each sidebar link does on top of
/// it: Case Workspace reloads its list every time it is entered (JD:486).
void showJudgeSection(WidgetRef ref, JudgeSection section) {
  if (section == JudgeSection.workspace) {
    ref.invalidate(judgeWorkspaceProvider);
  }
  if (section == JudgeSection.library) {
    ref.read(judgeLibraryOpenedProvider.notifier).state = true;
  }
  ref.read(judgeSectionProvider.notifier).state = section;
}

// ---- the docket --------------------------------------------------------------

/// The Docket page's two selects. Home's numbers follow them too, because the
/// page computes both from the same `loadDocket` reply (JD:589-593; analysis
/// OQ-J4).
typedef DocketFilter = ({String status, String urgency});

final docketFilterProvider = StateProvider.autoDispose<DocketFilter>(
  (ref) => (status: '', urgency: ''),
);

/// `loadDocket()` — the list behind the Docket table, the Home stats and the
/// Home upcoming hearings.
final judgeDocketProvider =
    FutureProvider.autoDispose<List<DocketEntry>>((ref) {
  final filter = ref.watch(docketFilterProvider);
  return ref
      .watch(judgeRepositoryProvider)
      .docket(status: filter.status, urgency: filter.urgency);
});

/// The Case Workspace's list: the whole docket, unfiltered (JD:771).
final judgeWorkspaceProvider =
    FutureProvider.autoDispose<List<WorkspaceCase>>((ref) async {
  final entries = await ref.watch(judgeRepositoryProvider).docket();
  return WorkspaceCase.group(entries);
});

/// The case whose detail panel is open in the workspace, if any.
final workspaceSelectionProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// The FIR behind one workspace case.
final judgeFirProvider = FutureProvider.autoDispose.family<JudgeFir, String>(
  (ref, caseId) => ref.watch(judgeRepositoryProvider).fir(caseId),
);

/// Every FIR, for the hearing modal's suggestions — fetched once when the page
/// loads (`loadFirOptions()`, JD:1191).
final judgeFirOptionsProvider = FutureProvider.autoDispose<List<JudgeFir>>(
  (ref) => ref.watch(judgeRepositoryProvider).firOptions(),
);

/// Home's "Add a Hearing" opens the docket and then its modal (JD:162).
/// Bumped to ask the docket to open the form.
final newHearingRequestProvider = StateProvider.autoDispose<int>((ref) => 0);

/// After a successful save or delete: `loadDocket()` again.
void refreshDocket(WidgetRef ref) => ref.invalidate(judgeDocketProvider);

// ---- law library: browsing --------------------------------------------------

class JudgeSectionsState {
  const JudgeSectionsState({
    this.act,
    this.page = 1,
    this.search = '',
    this.result,
  });

  /// `currentAct` — null until one is tapped.
  final String? act;
  final int page;
  final String search;

  /// Null before an act is chosen.
  final AsyncValue<LegalSectionPage>? result;

  JudgeSectionsState copyWith({
    String? act,
    int? page,
    String? search,
    AsyncValue<LegalSectionPage>? result,
  }) =>
      JudgeSectionsState(
        act: act ?? this.act,
        page: page ?? this.page,
        search: search ?? this.search,
        result: result ?? this.result,
      );
}

/// `selectAct`, the debounced search box and `goToPage` (JD:908-974), over
/// the same `GET /api/sections/<act>` the police library reads.
class JudgeSectionsController extends AutoDisposeNotifier<JudgeSectionsState> {
  Timer? _debounce;
  int _request = 0;

  @override
  JudgeSectionsState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const JudgeSectionsState();
  }

  /// Picking an act clears the search and starts at page one.
  void selectAct(String act) {
    _debounce?.cancel();
    state = JudgeSectionsState(act: act);
    _load();
  }

  /// Typing waits 350 ms, then goes back to page one — and searches only when
  /// an act is chosen, whatever the placeholder says (JD:918-925).
  void setSearch(String text) {
    _debounce?.cancel();
    final search = text.trim();
    _debounce = Timer(JudgeContent.searchDebounce, () {
      state = state.copyWith(search: search, page: 1);
      if (state.act != null) _load();
    });
  }

  void goToPage(int page) {
    state = state.copyWith(page: page);
    _load();
  }

  void retry() {
    if (state.act != null) _load();
  }

  Future<void> _load() async {
    final act = state.act;
    if (act == null) return;
    final request = ++_request;
    state = state.copyWith(result: const AsyncLoading());
    try {
      final page = await ref.read(legalRepositoryProvider).sections(
            act,
            search: state.search,
            page: state.page,
            limit: JudgeContent.sectionsPerPage,
          );
      if (request != _request) return;
      state = state.copyWith(result: AsyncData(page));
    } catch (e, st) {
      if (request != _request) return;
      state = state.copyWith(result: AsyncError(ErrorMapper.map(e), st));
    }
  }
}

final judgeSectionsProvider =
    AutoDisposeNotifierProvider<JudgeSectionsController, JudgeSectionsState>(
  JudgeSectionsController.new,
);

// ---- law library: bookmarks -------------------------------------------------

class JudgeBookmarksController
    extends AutoDisposeAsyncNotifier<List<JudgeBookmark>> {
  @override
  Future<List<JudgeBookmark>> build() =>
      ref.watch(judgeBookmarkStoreProvider).read();

  bool isBookmarked(String act, String section) =>
      (state.valueOrNull ?? const []).any((b) => b.same(act, section));

  /// `toggleBookmarkFromModal()` (JD:1008-1020): remove it if present, else
  /// add it at the end.
  Future<void> toggle(LegalSection s) async {
    final current = await future;
    final exists = current.any((b) => b.same(s.act, s.section));
    final next = exists
        ? [
            for (final b in current)
              if (!b.same(s.act, s.section)) b,
          ]
        : [
            ...current,
            JudgeBookmark(act: s.act, section: s.section, title: s.title),
          ];
    state = AsyncData(await ref.read(judgeBookmarkStoreProvider).write(next));
  }

  /// `removeBookmark(b)` (JD:1043-1047).
  Future<void> remove(JudgeBookmark bookmark) async {
    final current = await future;
    final next = [
      for (final b in current)
        if (!b.same(bookmark.act, bookmark.section)) b,
    ];
    state = AsyncData(await ref.read(judgeBookmarkStoreProvider).write(next));
  }
}

final judgeBookmarksProvider = AutoDisposeAsyncNotifierProvider<
    JudgeBookmarksController, List<JudgeBookmark>>(
  JudgeBookmarksController.new,
);

// ---- law library: precedent research -----------------------------------------

/// The research tab's one answer. There is no history: each answer replaces
/// the last (JD:1160-1188). Null before the first search.
class JudgeResearchController
    extends AutoDisposeNotifier<AsyncValue<PrecedentResearch>?> {
  @override
  AsyncValue<PrecedentResearch>? build() => null;

  bool get busy => state?.isLoading ?? false;

  Future<void> run(String query) async {
    final q = query.trim();
    if (q.isEmpty || busy) return;
    state = const AsyncLoading();
    try {
      final result = await ref.read(judgeRepositoryProvider).research(q);
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(ErrorMapper.map(e), st);
    }
  }
}

final judgeResearchProvider = AutoDisposeNotifierProvider<
    JudgeResearchController, AsyncValue<PrecedentResearch>?>(
  JudgeResearchController.new,
);

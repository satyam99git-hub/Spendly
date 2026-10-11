import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';
import '../../../legal/domain/entities/legal_section.dart';
import '../../../legal/presentation/controllers/legal_providers.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import '../widgets/judge_widgets.dart';
import 'research_tab.dart';

/// Law Library — judge_dashboard.html `<section id="library-page">`
/// (JD:294-359, 843-1188): Browse Acts, Precedent Research, Bookmarks.
///
/// Nothing is fetched until the library is first opened, as on the page
/// (JD:478-481).
class JudgeLibraryScreen extends ConsumerWidget {
  const JudgeLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(judgeLibraryOpenedProvider)) return const SizedBox.shrink();

    return const DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.md,
            ),
            child: LawyerHeading(JudgeContent.libraryHeading),
          ),
          // All three tabs stay on screen, as on the page; a label wraps to a
          // second line rather than pushing a tab out of reach.
          TabBar(
            tabs: [
              _LibraryTab(JudgeContent.tabBrowse),
              _LibraryTab(JudgeContent.tabResearch),
              _LibraryTab(JudgeContent.tabBookmarks),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_BrowseTab(), ResearchTab(), _BookmarksTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Tab(
        height: 56,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

/// Opens `/open-bare-act/<code>` outside the app, as the page opens it in a
/// new tab (JD:904-906).
Future<void> openBareAct(BuildContext context, String code) async {
  final uri =
      Uri.parse('${AppConfig.baseUrl}${ApiEndpoints.openBareAct(code)}');
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not open the $code bare act.')),
  );
}

// ---- Browse Acts --------------------------------------------------------------

class _BrowseTab extends ConsumerStatefulWidget {
  const _BrowseTab();

  @override
  ConsumerState<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends ConsumerState<_BrowseTab>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();

  /// The act list folds away once an act is chosen, so its sections are on
  /// screen without scrolling past eight cards — the page shows them side by
  /// side, which a phone cannot.
  bool _actsOpen = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(String act) {
    _search.clear();
    setState(() => _actsOpen = false);
    ref.read(judgeSectionsProvider.notifier).selectAct(act);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final acts = ref.watch(legalActsProvider);
    final state = ref.watch(judgeSectionsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        if (state.act != null && !_actsOpen)
          LawyerCard(
            onTap: () => setState(() => _actsOpen = true),
            child: Row(
              children: [
                Expanded(child: _ActSummary(code: state.act!, selected: true)),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          )
        else
          acts.when(
            loading: () => const LawyerLoading(),
            error: (e, _) => JudgeErrorView(
              error: e,
              onRetry: () => ref.invalidate(legalActsProvider),
            ),
            data: (list) => Column(
              children: [
                for (final code in list) ...[
                  LawyerCard(
                    key: Key('judge-act-$code'),
                    onTap: () => _select(code),
                    child: _ActSummary(
                      code: code,
                      selected: code == state.act,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          key: const Key('judge-section-search'),
          controller: _search,
          decoration: const InputDecoration(
            hintText: JudgeContent.sectionSearchHint,
            hintMaxLines: 3,
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: ref.read(judgeSectionsProvider.notifier).setSearch,
        ),
        const SizedBox(height: AppSpacing.lg),
        LawyerCard(padding: EdgeInsets.zero, child: _SectionList(state: state)),
        _Pagination(state: state),
      ],
    );
  }
}

/// One act in the list (JD:881-902).
class _ActSummary extends StatelessWidget {
  const _ActSummary({required this.code, required this.selected});

  final String code;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final repealedBy = JudgeContent.repealedBy[code];
    Widget link(String text, Color color, String target) => InkWell(
          onTap: () => openBareAct(context, target),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          code,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? LawyerColors.blue600 : LawyerColors.blue900,
          ),
        ),
        Text(
          JudgeContent.actLabels[code] ?? '',
          style: const TextStyle(fontSize: 12, color: LawyerColors.slate400),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: repealedBy != null
                ? const Color(0xFFFFEDD5)
                : LawyerColors.green100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            repealedBy != null ? 'Repealed — see $repealedBy' : 'Current law',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: repealedBy != null
                  ? const Color(0xFFC2410C)
                  : LawyerColors.green700,
            ),
          ),
        ),
        link(JudgeContent.openBareAct, const Color(0xFF3B82F6), code),
        if (repealedBy != null)
          link(
            JudgeContent.openCurrentLaw(repealedBy),
            LawyerColors.purple600,
            repealedBy,
          ),
      ],
    );
  }
}

/// `loadSections()` (JD:927-959).
class _SectionList extends ConsumerWidget {
  const _SectionList({required this.state});

  final JudgeSectionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result;
    if (state.act == null || result == null) {
      return const LawyerEmptyText(JudgeContent.selectAnAct);
    }
    final bookmarks = ref.watch(judgeBookmarksProvider).valueOrNull ?? const [];
    return result.when(
      loading: () => const LawyerEmptyText('Loading…'),
      error: (e, _) => JudgeErrorView(
        error: e,
        onRetry: ref.read(judgeSectionsProvider.notifier).retry,
      ),
      data: (page) {
        if (page.sections.isEmpty) {
          return const LawyerEmptyText(JudgeContent.noSections);
        }
        return Column(
          children: [
            for (var i = 0; i < page.sections.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _SectionRow(
                section: _withAct(page.sections[i], state.act!),
                starred: bookmarks.any(
                  (b) => b.same(state.act!, page.sections[i].section),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// `{ act: currentAct, ...s }` (JD:948).
  static LegalSection _withAct(LegalSection s, String act) => LegalSection(
        act: act,
        section: s.section,
        title: s.title,
        description: s.description,
      );
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.starred});

  final LegalSection section;
  final bool starred;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showSectionDetail(context, section),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Section ${section.section}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: LawyerColors.blue700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: LawyerColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
            if (starred)
              const Text(
                '★',
                style: TextStyle(fontSize: 18, color: Color(0xFFEAB308)),
              ),
          ],
        ),
      ),
    );
  }
}

/// `renderSectionsPagination` (JD:961-969): hidden for one page.
class _Pagination extends ConsumerWidget {
  const _Pagination({required this.state});

  final JudgeSectionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = state.result?.valueOrNull;
    if (page == null || page.sections.isEmpty || page.pages <= 1) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(judgeSectionsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          if (page.page > 1)
            OutlinedButton(
              onPressed: () => controller.goToPage(page.page - 1),
              child: const Text('Prev'),
            ),
          Text(
            'Page ${page.page} of ${page.pages}',
            style: const TextStyle(color: LawyerColors.slate500),
          ),
          if (page.page < page.pages)
            OutlinedButton(
              onPressed: () => controller.goToPage(page.page + 1),
              child: const Text('Next'),
            ),
        ],
      ),
    );
  }
}

// ---- the section modal --------------------------------------------------------

/// `viewSectionDetail(s)` (JD:976-984), with the bookmark toggle.
Future<void> showSectionDetail(BuildContext context, LegalSection section) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SectionDetailSheet(section: section),
  );
}

class _SectionDetailSheet extends ConsumerWidget {
  const _SectionDetailSheet({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(judgeBookmarksProvider);
    final marked = (bookmarks.valueOrNull ?? const [])
        .any((b) => b.same(section.act, section.section));
    final description = section.description.trim();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            '${section.act} § ${section.section} — ${section.title}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: LawyerColors.blue900,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SelectableText(
            description.isEmpty
                ? JudgeContent.noDescription
                : section.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: LawyerColors.slate600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            key: const Key('judge-bookmark-toggle'),
            onPressed: bookmarks.isLoading
                ? null
                : () =>
                    ref.read(judgeBookmarksProvider.notifier).toggle(section),
            child: Text(marked ? '★ Bookmarked' : '☆ Bookmark'),
          ),
        ],
      ),
    );
  }
}

// ---- Bookmarks ----------------------------------------------------------------

/// `renderBookmarks()` (JD:1021-1037).
class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(judgeBookmarksProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        LawyerCard(
          padding: EdgeInsets.zero,
          child: bookmarks.when(
            loading: () => const LawyerLoading(),
            error: (e, _) => JudgeErrorView(
              error: e,
              onRetry: () => ref.invalidate(judgeBookmarksProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const LawyerEmptyText(JudgeContent.noBookmarks);
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _open(
                                context,
                                ref,
                                list[i].act,
                                list[i].section,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${list[i].act} § ${list[i].section}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: LawyerColors.blue700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      list[i].title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: LawyerColors.slate600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          LawyerTextAction(
                            'Remove',
                            color: LawyerColors.red600,
                            onTap: () => ref
                                .read(judgeBookmarksProvider.notifier)
                                .remove(list[i]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// `openBookmark(b)` (JD:1038-1042): the section in full, then the modal.
  /// The page renders "§ undefined" when that lookup fails; the app says why.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String act,
    String section,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final detail =
          await ref.read(legalRepositoryProvider).section(act, section);
      if (!context.mounted) return;
      await showSectionDetail(
        context,
        LegalSection(
          act: act,
          section: detail.section,
          title: detail.title,
          description: detail.description,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(judgeMessageOf(e))));
    }
  }
}

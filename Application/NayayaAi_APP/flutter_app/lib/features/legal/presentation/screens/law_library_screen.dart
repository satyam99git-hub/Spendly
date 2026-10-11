import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/feedback/state_message.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../controllers/law_library_controller.dart';
import '../controllers/legal_providers.dart';
import '../widgets/legal_keys.dart';
import '../widgets/legal_section_tile.dart';

/// Every section of all eight acts, browsable and searchable.
///
/// ---------------------------------------------------------------------------
/// WHY AN ACT PICKER AND A SEARCH BOX, RATHER THAN ONE SEARCH
///
/// The server has two search endpoints and they answer two different questions.
/// `/api/search-sections?q=` looks across all eight acts and returns numbers and
/// titles with no text; `/api/sections/<act>?search=` searches inside one act
/// and returns the text too, paginated.
///
/// An officer uses both, at different moments. "What covers cheating?" is the
/// first — a wide net, and the titles are enough to pick from. "What exactly
/// does 379 say?" is the second, and needs the words. Collapsing them into one
/// box would mean either losing the text or searching thousands of rows across
/// eight tables to find one number the officer already knew.
///
/// So the act chips choose which question is being asked: one selected means
/// searching inside it, "All acts" means the wide net.
/// ---------------------------------------------------------------------------
class LawLibraryScreen extends ConsumerStatefulWidget {
  const LawLibraryScreen({super.key});

  @override
  ConsumerState<LawLibraryScreen> createState() => _LawLibraryScreenState();
}

class _LawLibraryScreenState extends ConsumerState<LawLibraryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  /// Null means "all acts" — the cross-act search. Held here rather than in the
  /// controller because the controller only ever browses one act; the wide
  /// search is a different provider entirely.
  String? _act;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  /// Asks for the next page a screen's-worth before the end of the list, so the
  /// spinner is usually gone by the time the officer scrolls to where it was.
  void _onScroll() {
    if (_act == null) return;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 600) return;
    ref.read(lawLibraryControllerProvider.notifier).loadMore();
  }

  void _selectAct(String? act) {
    setState(() => _act = act);
    if (act != null) {
      ref.read(lawLibraryControllerProvider.notifier)
        ..openAct(act)
        ..search(_search.text);
    }
  }

  void _openSection(String act, String section) {
    context.pushNamed(
      AppRoutes.lawSectionName,
      pathParameters: {'act': act, 'section': section},
    );
  }

  @override
  Widget build(BuildContext context) {
    final acts = ref.watch(legalActsProvider);
    final scheme = Theme.of(context).colorScheme;

    // Keeps the library controller alive for as long as this screen is.
    //
    // It is `autoDispose`, and until an act is chosen nothing watches it — the
    // body is showing the cross-act search, which is a different provider. So
    // `_selectAct`'s `ref.read(...).openAct(...)` would create the controller,
    // set the act, start the fetch, and have the whole thing disposed before
    // `_ActSections` was built to watch it: tapping an act showed an empty
    // list, every time.
    //
    // Watching one field rather than the whole state, so paging does not
    // rebuild the search box and the chips underneath the officer's thumb.
    ref.watch(lawLibraryControllerProvider.select((s) => s.act));

    return Scaffold(
      key: LegalKeys.library,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Law library'),
        backgroundColor: scheme.surface,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              0,
              AppSpacing.xxl,
              AppSpacing.sm,
            ),
            child: AppTextField(
              key: LegalKeys.librarySearch,
              label: 'Search',
              controller: _search,
              hintText: _act == null
                  ? 'A word, or a section number, across all eight acts'
                  : 'A word, a title or a number within $_act',
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                if (_act == null) {
                  // The wide search re-runs from the provider below; a rebuild
                  // is all it needs.
                  setState(() {});
                } else {
                  ref.read(lawLibraryControllerProvider.notifier).search(value);
                }
              },
            ),
          ),
          acts.when(
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox(height: 44),
            data: (list) => _ActChips(
              acts: list,
              selected: _act,
              onSelected: _selectAct,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: acts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => StateMessage(
                icon: Icons.cloud_off_rounded,
                title: 'The acts could not be loaded',
                body: '$error',
                centred: true,
              ),
              data: (_) => _act == null
                  ? _WideSearchResults(
                      query: _search.text,
                      onOpen: _openSection,
                    )
                  : _ActSections(scroll: _scroll, onOpen: _openSection),
            ),
          ),
        ],
      ),
    );
  }
}

/// "All acts" and the eight, as a scrolling row.
class _ActChips extends StatelessWidget {
  const _ActChips({
    required this.acts,
    required this.selected,
    required this.onSelected,
  });

  final List<String> acts;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: LegalKeys.actChips,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          _Chip(
            key: LegalKeys.actChip('all'),
            label: 'All acts',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final act in acts)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _Chip(
                key: LegalKeys.actChip(act),
                label: act,
                selected: selected == act,
                onTap: () => onSelected(act),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour =
        selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.65);

    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: selected ? 0.14 : 0.04),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(
              color: colour.withValues(alpha: selected ? 0.55 : 0.25),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.error.copyWith(
              color: colour,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// One act's sections, paged.
class _ActSections extends ConsumerWidget {
  const _ActSections({required this.scroll, required this.onOpen});

  final ScrollController scroll;
  final void Function(String act, String section) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lawLibraryControllerProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final failure = state.failure;
    if (failure != null && state.sections.isEmpty) {
      return StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'That could not be loaded',
        body: failure.message,
        centred: true,
      );
    }

    if (state.isEmpty) {
      return StateMessage(
        icon: Icons.search_off_rounded,
        title: 'Nothing in ${state.act} matches',
        body: state.query.isEmpty
            ? 'This act has no sections in the station database.'
            : 'No section of ${state.act} mentions “${state.query}”. '
                'Try “All acts”.',
        centred: true,
      );
    }

    return ListView.separated(
      controller: scroll,
      itemCount: state.sections.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 24),
      itemBuilder: (context, index) {
        if (index == state.sections.length) {
          return _Footer(
            key: LegalKeys.loadMore,
            loading: state.loadingMore,
            shown: state.sections.length,
            total: state.total,
            hasMore: state.hasMore,
            failure: state.failure?.message,
            onRetry: () =>
                ref.read(lawLibraryControllerProvider.notifier).loadMore(),
          );
        }

        final section = state.sections[index];
        return LegalSectionTile(
          section: section,
          onTap: () => onOpen(section.act, section.section),
        );
      },
    );
  }
}

/// The end of the list: how much of it is on screen, and whatever is happening
/// about the rest.
///
/// States what is loaded rather than only spinning, because "40 of 575" is the
/// difference between an officer scrolling on and one who assumes the act ends
/// at Section 40.
class _Footer extends StatelessWidget {
  const _Footer({
    super.key,
    required this.loading,
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.failure,
    required this.onRetry,
  });

  final bool loading;
  final int shown;
  final int total;
  final bool hasMore;
  final String? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    final message = failure;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: Column(
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (message != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('$message Tap to try again.'),
              )
            else
              Text(
                hasMore
                    ? 'Showing $shown of $total. Keep scrolling for more.'
                    : 'All $total shown.',
                textAlign: TextAlign.center,
                style: AppTypography.error.copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// The cross-act search: `/api/search-sections?q=`.
///
/// A different endpoint from the one behind [_ActSections], with a different
/// shape and no pagination, so it gets its own widget rather than a flag on
/// that one.
class _WideSearchResults extends ConsumerWidget {
  const _WideSearchResults({required this.query, required this.onOpen});

  final String query;
  final void Function(String act, String section) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) {
      return const StateMessage(
        icon: Icons.menu_book_outlined,
        title: 'Search every act at once',
        body: 'Type what you are looking for — “theft”, “cheating”, “420” — or '
            'pick an act above to read it section by section.',
        centred: true,
      );
    }

    final results = ref.watch(legalSearchProvider(query.trim()));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'That search could not be run',
        body: '$error',
        centred: true,
      ),
      data: (sections) {
        if (sections.isEmpty) {
          return StateMessage(
            icon: Icons.search_off_rounded,
            title: 'Nothing matches “${query.trim()}”',
            body: 'The search reads section numbers and titles across all '
                'eight acts.',
            centred: true,
          );
        }

        return ListView.separated(
          itemCount: sections.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 24),
          itemBuilder: (context, index) {
            final section = sections[index];
            return LegalSectionTile(
              section: section,
              showAct: true,
              onTap: () => onOpen(section.act, section.section),
            );
          },
        );
      },
    );
  }
}

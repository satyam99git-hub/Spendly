import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/fir_number.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/evidence_category.dart';
import '../../domain/entities/evidence_item.dart';
import '../controllers/evidence_providers.dart';
import 'evidence_keys.dart';
import 'evidence_tile.dart';

/// The locker, once it is open.
///
/// Grouped by FIR, because that is the unit an officer works in: evidence is
/// never "a file", it is "what we have on FIR 41/2026". A flat chronological
/// list would be shorter to build and would put two files from the same case
/// twenty rows apart.
///
/// The search box filters across both the FIR number and the filename, and the
/// chips under it narrow to one kind of file — the same two filters the
/// website's console has, and applied the same way: on the list already in
/// memory. No server-side search exists — `/get-all-evidence`
/// takes no query — and adding a debounce and a spinner for a client-side
/// `contains` would be pure ceremony.
class EvidenceListView extends ConsumerStatefulWidget {
  const EvidenceListView({super.key});

  @override
  ConsumerState<EvidenceListView> createState() => _EvidenceListViewState();
}

class _EvidenceListViewState extends ConsumerState<EvidenceListView> {
  final _search = TextEditingController();
  String _query = '';

  /// Null means every kind. The website's console has the same filter as a
  /// dropdown labelled All / Image / Video / Audio / PDF; on a handset it is a
  /// row of chips, because a dropdown costs two taps and a dismissal to change
  /// a filter an officer flips between while scanning a locker.
  EvidenceCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final evidence = ref.watch(allEvidenceProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            0,
          ),
          child: AppTextField(
            key: EvidenceKeys.search,
            label: 'Search',
            controller: _search,
            hintText: 'FIR number or file name',
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        _CategoryChips(
          selected: _category,
          onSelected: (category) => setState(() => _category = category),
        ),
        Expanded(
          child: RefreshIndicator(
            // The only way to see a colleague's upload. Nothing polls — see
            // allEvidenceProvider.
            onRefresh: () async {
              ref.invalidate(allEvidenceProvider);
              await ref.read(allEvidenceProvider.future);
            },
            child: evidence.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Message(
                icon: Icons.cloud_off_rounded,
                title: 'The locker could not be loaded',
                body: error is Failure
                    ? error.message
                    : 'Something went wrong. Pull down to try again.',
              ),
              data: (items) => _buildList(items),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<EvidenceItem> all) {
    final items = _filter(all);

    if (items.isEmpty) {
      // Scrollable even when empty, or RefreshIndicator has nothing to pull.
      return ListView(
        key: EvidenceKeys.list,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _Message(
            icon: all.isEmpty
                ? Icons.folder_open_outlined
                : Icons.search_off_rounded,
            title: all.isEmpty
                ? 'The locker is empty'
                : 'Nothing matches “$_query”',
            body: all.isEmpty
                ? 'Files added against an FIR appear here.'
                : 'Try the FIR number on its own.',
          ),
        ],
      );
    }

    final groups = _groupByFir(items);

    return ListView.builder(
      key: EvidenceKeys.list,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        // Clear of the floating Add button, which otherwise sits on the last row.
        AppSpacing.xxxl * 2.5,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _FirGroup(
          firNo: group.firNo,
          items: group.items,
          onOpen: (item) => context.pushNamed(
            AppRoutes.evidenceDetailName,
            pathParameters: {
              'firNo': item.firNo,
              'filename': item.filename,
            },
          ),
        );
      },
    );
  }

  List<EvidenceItem> _filter(List<EvidenceItem> items) {
    final q = _query.toLowerCase();
    final category = _category;

    return items
        .where((item) => category == null || item.category == category)
        .where(
          (item) =>
              q.isEmpty ||
              item.firNo.toLowerCase().contains(q) ||
              item.filename.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Groups preserving first-seen order, then sorts groups by FIR number
  /// descending — newest-looking numbers first, which is the closest thing to
  /// "most recent" available from a payload with no timestamps in it.
  List<({String firNo, List<EvidenceItem> items})> _groupByFir(
    List<EvidenceItem> items,
  ) {
    final byFir = <String, List<EvidenceItem>>{};
    for (final item in items) {
      byFir.putIfAbsent(item.firNo, () => []).add(item);
    }

    final keys = byFir.keys.toList()
      ..sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));

    return [
      for (final key in keys) (firNo: key, items: byFir[key]!),
    ];
  }
}

/// One FIR's files, under its number.
class _FirGroup extends StatelessWidget {
  const _FirGroup({
    required this.firNo,
    required this.items,
    required this.onOpen,
  });

  final String firNo;
  final List<EvidenceItem> items;
  final ValueChanged<EvidenceItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    FirNumber.label(firNo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Text(
                  items.length == 1 ? '1 file' : '${items.length} files',
                  style: AppTypography.error.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: AppSpacing.md + AppSizes.iconChip + AppSpacing.lg,
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  EvidenceTile(
                    item: items[i],
                    onTap: () => onOpen(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty, error and no-match states, which are the same shape and should look it.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl * 1.5,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: muted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

/// Every kind of file in the locker, as a row of chips.
///
/// The categories are the server's, derived from the extension — see
/// [EvidenceCategory]. `Other` is offered like the rest: a locker full of
/// `.docx` statements is exactly the case where "everything the app could not
/// classify" is the thing an officer is looking for.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final EvidenceCategory? selected;
  final ValueChanged<EvidenceCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: EvidenceKeys.categoryChips,
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        children: [
          _Chip(
            key: EvidenceKeys.categoryChip('all'),
            label: 'All',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final category in EvidenceCategory.values)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _Chip(
                key: EvidenceKeys.categoryChip(category.name),
                label: category.label,
                selected: selected == category,
                // Tapping the selected chip clears back to All, so the row is a
                // toggle rather than something an officer has to find their way
                // out of.
                onTap: () =>
                    onSelected(selected == category ? null : category),
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

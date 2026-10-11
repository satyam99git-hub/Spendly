import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../data/models/lawyer_models.dart';
import '../controllers/lawyer_providers.dart';
import '../widgets/lawyer_widgets.dart';

/// Drafts — lawyer_dashboard.html `<section id="drafts">` (lines 518-543,
/// `loadGlobalDrafts` 1520-1566). Reloaded every time the section is shown
/// (`showLawyerSection`). There is no delete here, as on the page.
class AllDraftsScreen extends ConsumerStatefulWidget {
  const AllDraftsScreen({super.key});

  @override
  ConsumerState<AllDraftsScreen> createState() => _AllDraftsScreenState();
}

class _AllDraftsScreenState extends ConsumerState<AllDraftsScreen> {
  /// The "Draft Preview" card's content; null while it is hidden.
  String? _preview;

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(lawyerAllDraftsProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const LawyerHeading('All Drafts'),
        const SizedBox(height: AppSpacing.xl),
        LawyerCard(
          child: drafts.when(
            // `skipLoadingOnRefresh: false`: the page empties the list and
            // shows "Loading drafts…" on every visit.
            skipLoadingOnRefresh: false,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: LawyerBusyLine('Loading drafts…')),
            ),
            error: (_, __) => const LawyerEmptyText(
              'Something went wrong loading drafts.',
            ),
            data: (list) => list.isEmpty
                ? const LawyerEmptyText(
                    'No drafts saved yet. Open a case\'s workspace to '
                    'generate and save one.',
                  )
                : Column(
                    children: [
                      for (final d in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _DraftRow(
                            draft: d,
                            onView: () => setState(() => _preview = d.content),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (_preview != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          LawyerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Draft Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? LawyerColors.blue100
                              : LawyerColors.blue900,
                        ),
                      ),
                    ),
                    LawyerTextAction(
                      'CLOSE',
                      color: LawyerColors.slate400,
                      onTap: () => setState(() => _preview = null),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LawyerMarkdown(_preview!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DraftRow extends ConsumerWidget {
  const _DraftRow({required this.draft, required this.onView});

  final CaseDraft draft;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LawyerRow(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIR: ${draft.firNo}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: dark ? LawyerColors.blue100 : LawyerColors.blue900,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: draft.kindLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: '  ${draft.createdAt}',
                        style: const TextStyle(color: LawyerColors.slate400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LawyerTextAction('VIEW', onTap: onView),
          LawyerTextAction(
            'OPEN CASE',
            color: LawyerColors.slate500,
            onTap: () => openCaseWorkspace(ref, draft.firNo),
          ),
        ],
      ),
    );
  }
}

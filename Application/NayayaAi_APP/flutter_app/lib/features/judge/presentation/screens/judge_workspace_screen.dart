import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';
import '../../data/models/judge_models.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import '../widgets/judge_widgets.dart';

/// Case Workspace — judge_dashboard.html `<section id="workspace-page">`
/// (JD:252-290, 770-841).
///
/// The page shows the case cards with the detail panel beneath them; on a
/// phone the detail replaces the cards, with a back arrow standing in for the
/// panel's ×. It is read-only on the website and read-only here.
class JudgeWorkspaceScreen extends ConsumerWidget {
  const JudgeWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(judgeWorkspaceProvider);
    final selected = ref.watch(workspaceSelectionProvider);

    final list = cases.valueOrNull;
    if (selected != null && list != null) {
      final match = list.where((c) => c.caseId == selected);
      if (match.isNotEmpty) return _CaseDetail(item: match.first);
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(judgeWorkspaceProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const LawyerHeading(JudgeContent.workspaceHeading),
          const SizedBox(height: AppSpacing.xl),
          cases.when(
            loading: () => const LawyerLoading(),
            error: (e, _) => JudgeErrorView(
              error: e,
              onRetry: () => ref.invalidate(judgeWorkspaceProvider),
            ),
            data: (items) => items.isEmpty
                ? const LawyerEmptyText(JudgeContent.workspaceEmpty)
                : Column(
                    children: [
                      for (final item in items) ...[
                        _CaseCard(item: item),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One case card (JD:788-798).
class _CaseCard extends ConsumerWidget {
  const _CaseCard({required this.item});

  final WorkspaceCase item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LawyerCard(
      onTap: () {
        ref.invalidate(judgeFirProvider(item.caseId));
        ref.read(workspaceSelectionProvider.notifier).state = item.caseId;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.caseId,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: LawyerColors.blue700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${jsOrText(item.latest.raw['case_type'], 'General')} · '
            '${item.hearingCount}',
            style: const TextStyle(fontSize: 12, color: LawyerColors.slate400),
          ),
          const SizedBox(height: AppSpacing.sm),
          JudgePill(item.latest.status),
        ],
      ),
    );
  }
}

/// `openWorkspaceDetail(caseId)` (JD:803-837).
class _CaseDetail extends ConsumerWidget {
  const _CaseDetail({required this.item});

  final WorkspaceCase item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void close() => ref.read(workspaceSelectionProvider.notifier).state = null;

    // Back closes the detail — but only while the workspace is the section on
    // screen; the IndexedStack keeps this built behind the others.
    final visible = ref.watch(judgeSectionProvider) == JudgeSection.workspace;

    return PopScope(
      canPop: !visible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: close,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to cases',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.caseId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: LawyerColors.blue900,
                      ),
                    ),
                    Text(
                      item.detailType,
                      style: const TextStyle(
                        fontSize: 13,
                        color: LawyerColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const JudgeBlockHeading(JudgeContent.firDetailsHeading),
          const SizedBox(height: AppSpacing.md),
          LawyerCard(child: _FirDetails(caseId: item.caseId)),
          const SizedBox(height: AppSpacing.xxl),
          const JudgeBlockHeading(JudgeContent.timelineHeading),
          const SizedBox(height: AppSpacing.md),
          for (final e in item.timeline) _TimelineEntry(entry: e),
        ],
      ),
    );
  }
}

class _FirDetails extends ConsumerWidget {
  const _FirDetails({required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fir = ref.watch(judgeFirProvider(caseId));
    return fir.when(
      loading: () => const LawyerEmptyText('Loading…', center: false),
      // The page shows one sentence for every failure (JD:832-834). A failure
      // to reach the server at all is said as such, with a retry, rather than
      // as "no linked FIR".
      error: (e, _) => e is NetworkFailure
          ? JudgeErrorView(
              error: e,
              onRetry: () => ref.invalidate(judgeFirProvider(caseId)),
            )
          : const LawyerEmptyText(JudgeContent.noLinkedFir, center: false),
      data: (f) {
        Widget row(String label, String value) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text.rich(
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: LawyerColors.slate400,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Complainant', f.field('complainant_name')),
            row('District', f.field('dist')),
            row('Police Station', f.field('ps')),
            row('Act/Sections', f.field('act_sections')),
            row('Status', f.field('status')),
          ],
        );
      },
    );
  }
}

/// One timeline row (JD:811-817).
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry});

  final DocketEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFBFDBFE), width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.hearingDate,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          JudgePill(entry.status),
          const SizedBox(height: AppSpacing.sm),
          Text(
            jsOrText(entry.raw['remarks'], JudgeContent.noRemarks),
            style: const TextStyle(fontSize: 14, color: LawyerColors.slate600),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../lawyer/presentation/widgets/lawyer_widgets.dart';
import '../../data/models/judge_models.dart';
import '../../domain/entities/judge_content.dart';
import '../controllers/judge_providers.dart';
import '../widgets/judge_widgets.dart';
import 'hearing_form_sheet.dart';

/// Case Docket — judge_dashboard.html `<section id="docket-page">`
/// (JD:196-248, 582-767).
///
/// The page's seven-column table becomes one card per entry on a phone, with
/// the same fields in the same order and the same Edit / Delete actions.
class DocketScreen extends ConsumerWidget {
  const DocketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Home's "Add a Hearing" (JD:162).
    ref.listen<int>(newHearingRequestProvider, (previous, next) {
      if (next > (previous ?? 0)) openHearingForm(context, ref);
    });

    final docket = ref.watch(judgeDocketProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(judgeDocketProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Row(
            children: [
              const Expanded(child: LawyerHeading(JudgeContent.docketHeading)),
              FilledButton(
                onPressed: () => openHearingForm(context, ref),
                child: const Text(JudgeContent.newHearing),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const _Filters(),
          const SizedBox(height: AppSpacing.xl),
          docket.when(
            loading: () => const LawyerLoading(),
            error: (e, _) => JudgeErrorView(
              error: e,
              onRetry: () => refreshDocket(ref),
            ),
            data: (entries) => entries.isEmpty
                ? const LawyerEmptyText(JudgeContent.docketEmpty)
                : Column(
                    children: [
                      for (final e in entries) ...[
                        _DocketCard(entry: e),
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

/// `#statusFilter`, `#urgencyFilter` and Refresh (JD:208-227). A change
/// reloads at once, as the page's `change` listeners do.
class _Filters extends ConsumerWidget {
  const _Filters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(docketFilterProvider);

    Widget select(
      String key,
      String value,
      List<(String, String)> options,
      void Function(String) onChanged,
    ) =>
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            key: Key(key),
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final (label, wire) in options)
                DropdownMenuItem(value: wire, child: Text(label)),
            ],
            onChanged: (v) => onChanged(v ?? ''),
          ),
        );

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        select(
          'judge-status-filter',
          filter.status,
          JudgeContent.statusFilters,
          (v) => ref.read(docketFilterProvider.notifier).state =
              (status: v, urgency: filter.urgency),
        ),
        select(
          'judge-urgency-filter',
          filter.urgency,
          JudgeContent.urgencyFilters,
          (v) => ref.read(docketFilterProvider.notifier).state =
              (status: filter.status, urgency: v),
        ),
        OutlinedButton(
          onPressed: () => refreshDocket(ref),
          child: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _DocketCard extends ConsumerWidget {
  const _DocketCard({required this.entry});

  final DocketEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: LawyerColors.slate400),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(color: scheme.onSurface),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 13),
          ),
        );

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.caseId,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: LawyerColors.blue700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [JudgePill(entry.urgency), JudgePill(entry.status)],
        ),
        line('Hearing Date', entry.hearingDate),
        line('Type', jsOrText(entry.raw['case_type'], '-')),
        line('Remarks', jsOrText(entry.raw['remarks'], '-')),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            LawyerTextAction(
              'Edit',
              onTap: () => _edit(context, ref),
            ),
            LawyerTextAction(
              'Delete',
              color: LawyerColors.red600,
              onTap: () => _delete(context, ref),
            ),
          ],
        ),
      ],
    );

    if (!entry.isUrgent) return LawyerCard(child: card);
    return Material(
      color: judgeUrgentTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFED7AA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFF0F172A)),
          child: card,
        ),
      ),
    );
  }

  /// `editEntry(id)` (JD:684-689): the whole docket again, unfiltered, and the
  /// entry with this id from it. The page silently does nothing when that
  /// fails; the app says so.
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final id = entry.id;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final all = await ref.read(judgeRepositoryProvider).docket();
      final match = all.where((e) => e.id == id);
      if (match.isEmpty || !context.mounted) return;
      await openHearingForm(context, ref, entry: match.first);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(judgeMessageOf(e))));
    }
  }

  /// `deleteEntry(id)` (JD:691-695): confirm, delete, reload.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final id = entry.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text(JudgeContent.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(judgeRepositoryProvider).deleteEntry(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(judgeMessageOf(e))));
    }
    refreshDocket(ref);
  }
}

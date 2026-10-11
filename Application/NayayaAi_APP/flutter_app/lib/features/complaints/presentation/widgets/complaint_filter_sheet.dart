import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/dashboard/presentation/widgets/dashboard_cards.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint_filter.dart';
import '../controllers/complaint_filter_controller.dart';
import 'complaint_keys.dart';
import 'sheet_scaffold.dart';

/// When a complaint arrived: five presets and a calendar.
///
/// ---------------------------------------------------------------------------
/// WHY THE DATE IS `created_at` AND NOT `incident_date`
///
/// Two reasons, and the second decides it.
///
/// The question this filter answers is a question about the inbox — "what came
/// in today", "what has been sitting here a fortnight" — which is about when the
/// complaint reached the station, not when the offence happened.
///
/// And `incident_date` cannot be filtered on at all. It is free text a citizen
/// typed into a form the API accepts anything for, so the column already holds
/// blanks and phrases as well as dates; a range over it would silently exclude
/// every complaint whose date was written in words. It is still shown on the
/// detail screen and still matched by the search box, where being a string is
/// not a problem.
/// ---------------------------------------------------------------------------
///
/// Applies as you tap rather than on a Done button. The list is behind the sheet
/// and the counts change under it, so the effect of a choice is visible while the
/// sheet is still open — a Done button would only add a step before the officer
/// could see whether they had chosen well. The button at the bottom closes the
/// sheet; it does not decide anything.
Future<void> showComplaintFilterSheet(BuildContext context) {
  return showComplaintSheet<void>(
    context,
    builder: (context) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(complaintFilterProvider);
    final controller = ref.read(complaintFilterProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return ComplaintSheetScaffold(
      sheetKey: ComplaintKeys.filterSheet,
      title: 'Narrow the inbox',
      subtitle:
          'Days are counted in UTC, the same as every time shown in the app.',
      children: [
            // What the server made of the narrative. First, because it is the
            // filter that changes what an officer does next — the date range
            // only changes how much of the same work is on screen.
            const SectionHeading('KIND OF OFFENCE'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Worked out from the narrative by the server, not chosen by the '
              'person who filed it. Treat it as a starting point.',
              style: AppTypography.error.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final choice in ComplaintCategoryFilter.values)
                  _CategoryChip(
                    key: ComplaintKeys.categoryChoice(choice.name),
                    label: choice.label,
                    selected: filter.category == choice,
                    onTap: () => controller.setCategory(choice),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeading('RECEIVED'),
            const SizedBox(height: AppSpacing.md),
            for (final preset in ComplaintDatePreset.values)
              if (preset == ComplaintDatePreset.custom)
                ComplaintChoiceTile(
                  key: ComplaintKeys.datePreset(preset.name),
                  title: filter.datePreset == preset
                      ? 'Custom range · ${filter.dateLabel}'
                      : preset.label,
                  subtitle: 'Pick two dates',
                  selected: filter.datePreset == preset,
                  onTap: () => _pickRange(context, ref, filter),
                )
              else
                ComplaintChoiceTile(
                  key: ComplaintKeys.datePreset(preset.name),
                  title: preset.label,
                  subtitle: _describe(preset),
                  selected: filter.datePreset == preset,
                  onTap: () => controller.setDatePreset(preset),
                ),
            const SizedBox(height: AppSpacing.sm),
            if (filter.isActive) ...[
              Text(
                '${filter.activeCount} filter'
                '${filter.activeCount == 1 ? '' : 's'} on, search included.',
                style: AppTypography.error.copyWith(color: muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                key: ComplaintKeys.clearFilters,
                label: 'Clear all filters',
                icon: Icons.filter_alt_off_outlined,
                onPressed: () {
                  controller.clear();
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        PrimaryButton(
          key: ComplaintKeys.filterApply,
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static String _describe(ComplaintDatePreset preset) {
    switch (preset) {
      case ComplaintDatePreset.anyTime:
        return 'Every complaint on record';
      case ComplaintDatePreset.today:
        return 'Since midnight UTC';
      case ComplaintDatePreset.yesterday:
        return 'The UTC day before this one';
      case ComplaintDatePreset.last7Days:
        return 'Today and the six days before it';
      case ComplaintDatePreset.last30Days:
        return 'Today and the twenty-nine days before it';
      case ComplaintDatePreset.custom:
        return 'Pick two dates';
    }
  }

  /// Opens the platform range picker, seeded with whatever is already chosen.
  ///
  /// The lower bound is 2020 rather than "the oldest complaint on record": the
  /// sheet does not know what that is, and a picker that refused a date because
  /// nothing was filed then would be arguing with the officer about an empty
  /// result they can see for themselves.
  ///
  /// The upper bound is today, because a complaint received tomorrow does not
  /// exist and offering to filter for one only produces an empty list.
  Future<void> _pickRange(
    BuildContext context,
    WidgetRef ref,
    ComplaintFilter filter,
  ) async {
    final now = ref.read(complaintClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final from = filter.customFrom;
    final to = filter.customTo;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      currentDate: today,
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
      helpText: 'Complaints received between',
    );

    if (picked == null) return;
    ref
        .read(complaintFilterProvider.notifier)
        .setCustomRange(picked.start, picked.end);
  }
}

/// One category choice, shaped like the stage chips on the filter bar.
///
/// Hand-built rather than a Material [FilterChip] for the same reason
/// `_StageChip` is: a checkmark that animates in shifts every chip to its right,
/// and in a wrap of eleven that moves the one the officer was aiming at.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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

    return InkWell(
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
    );
  }
}

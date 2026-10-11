import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint_filter.dart';
import '../controllers/complaint_filter_controller.dart';
import 'complaint_filter_sheet.dart';
import 'complaint_keys.dart';

/// The search box, the stage chips and the way into the date filter.
///
/// ---------------------------------------------------------------------------
/// WHY THE STAGES ARE CHIPS AND THE DATES ARE A SHEET
///
/// They are not used the same way. Switching between Active, Pending and All is
/// what triage *is* — an officer does it several times in a sitting, and putting
/// two taps and an animation in front of every switch would make the screen feel
/// like an argument. So the stages sit on the screen, always visible, which also
/// means a filter left on from yesterday cannot hide behind an icon and make an
/// inbox look empty.
///
/// A date range is chosen once and then worked within. It needs five options and
/// a calendar, which is more than fits above a list, and it is the rarer choice —
/// so it lives behind a button that shows a dot when it is doing something.
/// ---------------------------------------------------------------------------
class ComplaintFilterBar extends ConsumerWidget {
  const ComplaintFilterBar({super.key, required this.searchController});

  /// Owned by the screen rather than by this widget: the inbox rebuilds on every
  /// keystroke, and a controller created here would be recreated with it.
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(complaintFilterProvider);
    final controller = ref.read(complaintFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            0,
          ),
          child: AppTextField(
            key: ComplaintKeys.search,
            label: 'Search',
            controller: searchController,
            hintText: 'Name, phone, place, tracking ID or what happened',
            textInputAction: TextInputAction.search,
            onChanged: controller.setQuery,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: ComplaintKeys.stageChips,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: AppSpacing.xxl),
                child: Row(
                  children: [
                    for (final stage in ComplaintStage.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: _StageChip(
                          key: ComplaintKeys.stageChip(stage.name),
                          label: stage.label,
                          selected: filter.stage == stage,
                          onTap: () => controller.setStage(stage),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _DateFilterButton(filter: filter),
            const _ViewToggle(),
          ],
        ),
      ],
    );
  }
}

/// The way into [showComplaintFilterSheet], marked when a date filter is on.
///
/// The label carries the current choice rather than always reading "Filter": an
/// officer who cannot see that the inbox is showing only today is an officer who
/// will conclude the inbox is empty.
class _DateFilterButton extends ConsumerWidget {
  const _DateFilterButton({required this.filter});

  final ComplaintFilter filter;

  /// What the button says when the sheet behind it is doing something.
  ///
  /// The sheet holds two filters now — the kind of offence and the date range —
  /// and the button has room for one short label. It names whichever is on, and
  /// when both are it names the offence: the date range is a backdrop an officer
  /// sets once and works within, while the category is the choice they change
  /// while triaging and the one they need to see they have left on.
  String get _label {
    final byCategory = filter.category != ComplaintCategoryFilter.all;
    final byDate = filter.datePreset != ComplaintDatePreset.anyTime;

    if (byCategory) return filter.category.label;
    if (byDate) return filter.dateLabel;
    return 'Filters';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final on = filter.category != ComplaintCategoryFilter.all ||
        filter.datePreset != ComplaintDatePreset.anyTime;
    final colour = on ? scheme.primary : scheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: InkWell(
        key: ComplaintKeys.filterButton,
        onTap: () => showComplaintFilterSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: on ? 0.14 : 0.04),
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: Border.all(color: colour.withValues(alpha: on ? 0.55 : 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: colour),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _label,
                style: AppTypography.error.copyWith(
                  color: colour,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              // Both on, and only one fits. The dot says there is a second
              // filter behind the button without claiming the space to name it.
              if (filter.category != ComplaintCategoryFilter.all &&
                  filter.datePreset != ComplaintDatePreset.anyTime) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colour,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip that is a filter, not a Material [FilterChip].
///
/// Hand-built for one reason: [FilterChip] draws a checkmark when selected and
/// animates its label sideways to make room for it, so a row of them shifts
/// horizontally every time the officer changes their mind — and the chip they
/// were about to tap moves out from under their thumb. Here selection is a fill
/// and a border, and nothing moves.
class _StageChip extends StatelessWidget {
  const _StageChip({
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

    return Semantics(
      button: true,
      selected: selected,
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

/// Flat list ↔ grouped by the kind of offence.
///
/// An icon, not a labelled button. It sits at the end of a row that already
/// carries six stage chips and a date button, and "Board view" spelled out would
/// push the chips off the screen on a narrow handset. The icon is the one the
/// website uses for the same toggle, and the tooltip says which way it goes.
class _ViewToggle extends ConsumerWidget {
  const _ViewToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final grouped = ref.watch(complaintViewProvider).isGrouped;
    final colour =
        grouped ? scheme.primary : scheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: IconButton(
        key: ComplaintKeys.viewToggle,
        onPressed: ref.read(complaintViewProvider.notifier).toggle,
        visualDensity: VisualDensity.compact,
        tooltip: grouped ? 'Show as one list' : 'Group by kind of offence',
        icon: Icon(
          grouped ? Icons.view_list_rounded : Icons.dashboard_outlined,
          size: 20,
          color: colour,
        ),
      ),
    );
  }
}

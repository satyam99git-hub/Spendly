import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint_filter.dart';
import '../../domain/entities/complaint_status.dart';
import '../controllers/complaint_filter_controller.dart';
import '../controllers/complaint_providers.dart';
import 'complaint_keys.dart';

/// How the inbox divides up, in four numbers.
///
/// ---------------------------------------------------------------------------
/// WHY COUNTS AND NOT A CHART
///
/// The website's console has the same four as tiles across the top of its
/// complaints panel, and they answer the question an officer asks on arriving at
/// the desk: *how much of this is mine, and how much has been dealt with?* Four
/// integers answer it. A chart would take three times the height to say the same
/// thing less precisely, on the screen where vertical space is the list.
///
/// **They count the whole table, not the filtered view.** That is the point of
/// them: the count under the list already says "12 of 48" for what a filter is
/// showing, and a header that also moved when a filter changed would be a second
/// version of the same number. These stay still, so an officer can filter to
/// Pending and still see that eleven others are under review.
///
/// Each is a filter. Tapping Pending is the shortest path from "there are nine"
/// to "here they are", and a row of numbers an officer cannot act on is a row
/// they stop reading.
/// ---------------------------------------------------------------------------
class ComplaintStatRow extends ConsumerWidget {
  const ComplaintStatRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read here rather than passed in. The inbox watches
    // `filteredComplaintsProvider`, so a list handed down from it would be the
    // narrowed one — and these counts would move with the filter, which is
    // exactly what the doc above says they must not do.
    final complaints = ref.watch(complaintsProvider).valueOrNull;
    if (complaints == null) return const SizedBox.shrink();

    final filter = ref.watch(complaintFilterProvider);
    final controller = ref.read(complaintFilterProvider.notifier);

    int countOf(ComplaintStatus status) =>
        complaints.where((c) => c.status == status).length;

    final tiles = <({String label, int count, ComplaintStage stage})>[
      (label: 'All', count: complaints.length, stage: ComplaintStage.all),
      (
        label: 'Pending',
        count: countOf(ComplaintStatus.pending),
        stage: ComplaintStage.pending,
      ),
      (
        label: 'Reviewing',
        count: countOf(ComplaintStatus.underReview),
        stage: ComplaintStage.underReview,
      ),
      (
        label: 'FIR filed',
        count: countOf(ComplaintStatus.firFiled),
        stage: ComplaintStage.firFiled,
      ),
    ];

    return Padding(
      key: ComplaintKeys.stats,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        0,
      ),
      child: Row(
        children: [
          for (final tile in tiles) ...[
            Expanded(
              child: _Tile(
                key: ComplaintKeys.stat(tile.stage.name),
                label: tile.label,
                count: tile.count,
                selected: filter.stage == tile.stage,
                // Tapping the selected one clears back to All, so the row is a
                // toggle rather than a trap an officer has to leave through the
                // chips underneath.
                onTap: () => controller.setStage(
                  filter.stage == tile.stage
                      ? ComplaintStage.all
                      : tile.stage,
                ),
              ),
            ),
            if (tile != tiles.last) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour =
        selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.controlBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: selected ? 0.12 : 0.04),
          borderRadius: AppRadius.controlBorder,
          border: Border.all(
            color: colour.withValues(alpha: selected ? 0.5 : 0.18),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTypography.fieldValue.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colour,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.error.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint.dart';
import 'complaint_category_chip.dart';
import 'complaint_keys.dart';
import 'complaint_status_chip.dart';

/// One complaint in the inbox.
///
/// ---------------------------------------------------------------------------
/// WHAT A ROW HAS TO ANSWER BEFORE IT IS TAPPED
///
/// Triage is deciding which of forty rows to open, so the row has to carry
/// enough to decide with: what it is about, who filed it, when it arrived, and
/// whether anybody has dealt with it. The tracking ID is *not* that — nobody
/// recognises `CMP-3F91A2C7` — so it is set small and last, where it is
/// available for reading out on the phone but is not competing for the eye.
///
/// The description gets two lines and the largest type in the row, because it is
/// the only field that distinguishes one complaint from another. It is also what
/// the search box matches on, so a row that appears because of a hit inside the
/// narrative has something visible explaining itself.
/// ---------------------------------------------------------------------------
class ComplaintTile extends StatelessWidget {
  const ComplaintTile({
    super.key,
    required this.complaint,
    required this.onTap,
    this.writingFir = false,
  });

  final Complaint complaint;
  final VoidCallback onTap;

  /// True while an FIR is being written for this complaint.
  ///
  /// A conversion is a form the officer can walk away from half-finished, and
  /// the complaint's own status does not move until the FIR is actually filed —
  /// so without this the inbox would look untouched and the officer would have
  /// no way back to the row they were working on.
  final bool writingFir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final description = complaint.incidentDescription.trim();

    return InkWell(
      key: ComplaintKeys.tile(complaint.trackingId),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complaint.summaryLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.fieldValue.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (writingFir)
                  // Takes the status chip's place rather than sitting beside it.
                  // The row has one slot at that end, and "you are in the middle
                  // of registering an FIR for this" is the more urgent of the
                  // two — the status is still whatever it was and is visible on
                  // the detail screen a tap away.
                  _WritingFirChip(colour: scheme.primary)
                else
                  ComplaintStatusChip(complaint: complaint, compact: true),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              description.isEmpty ? 'No description was filed.' : description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: description.isEmpty
                        ? muted
                        : scheme.onSurface.withValues(alpha: 0.85),
                    height: 1.35,
                    fontStyle:
                        description.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
            ),
            // The server's triage of the narrative, under the narrative it
            // triaged. Above the date row rather than beside the status pill:
            // the two say different things — "has anyone picked this up" and
            // "can an FIR be filed on it" — and a row that ends in two chips
            // reads as one fact stated twice.
            if (complaint.hasCategory) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: ComplaintCategoryChip(
                  complaint: complaint,
                  compact: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: muted),
                const SizedBox(width: AppSpacing.xs + 1),
                Text(
                  complaint.receivedOnDisplay.isEmpty
                      ? 'Date not recorded'
                      : complaint.receivedOnDisplay,
                  style: AppTypography.error.copyWith(color: muted),
                ),
                if (complaint.hasFir) ...[
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.link_rounded, size: 13, color: muted),
                  const SizedBox(width: AppSpacing.xs + 1),
                  // The FIR number, not just "has an FIR". An officer scanning
                  // the inbox for a case they are working knows the number, and
                  // this is the only place it appears without opening the row.
                  Flexible(
                    child: Text(
                      complaint.firNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.error.copyWith(color: muted),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  complaint.trackingId,
                  style: AppTypography.error.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks the complaint whose FIR is currently being written.
///
/// Deliberately shaped like [ComplaintStatusChip] — same height, same radius,
/// same type — because it stands in the same slot. A differently-shaped badge
/// there would make the row jump when the conversion finishes.
class _WritingFirChip extends StatelessWidget {
  const _WritingFirChip({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colour.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note_rounded, size: 13, color: colour),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Writing FIR',
            style: AppTypography.error.copyWith(
              color: colour,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

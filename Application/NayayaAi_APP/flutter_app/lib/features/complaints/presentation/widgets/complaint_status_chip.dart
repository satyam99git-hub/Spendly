import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_status.dart';

/// The status of one complaint, as a chip.
///
/// ---------------------------------------------------------------------------
/// WHY FOUR STATUSES AND ONLY TWO COLOURS
///
/// The obvious design gives each status its own colour. The palette does not
/// have them: it is navy, one blue, one saffron and one red, and saffron already
/// means something specific — operator-supplied and deployment-specific text, the
/// officer's own ID and the station line. Spending it on "Pending" would make the
/// two unrelated things on screen agree in colour and mean nothing by it.
///
/// So the colour carries the distinction that actually drives the officer's
/// behaviour — **is this still mine?** — and the icon and the label carry which
/// of the four it is:
///
///   - **Pending** — filled. Nobody has touched it; it is the loudest thing in
///     the inbox because it is the only one asking for something.
///   - **Under review** — outlined, same colour. Live, but claimed.
///   - **FIR filed** / **Closed** — muted. Done with, and not competing for
///     attention with the rows that are not.
///
/// An unreadable status renders muted with a question mark rather than as one of
/// the four, because guessing which it meant is how a complaint gets closed
/// twice.
/// ---------------------------------------------------------------------------
class ComplaintStatusChip extends StatelessWidget {
  const ComplaintStatusChip({
    super.key,
    required this.complaint,
    this.compact = false,
  });

  final Complaint complaint;

  /// Drops the icon and tightens the padding, for a list row where the pill sits
  /// beside a date and must not push the tracking ID into an ellipsis.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = complaint.status;

    final live = status?.isOpen ?? false;
    final colour = live ? scheme.primary : scheme.onSurface.withValues(alpha: 0.6);
    final filled = status == ComplaintStatus.pending;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: filled ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: colour.withValues(alpha: filled ? 0.55 : 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(_icon(status), size: 13, color: colour),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            complaint.statusLabel,
            style: AppTypography.error.copyWith(
              color: colour,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(ComplaintStatus? status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Icons.inbox_rounded;
      case ComplaintStatus.underReview:
        return Icons.pending_actions_rounded;
      case ComplaintStatus.firFiled:
        return Icons.description_rounded;
      case ComplaintStatus.closed:
        return Icons.check_circle_outline_rounded;
      case null:
        return Icons.help_outline_rounded;
    }
  }
}

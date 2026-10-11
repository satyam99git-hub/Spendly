import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/complaint.dart';

/// What the server made of a complaint's narrative, as a chip.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS NOT A COLOUR-CODED SEVERITY SCALE
///
/// The website gives each of its ten categories a colour — red for homicide,
/// rose for a sexual offence, amber for assault, down to slate for the three
/// "we could not tell" buckets. Ten hues is a fine thing to have on a desktop
/// board with a column per category and the whole palette of a CSS framework
/// behind it.
///
/// This app has navy, one blue, one saffron and one red, and each already means
/// something. Ten categories cannot be given ten of four colours, and inventing
/// six more would leave the officer reading a rainbow where every hue is a
/// wrong guess away from meaning something it does not.
///
/// So the chip carries the one distinction that changes what an officer does
/// next — **can an FIR be filed on this?** — in the same colour the rest of the
/// app uses for "this needs you", and the label carries which of the ten it is.
/// That is the same information the website's pill carries in its tooltip; it is
/// simply the part that had to survive the trip to a four-colour palette.
///
/// The warning triangle is the website's own ⚠️, kept because an officer moving
/// between the console and the handset should not have to re-learn what marks a
/// cognizable complaint.
/// ---------------------------------------------------------------------------
///
/// Renders nothing at all for a row with no category — see
/// [Complaint.hasCategory]. Rows filed before the categoriser existed have an
/// empty column, and a chip reading "Not categorised" on every one of them would
/// be a column of noise down the inbox.
class ComplaintCategoryChip extends StatelessWidget {
  const ComplaintCategoryChip({
    super.key,
    required this.complaint,
    this.compact = false,
  });

  final Complaint complaint;

  /// Drops the icon and tightens the padding, for a list row where the chip sits
  /// beside the status pill and both have to fit on one line.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!complaint.hasCategory) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final cognizable = complaint.isCognizable;

    // Saffron is spoken for — it marks operator-supplied text elsewhere in the
    // app — so the emphasis colour is the scheme's error red, read off the
    // theme rather than the palette so it stays legible on navy in dark mode.
    // Red for "an FIR can be filed on this" is the website's own choice, and an
    // officer moving between the two should not have to re-learn it.
    final colour =
        cognizable ? scheme.error : scheme.onSurface.withValues(alpha: 0.6);

    return Tooltip(
      // The website puts exactly this on its pill. It is the sentence that
      // explains why one chip is red and the next is grey.
      message: cognizable
          ? 'FIR can be filed'
          : 'FIR typically not applicable — read the narrative and decide',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? 2 : AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: cognizable ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: colour.withValues(alpha: cognizable ? 0.50 : 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cognizable) ...[
              Icon(Icons.warning_amber_rounded, size: 13, color: colour),
              const SizedBox(width: AppSpacing.xs),
            ] else if (!compact) ...[
              Icon(Icons.label_outline_rounded, size: 13, color: colour),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                complaint.categoryLabel,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.error.copyWith(
                  color: colour,
                  fontWeight: cognizable ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/fir_record.dart';
import 'fir_history_keys.dart';

/// One FIR in the history list.
///
/// Four things, in the order an officer scanning the list reads them: the
/// number, who reported it and where, what it was filed under, and when it was
/// recorded. Nothing from the narrative — a truncated first line of a statement
/// is the part of a complaint least likely to identify it, and on a shared
/// handset it puts the details of a case on screen for whoever is standing
/// nearby.
class FirRecordTile extends StatelessWidget {
  const FirRecordTile({
    super.key,
    required this.record,
    required this.onTap,
  });

  final FirRecord record;
  final VoidCallback onTap;

  /// Beyond this the chips are summarised. Two fit on the narrowest handset the
  /// app supports without wrapping the row into a third line.
  static const _maxSections = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final sections = record.sectionList;

    return InkWell(
      key: FirHistoryKeys.tile(record.firNo),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.iconChip,
              height: AppSizes.iconChip,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 22,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.displayNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                        ),
                      ),
                      if (record.filedOnDisplay.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          record.filedOnDisplay,
                          style: AppTypography.error.copyWith(color: muted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.summaryLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: muted),
                  ),
                  if (sections.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final section in sections.take(_maxSections))
                          _SectionChip(label: section),
                        if (sections.length > _maxSections)
                          _SectionChip(
                            label: '+${sections.length - _maxSections}',
                            subdued: true,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One act and section, as filed.
///
/// Not parsed into an [ActSection]. The column is free text that the website's
/// own form writes too, so a value that does not split into an act and a number
/// is a value the app should still show rather than drop.
class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.label, this.subdued = false});

  final String label;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = subdued
        ? scheme.onSurface.withValues(alpha: 0.55)
        : scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: colour.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: AppTypography.error.copyWith(
          color: colour,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

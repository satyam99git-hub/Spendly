import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/evidence_category.dart';
import '../../domain/entities/evidence_item.dart';
import 'evidence_keys.dart';

/// One file, as a row.
///
/// The icon carries the category rather than a text label doing it, because on a
/// list of thirty files the thing an officer is scanning for is "the photo" or
/// "the PDF", and a shape is faster to scan than a word. The word is still there
/// for a screen reader, in the semantic label.
class EvidenceTile extends StatelessWidget {
  const EvidenceTile({super.key, required this.item, required this.onTap});

  final EvidenceItem item;
  final VoidCallback onTap;

  static IconData iconFor(EvidenceCategory category) {
    switch (category) {
      case EvidenceCategory.image:
        return Icons.image_outlined;
      case EvidenceCategory.video:
        return Icons.videocam_outlined;
      case EvidenceCategory.audio:
        return Icons.graphic_eq_rounded;
      case EvidenceCategory.pdf:
        return Icons.picture_as_pdf_outlined;
      case EvidenceCategory.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      label: '${item.category.label}. ${item.filename}. FIR ${item.firNo}',
      excludeSemantics: true,
      child: Material(
        key: EvidenceKeys.tile(item.firNo, item.filename),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: AppSizes.iconChip,
                  height: AppSizes.iconChip,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Icon(
                    iconFor(item.category),
                    size: 21,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category.label,
                        style: AppTypography.error.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, size: 20, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

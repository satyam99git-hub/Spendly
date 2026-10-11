import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import '../../domain/entities/legal_section.dart';
import 'legal_keys.dart';

/// One section in a list.
///
/// Shows the number, the title, and the first two lines of the text where there
/// is any. A cross-act search hit has none — see [LegalSection.isSummary] — and
/// the tile simply omits the body rather than showing a placeholder: a row that
/// says "no description" for every result of every search is a row that has
/// stopped carrying information.
class LegalSectionTile extends StatelessWidget {
  const LegalSectionTile({
    super.key,
    required this.section,
    required this.onTap,
    this.showAct = false,
  });

  final LegalSection section;
  final VoidCallback onTap;

  /// Prints the act alongside the number. On by default only for cross-act
  /// search results — inside one act's list it would be the same word on every
  /// row.
  final bool showAct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      key: LegalKeys.sectionTile(section.act, section.section),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showAct ? section.longLabel : 'Section ${section.section}',
                    style: AppTypography.label.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.title.isEmpty ? 'Untitled' : section.title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                  ),
                  if (!section.isSummary) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      section.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: muted,
                            height: 1.35,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

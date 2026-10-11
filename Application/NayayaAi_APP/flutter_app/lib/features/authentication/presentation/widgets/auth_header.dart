import 'package:flutter/material.dart';

import '../../../../shared/widgets/images/justice_crest.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';

/// Navy masthead above the sign-in sheet.
///
/// COLLAPSES WHEN THE KEYBOARD IS UP. On a 5" handset the keyboard claims most
/// of the viewport; holding a full-height masthead would squeeze the form into a
/// slot too short to show both fields at once. When [compact] is set the crest
/// and subtitle drop out and the padding tightens, handing that space to the
/// form. The transition is animated so the change reads as intentional rather
/// than as a layout glitch.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  /// The masthead colour for the active theme.
  ///
  /// Light: [AppColors.navy], with the white sheet lifting off it.
  /// Dark: the DEEPER navy, so the sheet above it is still the lighter plane.
  /// Using the same navy in both inverts the elevation — in dark mode the card
  /// ends up darker than the surface it is supposed to be sitting on top of,
  /// and the whole thing reads as a hole rather than a card.
  static Color backgroundFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.navyDeep
        : AppColors.navy;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      color: backgroundFor(context),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        compact ? AppSpacing.lg : AppSpacing.xxxl,
        AppSpacing.xxl,
        compact ? AppSpacing.lg : AppSpacing.xxl + AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            const JusticeCrest(),
            const SizedBox(height: AppSpacing.xxl),
          ],
          Text(
            title,
            style: AppTypography.display.copyWith(color: AppColors.white),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: AppTypography.subtitle.copyWith(
                color: AppColors.onNavyMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

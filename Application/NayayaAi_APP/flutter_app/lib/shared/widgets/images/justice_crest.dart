import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';

/// The NyayaAI emblem on a translucent chip.
///
/// The chip is white at low alpha rather than a solid colour so it sits on any
/// navy surface without introducing another palette entry. It is drawn at two
/// scales: small and flat in the sign-in masthead, large and lifted on the
/// splash. Same mark, one definition -- the two must not drift.
///
/// The mark is `assets/images/logo/emblem.png`: the ring and scales cut out of
/// the brand lockup and keyed to transparency, so it composites onto the chip
/// with no navy halo. It is deliberately NOT `Logo.png` -- that file carries its
/// own navy tile and its own "NyayaAI" wordmark, and both are already on screen
/// wherever this appears.
///
/// DECORATIVE. The wordmark beside or beneath it always carries the meaning, so
/// the image stays unlabelled and screen readers announce the name once.
class JusticeCrest extends StatelessWidget {
  const JusticeCrest({
    super.key,
    this.size = AppSizes.iconChip,
    this.radius = AppRadius.chip,
    this.elevated = false,
  });

  /// The emblem's own asset path. Public so a test can precache it — an
  /// un-cached [Image.asset] resolves a frame late, which a golden captures as
  /// an empty chip.
  static const asset = 'assets/images/logo/emblem.png';

  final double size;

  /// Corner radius of the chip. Scale it with [size] -- [AppRadius.chip] on the
  /// 44px masthead crest reads as "soft square"; the same 12px on a 96px chip
  /// reads as a plain box.
  final double radius;

  /// Casts a soft drop shadow. Only for the splash, where the crest is the
  /// single object on the screen and needs to lift off the background; inside
  /// the masthead there is nothing for it to lift from.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.14),
        ),
        boxShadow: elevated
            ? const [
                // Wide and weak on purpose. On a navy field a tight, opaque
                // shadow does not read as depth, it reads as a dark pad glued
                // under the chip.
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 32,
                  offset: Offset(0, 10),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Image.asset(
          asset,
          // Proportional, so the mark keeps its optical weight at every size.
          // Larger than the 0.48 the old Material glyph used: that glyph was a
          // solid shape, while this one spends its outermost ring on a hairline
          // that all but disappears if the mark is set too small inside the
          // chip.
          width: (size * 0.68).roundToDouble(),
          height: (size * 0.68).roundToDouble(),
          // The asset is 512px and is drawn here between 30px and 65px. At the
          // default FilterQuality.low that much reduction drops the ring to a
          // dotted line; medium mipmaps it instead.
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

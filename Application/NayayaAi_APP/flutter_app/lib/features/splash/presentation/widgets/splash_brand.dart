import 'package:flutter/material.dart';

import '../../../../shared/widgets/images/justice_crest.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';
import 'splash_sequence.dart';

/// Crest, wordmark and department tag, stacked and centred.
///
/// Driven by the splash's single controller: pass the controller itself as
/// [animation] and each element takes its opacity from its own slice of
/// [SplashSequence]. The widget owns no controller and no timer, so it is safe
/// to drop into a golden test at a fixed `animation.value`.
class SplashBrand extends StatelessWidget {
  const SplashBrand({
    super.key,
    required this.animation,
    required this.appName,
    required this.tagline,
  });

  /// The splash controller, 0 -> 1 over [SplashSequence.total].
  final Animation<double> animation;

  final String appName;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    // Scale the crest with the handset rather than pinning it: 76px is right on
    // a 6" phone and looks like a postage stamp on a 10" tablet. The clamp stops
    // it from collapsing on a 4" screen or ballooning on a foldable's outer
    // display.
    final crestSize =
        (MediaQuery.sizeOf(context).shortestSide * 0.19).clamp(64.0, 96.0);

    return Semantics(
      container: true,
      label: '$appName. $tagline.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Fade(
            animation: animation,
            interval: SplashSequence.crest,
            child: JusticeCrest(
              size: crestSize,
              // Keeps the masthead crest's radius-to-size proportion (12/44) at
              // this scale; AppRadius.chip on a 76px chip reads as a plain box.
              radius: crestSize * 0.28,
              elevated: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Fade(
            animation: animation,
            interval: SplashSequence.wordmark,
            child: Text(
              appName,
              textAlign: TextAlign.center,
              style: AppTypography.brand.copyWith(color: AppColors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Fade(
            animation: animation,
            interval: SplashSequence.tagline,
            child: Padding(
              // Optical centring. Letter-spacing is painted after the LAST glyph
              // too, so a centred wide-tracked word sits half a space left of
              // true centre -- visible here because the wordmark directly above
              // it is the reference edge. Push it back by that half space.
              padding: EdgeInsets.only(
                left: AppTypography.brandTag.letterSpacing ?? 0,
              ),
              child: Text(
                tagline,
                textAlign: TextAlign.center,
                style: AppTypography.brandTag.copyWith(
                  color: AppColors.onNavyMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades [child] in over its slice of the parent controller.
///
/// Shared by the brand stack and the footnote, which is why it takes the
/// interval rather than hard-coding one.
class _Fade extends StatelessWidget {
  const _Fade({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: interval),
      child: child,
    );
  }
}

/// The provenance line at the foot of the splash.
///
/// Split out of the brand stack because it is anchored to the bottom safe area,
/// not to the centred column -- but it fades on the same controller, so it lives
/// beside the thing it is timed against.
class SplashFootnote extends StatelessWidget {
  const SplashFootnote({
    super.key,
    required this.animation,
    required this.text,
  });

  final Animation<double> animation;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _Fade(
      animation: animation,
      interval: SplashSequence.footnote,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.footerFine.copyWith(
          color: AppColors.onNavyMuted.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

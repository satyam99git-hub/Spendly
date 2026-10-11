import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';

/// Inline message pinned above a form.
///
/// Deliberately not a SnackBar. A submission failure has to stay on screen while
/// the user corrects the field it refers to, and a snackbar times out, floats
/// over the very controls being fixed, and is gone by the time the keyboard has
/// finished animating. Pinning the message to the form keeps cause and
/// correction in the same place.
///
/// Announced via [Semantics.liveRegion] so a screen-reader user hears it when it
/// appears, rather than only on the next explicit traversal.
///
/// Shared rather than per-feature: sign-in, registration and the FIR review all
/// render a server's own message the same way, and they should keep looking
/// alike as more of them arrive.
class FormBanner extends StatelessWidget {
  const FormBanner({
    super.key,
    required this.message,
    this.tone = FormBannerTone.error,
  });

  final String message;
  final FormBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = tone == FormBannerTone.error;

    final foreground = isError ? scheme.error : scheme.primary;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.09),
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: foreground.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum FormBannerTone { error, success }

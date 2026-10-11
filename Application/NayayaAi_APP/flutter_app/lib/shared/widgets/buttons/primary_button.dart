import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';

/// Filled call-to-action with a built-in busy state.
///
/// While [isLoading] the button keeps its full width and height and swaps the
/// label for a spinner. Collapsing to a small circular indicator -- the common
/// shortcut -- makes the layout jump and moves every control beneath it, which
/// on a sign-in form means the biometric button slides under a thumb already in
/// motion.
///
/// [onPressed] is nulled while busy, so a double-tap cannot fire two sign-in
/// requests.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInteractive = enabled && !isLoading && onPressed != null;

    return SizedBox(
      height: AppSizes.controlHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: isInteractive ? onPressed : null,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

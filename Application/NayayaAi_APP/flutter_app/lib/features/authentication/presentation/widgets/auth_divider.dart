import 'package:flutter/material.dart';

import '../../../../theme/app_typography.dart';

/// The "OR" between the password and biometric paths.
///
/// Rendered as bare text, matching the design -- no flanking rules. Marked as a
/// [Semantics] separator so screen readers announce a boundary between the two
/// sign-in methods instead of reading a stray "or" between buttons.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = 'OR'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: 'or, alternatively',
      excludeSemantics: true,
      child: Center(
        child: Text(
          label,
          style: AppTypography.divider.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

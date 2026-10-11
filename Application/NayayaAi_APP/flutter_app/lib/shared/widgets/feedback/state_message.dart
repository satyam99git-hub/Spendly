import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';

/// An icon, a headline and a sentence — for a screen that has nothing to show.
///
/// Empty, error and no-match are the same shape and should look it. What differs
/// between them is only the words: what happened, and what the officer can do
/// about it. Giving each its own bespoke layout is how a list ends up with a
/// centred spinner-sized error and a top-aligned empty state that look like two
/// different apps.
///
/// [centred] is the one variation. A list keeps its message near the top so it
/// sits where the first row would; a detail screen has no rows and centres it.
///
/// The evidence locker has two private copies of this, written before it
/// existed. They should adopt this widget the next time either is touched — not
/// as a drive-by, because both are pinned by golden tests and a refactor with no
/// behaviour change is not worth re-blessing an image over.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.centred = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: muted),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: muted, height: 1.4),
        ),
      ],
    );

    if (centred) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxxl * 1.5,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: content,
    );
  }
}

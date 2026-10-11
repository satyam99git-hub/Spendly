import 'package:flutter/material.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../../theme/app_typography.dart';

/// The chrome the feature's three bottom sheets share — respond, escalate,
/// filter.
///
/// Shared rather than copied because all three are the same object: a titled
/// panel of choices over a screen the officer must still be able to see they are
/// on, with a button at the bottom. Three hand-rolled versions of that drift into
/// three top paddings and two grabber widths, which is how an app starts looking
/// assembled rather than designed.
class ComplaintSheetScaffold extends StatelessWidget {
  const ComplaintSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.sheetKey,
    this.subtitle,
  });

  /// Put on the scrolling column rather than on the widget itself, so a test can
  /// find the sheet's *content* — `find.byKey` on a route's root turns up a
  /// wrapper that is present before the sheet has laid anything out.
  final Key? sheetKey;

  final String title;

  /// One line under the title. For a sheet that has to be plain about what it
  /// will actually do — the escalate sheet uses it to say that nothing is sent
  /// anywhere.
  final String? subtitle;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      // The keyboard, not a fixed gap: two of these sheets hold a text area, and
      // an officer types into it with the sheet already at full height.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: sheetKey,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.md,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: muted, height: 1.35),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Raises one of the feature's sheets and returns whatever it pops with.
///
/// `isScrollControlled` because two of the three contain a text box: without it
/// the sheet is capped at half the screen and the keyboard covers the very field
/// being typed into.
Future<T?> showComplaintSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: builder,
  );
}

/// One selectable option with an explanation under it.
///
/// A list of these rather than a row of chips where the choice needs explaining:
/// which desk a complaint escalates to, and which stretch of days the inbox
/// shows, are both decisions an officer should not have to already know the
/// convention for. The respond sheet uses chips instead, because its four
/// statuses are explained by a single line under the row rather than four.
class ComplaintChoiceTile extends StatelessWidget {
  const ComplaintChoiceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.controlBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: AppRadius.controlBorder,
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.55)
                    : scheme.outline,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? scheme.primary : muted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.error.copyWith(
                          color: muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

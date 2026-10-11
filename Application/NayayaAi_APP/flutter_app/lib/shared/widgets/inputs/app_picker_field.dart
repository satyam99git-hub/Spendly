import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';

/// A field whose value is chosen, not typed — a date, a time, a district.
///
/// Built to be indistinguishable from `AppTextField`: same label, same
/// [AppSizes.controlHeight] box, same reserved error slot underneath. A form
/// that mixes typed and picked entries should not look like it mixes two
/// widget kits, and the reserved slot is what keeps the column from reflowing
/// when one of them goes red.
///
/// It is a button, and is announced as one. Rendering a tappable box as a
/// disabled text field — the usual shortcut for date entry — leaves a screen
/// reader saying "text field, disabled" about the one control on the row that
/// actually does something.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hintText,
    this.icon,
    this.errorText,
    this.onClear,
    this.enabled = true,
    this.valueStyle,
  });

  final String label;

  /// What is currently chosen, already formatted for display. Empty shows
  /// [hintText] in the hint colour.
  final String value;

  final VoidCallback onTap;
  final String? hintText;
  final IconData? icon;
  final String? errorText;

  /// When supplied, an empty-able field gets a clear affordance once it holds a
  /// value. Omitted for entries that cannot meaningfully be unset.
  final VoidCallback? onClear;

  final bool enabled;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasError = errorText != null;
    final hasValue = value.trim().isNotEmpty;

    // Taken from the input theme rather than picked here, so a picked entry and
    // a typed one sitting in the same column cannot end up different shades of
    // the same near-black. They differ by about 5% in dark mode if this is left
    // to `scheme.surface`, which is exactly enough to look like a mistake.
    final fill = theme.inputDecorationTheme.fillColor ?? scheme.surface;

    final borderColour = hasError
        ? scheme.error
        : scheme.outline.withValues(alpha: enabled ? 1 : 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          value: hasValue ? value : 'not set',
          excludeSemantics: true,
          child: Material(
            color: enabled ? fill : fill.withValues(alpha: 0.6),
            borderRadius: AppRadius.controlBorder,
            child: InkWell(
              borderRadius: AppRadius.controlBorder,
              onTap: enabled ? onTap : null,
              child: Container(
                height: AppSizes.controlHeight,
                padding: const EdgeInsets.only(
                  left: AppSpacing.md + 2,
                  right: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.controlBorder,
                  border: Border.all(color: borderColour),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? value : (hintText ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: hasValue
                            ? (valueStyle ?? AppTypography.fieldValue).copyWith(
                                color: valueStyle?.color ??
                                    scheme.onSurface.withValues(
                                      alpha: enabled ? 1 : 0.5,
                                    ),
                              )
                            : AppTypography.fieldValue.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w400,
                              ),
                      ),
                    ),
                    if (hasValue && onClear != null && enabled)
                      IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: scheme.onSurface.withValues(alpha: 0.5),
                        tooltip: 'Clear $label',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                      )
                    else if (icon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: Icon(
                          icon,
                          size: 19,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    errorText!,
                    style: AppTypography.error.copyWith(color: scheme.error),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

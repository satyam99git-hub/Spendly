import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';

/// Labelled text field with the error message rendered BELOW the control.
///
/// Why not the built-in error slot: [InputDecoration] draws errors inside the
/// decoration, which changes the field's height the moment validation fails and
/// pushes everything under it down the screen. On a two-field form that means
/// the password box moves while the officer is reaching for it. Here the field
/// keeps a fixed [AppSizes.controlHeight] and the message occupies reserved
/// space underneath, so the layout never jumps.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofillHints,
    this.suffix,
    this.valueStyle,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final FormFieldValidator<String>? validator;

  /// Error supplied by the caller rather than derived from [validator].
  ///
  /// For forms whose validity lives outside the widget tree: the FIR form
  /// holds one immutable draft and decides what is missing from *that*, so its
  /// steps pass the message down instead of each field re-deriving it. Takes
  /// precedence over [validator] when both are set, so a field can be
  /// self-validating on one screen and centrally validated on another.
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  /// Overrides the text style of the entered value. The officer ID field uses
  /// this to render in saffron, marking it as operator-supplied.
  final TextStyle? valueStyle;

  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FormField<String>(
      // FormField owns only the error state; the controller owns the text. The
      // validator reads the controller rather than `field.value` so the two can
      // never disagree -- `field.value` only advances on user keystrokes, so a
      // programmatic `controller.text = ...` would otherwise validate stale text.
      initialValue: controller.text,
      validator: (_) => validator?.call(controller.text),
      builder: (field) {
        final message = errorText ?? (field.hasError ? field.errorText : null);
        final hasError = message != null;

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
            SizedBox(
              height: AppSizes.controlHeight,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                textCapitalization: textCapitalization,
                inputFormatters: inputFormatters,
                autofillHints: autofillHints,
                style: (valueStyle ?? AppTypography.fieldValue).copyWith(
                  color: valueStyle?.color ?? scheme.onSurface,
                ),
                cursorColor: scheme.primary,
                onChanged: (v) {
                  field.didChange(v);
                  // Re-validate ONLY while an error is already showing. That
                  // clears the message the moment the officer fixes the value,
                  // without the opposite failure of AutovalidateMode: flagging
                  // "ID looks too short" after the first keystroke of a badge
                  // number nobody has finished typing.
                  if (field.hasError) field.validate();
                  onChanged?.call(v);
                },
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: hintText,
                  suffixIcon: suffix,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  enabledBorder: hasError
                      ? OutlineInputBorder(
                          borderRadius: AppRadius.controlBorder,
                          borderSide: BorderSide(color: scheme.error),
                        )
                      : null,
                ),
              ),
            ),
            // Reserved space: present whether or not there is a message, so the
            // form does not reflow when an error appears or clears.
            SizedBox(
              height: 18,
              child: hasError
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        message,
                        style: AppTypography.error.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

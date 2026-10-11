import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';

/// Multi-line companion to `AppTextField`, for the entries that are prose:
/// the narrative, the complainant's address, the details of the accused.
///
/// Deliberately NOT the same widget with `maxLines`. A single-line field pins
/// its height so the form never reflows; a text area has to do the opposite and
/// grow with what is typed, because a narrative read through a three-line
/// window is a narrative nobody proof-reads. Fusing the two would mean one
/// widget whose central layout promise depends on an argument.
class AppTextArea extends StatelessWidget {
  const AppTextArea({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.helperText,
    this.errorText,
    this.minLines = 4,
    this.maxLines = 12,
    this.maxLength,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.sentences,
    this.focusNode,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;

  /// Guidance shown under the box while it is valid. Replaced by [errorText]
  /// when there is one — two lines of small print under a field compete, and
  /// the correction is what matters at that moment.
  final String? helperText;

  final String? errorText;
  final int minLines;
  final int maxLines;

  /// Caps the entry and shows a counter once the officer is close to it. The
  /// server imposes no limit; this exists so a pasted document cannot become an
  /// FIR narrative that no PDF page can render.
  final int? maxLength;

  final bool enabled;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

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
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AppTypography.fieldValue.copyWith(
            color: scheme.onSurface,
            height: 1.4,
            // Prose, not a badge number. The positive tracking that makes an ID
            // legible character-by-character makes a paragraph tiring.
            letterSpacing: 0,
            fontWeight: FontWeight.w400,
          ),
          cursorColor: scheme.primary,
          onChanged: onChanged,
          inputFormatters: [
            if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: InputDecoration(
            hintText: hintText,
            // The shared theme sets zero vertical padding because single-line
            // fields pin their own height. A text area has to put it back or the
            // first line sits against the border.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2,
              vertical: AppSpacing.md + 2,
            ),
            enabledBorder: hasError
                ? OutlineInputBorder(
                    borderRadius: AppRadius.controlBorder,
                    borderSide: BorderSide(color: scheme.error),
                  )
                : null,
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
              : (helperText == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        helperText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.error.copyWith(color: muted),
                      ),
                    )),
        ),
      ],
    );
  }
}

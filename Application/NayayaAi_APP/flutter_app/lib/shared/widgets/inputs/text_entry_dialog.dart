import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';

/// Collects one short string in a dialog.
///
/// The escape hatch behind pickers whose list came from the server: when the
/// district lookup is unreachable, the officer can still type the district and
/// file the FIR. Locking the form on a failed *reference* request would be the
/// app deciding that a network problem outranks a statutory duty to register.
///
/// Returns the trimmed text, or null if cancelled. Empty input returns null too:
/// dismissing and confirming an empty box mean the same thing to the caller.
Future<String?> showTextEntryDialog(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hintText,
  String? helperText,
  String confirmLabel = 'Use this',
  int maxLength = 80,
  TextCapitalization textCapitalization = TextCapitalization.words,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _TextEntryDialog(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
      helperText: helperText,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
    ),
  );
}

/// A [StatefulWidget] purely so the controller's life matches the dialog's.
///
/// Creating it beside `showDialog` and disposing it after the future completes
/// looks equivalent and is not: `showDialog` returns as soon as the route is
/// popped, while the dialog keeps rebuilding through its own exit animation.
/// The controller is then read after being disposed, which throws — into the
/// frame, where a dialog that is already closing makes it look like it came
/// from whatever is underneath.
class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.confirmLabel,
    required this.maxLength,
    required this.textCapitalization,
    this.initialValue,
    this.hintText,
    this.helperText,
  });

  final String title;
  final String confirmLabel;
  final int maxLength;
  final TextCapitalization textCapitalization;
  final String? initialValue;
  final String? hintText;
  final String? helperText;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  late final _controller =
      TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: AppSizes.controlHeight,
            child: TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: widget.textCapitalization,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              style: AppTypography.fieldValue.copyWith(color: scheme.onSurface),
              decoration: InputDecoration(hintText: widget.hintText),
            ),
          ),
          if (widget.helperText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.helperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

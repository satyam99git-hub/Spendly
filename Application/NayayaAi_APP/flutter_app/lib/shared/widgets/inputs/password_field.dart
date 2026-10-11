import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';
import 'app_text_field.dart';

/// [AppTextField] with a reveal toggle.
///
/// The toggle matters more here than on a consumer app: officers sign in on
/// shared handsets in daylight, and a mistyped password they cannot see costs a
/// lockout. It defaults to obscured and never persists the revealed state.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hintText,
    this.validator,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    this.autofillHints = const [AutofillHints.password],
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final FormFieldValidator<String>? validator;

  /// Error supplied by the caller rather than derived from [validator] — for a
  /// box whose verdict comes from somewhere else, like the locker's PIN gate,
  /// where "wrong" is decided by a controller and not by the field's contents.
  final String? errorText;

  final TextInputAction textInputAction;
  final bool enabled;

  /// Null for a field the platform's password manager has no business filling.
  /// A locker PIN is not the account password, and offering one there teaches
  /// the manager to save the wrong secret against this app.
  final Iterable<String>? autofillHints;

  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      hintText: widget.hintText,
      validator: widget.validator,
      errorText: widget.errorText,
      obscureText: _obscured,
      enabled: widget.enabled,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      focusNode: widget.focusNode,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      suffix: Semantics(
        // Screen readers must not announce the toggle's state as the password
        // itself; label the ACTION, not the value.
        button: true,
        label: _obscured ? 'Show password' : 'Hide password',
        child: IconButton(
          onPressed: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
          splashRadius: 20,
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 19,
            color: scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

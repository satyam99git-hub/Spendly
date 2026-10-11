import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';

/// The website's four-bar password strength meter (signup.html:480-491).
///
/// Advisory only, exactly as there: it never blocks submission. The server's
/// own rule — ten characters with upper, lower, digit and symbol — is what
/// decides, and its message is what the form shows when a password falls short.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  /// 0–4, one point per rule the website counts:
  /// length ≥ 6, length ≥ 10, an uppercase letter *and* a digit, a symbol.
  static int strengthOf(String value) {
    var strength = 0;
    if (value.length >= 6) strength++;
    if (value.length >= 10) strength++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value)) {
      strength++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) strength++;
    return strength;
  }

  /// `weak` at 0–1, `medium` at 2, `strong` at 3–4 — the website's classes.
  static String levelOf(int strength) => strength <= 1
      ? 'weak'
      : strength <= 2
          ? 'medium'
          : 'strong';

  @override
  Widget build(BuildContext context) {
    final strength = strengthOf(password);
    final level = levelOf(strength);
    final colour = switch (level) {
      'weak' => const Color(0xFFEF4444),
      'medium' => const Color(0xFFF59E0B),
      _ => const Color(0xFF22C55E),
    };
    final empty =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

    return Semantics(
      label: password.isEmpty ? null : 'Password strength: $level',
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? colour : empty,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

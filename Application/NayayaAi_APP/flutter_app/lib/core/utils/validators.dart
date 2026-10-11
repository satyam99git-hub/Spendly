import '../enums/user_role.dart';

/// Form validation rules, in one place so the sign-in, registration and
/// password-reset screens cannot drift apart on what counts as valid.
///
/// Each returns `null` when the value passes -- the contract Flutter's
/// [FormFieldValidator] expects.
///
/// These are a UX affordance, not a security control. Every rule here is
/// re-checked server-side; anything that only runs on the client is advisory.
abstract final class Validators {
  /// Letters, digits, hyphen and slash. Matches the state-code format on Indian
  /// police identification (e.g. MH-DL-4471) without hard-coding state prefixes,
  /// which vary by force and would reject valid officers from other units.
  static final _officerId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/]{2,19}$');

  static String? officerId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your officer ID or badge number';
    if (v.length < 3) return 'ID looks too short';
    if (v.length > 20) return 'ID looks too long';
    if (!_officerId.hasMatch(v)) {
      return 'Use letters, numbers, hyphens or slashes only';
    }
    return null;
  }

  /// Presence ONLY, for sign-in.
  ///
  /// Deliberately does not enforce composition rules at sign-in. Telling someone
  /// their existing password "needs a symbol" while they are trying to log in is
  /// both useless and a disclosure about the password policy. Strength rules
  /// belong on the set/change screens -- see [newPassword].
  ///
  /// It does not enforce a minimum length either, and that part is not merely
  /// stylistic: the NyayaAI server has never applied a password policy, so
  /// accounts already in the database have passwords shorter than any floor this
  /// app might pick. A client-side minimum would lock those users out of an app
  /// that is supposed to accept their existing credentials, and the server --
  /// the only authority on whether a password is correct -- would never be
  /// asked. Every rule here must be one the stored data can satisfy.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password';
    return null;
  }

  /// Composition rules for choosing a password at registration.
  ///
  /// The server accepts anything non-empty, so this floor is the app's own and
  /// applies only to accounts created here. It is set at 8 rather than the
  /// stricter [newPassword] policy so that registration in the field is not an
  /// exercise in frustration on a phone keyboard.
  static String? signupPassword(String? value) {
    final v = value ?? '';
    // Not "Choose a password" -- that is the field's own label, and an error
    // that repeats the label reads as a rendering glitch rather than as a
    // correction. The message has to say something the label does not.
    if (v.isEmpty) return 'Enter a password';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  /// Composition rules for resetting a password. Stricter than [signupPassword]
  /// because a reset is a deliberate, unhurried action.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a password';
    if (v.length < 12) return 'Use at least 12 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Include a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return 'Include a symbol';
    return null;
  }

  /// Display name at registration. The server requires presence and nothing
  /// more; the upper bound here is to stop a paste of unbounded text.
  static String? fullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name';
    if (v.length < 2) return 'Name looks too short';
    if (v.length > 80) return 'Name looks too long';
    return null;
  }

  /// The role-prefixed unique ID a police officer, lawyer or judge supplies at
  /// registration.
  ///
  /// Mirrors the server's rule exactly: uppercase, and it must start with the
  /// role's prefix. The server checks nothing else -- real IDs in the database
  /// range from `POL1` to `POL-101` to `POL9999` -- so this deliberately does
  /// not impose a shape beyond the prefix and a sane length. Rejecting an ID
  /// format the server would have accepted is the failure mode to avoid here.
  ///
  /// Returns null for [UserRole.citizen], whose ID the server generates.
  static String? uniqueId(String? value, UserRole role) {
    if (!role.requiresUserSuppliedId) return null;

    final v = value?.trim().toUpperCase() ?? '';
    if (v.isEmpty) return 'Enter your ${role.label.toLowerCase()} ID';
    if (!v.startsWith(role.idPrefix)) {
      return 'ID must start with ${role.idPrefix}';
    }
    if (v.length <= role.idPrefix.length) {
      return 'Add your number after ${role.idPrefix}';
    }
    if (v.length > 20) return 'ID looks too long';
    if (!RegExp(r'^[A-Z0-9\-/]+$').hasMatch(v)) {
      return 'Use letters, numbers, hyphens or slashes only';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Re-enter the password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if ((value ?? '').trim().isEmpty) return '$field is required';
    return null;
  }
}

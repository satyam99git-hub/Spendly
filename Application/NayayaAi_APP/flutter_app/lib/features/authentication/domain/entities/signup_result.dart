/// What `POST /signup` answered.
///
/// Two fields because the server has two successes. A new account comes back
/// 201 with the assigned [uniqueId]. An email that is already registered comes
/// back **200 with no ID at all** and the message "If eligible, your account has
/// been created." (app.py:2004-2005) — deliberately vague, so the form cannot be
/// used to find out who has an account. The sign-up screen has to tell the two
/// apart rather than announce an account that was never made.
class SignupResult {
  const SignupResult({required this.uniqueId, this.message});

  /// Empty in the already-registered case.
  final String uniqueId;

  /// The server's own sentence, shown when there is no ID to show.
  final String? message;

  bool get hasUniqueId => uniqueId.isNotEmpty;
}

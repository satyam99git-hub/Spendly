import '../../../../core/enums/user_role.dart';
import '../entities/auth_user.dart';
import '../entities/signup_result.dart';

/// The authentication contract the presentation layer programs against.
///
/// Every method throws a `Failure` on error rather than returning a result
/// wrapper. That is a deliberate choice for this app: all three operations are
/// invoked from a controller that already has a try/catch to drive its loading
/// state, so a wrapper would be unwrapped immediately at every call site.
abstract interface class AuthRepository {
  /// Signs in with email and password.
  ///
  /// On success the session cookie is stored and the profile is cached.
  ///
  /// Throws [AuthFailure] on rejected credentials, [ValidationFailure] when the
  /// server refuses the input, [NetworkFailure] when it cannot be reached.
  Future<AuthUser> login({required String email, required String password});

  /// Registers a new account.
  ///
  /// [uniqueId] is required for police, lawyer and judge, and must carry that
  /// role's prefix; the server generates one for citizens and ignores anything
  /// passed. See [UserRole.requiresUserSuppliedId].
  ///
  /// Note this does NOT sign the user in — the server registers the account and
  /// returns without establishing a session. Returns the server-assigned unique
  /// ID so the UI can show a citizen the ID that was generated for them — or,
  /// for an email that is already registered, no ID and the server's message
  /// (see [SignupResult]).
  Future<SignupResult> signup({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? uniqueId,
  });

  /// Ends the session, server-side and locally.
  ///
  /// Never throws. A sign-out that fails at the server must still clear the
  /// local session, or the user stays signed in against their wishes.
  Future<void> logout();

  /// Resolves the stored session against the server.
  ///
  /// Returns null when there is no valid session — including when the server is
  /// unreachable. "Unknown" is treated as "signed out" on purpose: showing
  /// sign-in to someone already signed in costs a tap, the reverse costs a
  /// security boundary.
  Future<AuthUser?> restoreSession();
}

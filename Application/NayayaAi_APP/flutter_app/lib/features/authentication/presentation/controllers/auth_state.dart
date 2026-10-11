import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_user.dart';

/// Where the app is in the sign-in lifecycle.
///
/// [unknown] is separate from [signedOut] and the distinction is load-bearing:
/// the router must not redirect anyone to sign-in while the session is still
/// being resolved, or every cold start flashes the login screen before landing
/// on the dashboard.
enum AuthStatus { unknown, authenticating, signedIn, signedOut }

/// Immutable auth state.
class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.failure});

  final AuthStatus status;

  /// Non-null exactly when [status] is [AuthStatus.signedIn].
  final AuthUser? user;

  /// The last failure, held so a screen can render it after a rebuild rather
  /// than only catching it once at the call site. Cleared on the next attempt.
  final Failure? failure;

  const AuthState.unknown() : this();

  const AuthState.authenticating() : this(status: AuthStatus.authenticating);

  const AuthState.signedIn(AuthUser user)
      : this(status: AuthStatus.signedIn, user: user);

  const AuthState.signedOut({Failure? failure})
      : this(status: AuthStatus.signedOut, failure: failure);

  bool get isSignedIn => status == AuthStatus.signedIn && user != null;
  bool get isResolving => status == AuthStatus.unknown;
  bool get isBusy => status == AuthStatus.authenticating;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          other.status == status &&
          other.user == user &&
          other.failure == failure;

  @override
  int get hashCode => Object.hash(status, user, failure);

  @override
  String toString() => 'AuthState(${status.name}, ${user?.uniqueId ?? '-'})';
}

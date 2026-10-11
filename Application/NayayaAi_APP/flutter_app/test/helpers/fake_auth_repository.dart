import 'package:nayaya_app/core/enums/user_role.dart';
import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/authentication/domain/entities/auth_user.dart';
import 'package:nayaya_app/features/authentication/domain/entities/signup_result.dart';
import 'package:nayaya_app/features/authentication/domain/repositories/auth_repository.dart';

/// Scriptable [AuthRepository] for widget and controller tests.
///
/// Hand-written rather than mocked: the interface has four methods, and a fake
/// that records its calls is easier to read in a failing test than a mock's
/// verification syntax.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.loginResult,
    this.loginFailure,
    this.signupResult = 'CIT001',
    this.signupMessage = 'User registered successfully',
    this.signupFailure,
    this.restoreResult,
  });

  /// Returned by [login] when [loginFailure] is null.
  AuthUser? loginResult;

  /// Thrown by [login] when set. Takes precedence over [loginResult].
  Failure? loginFailure;

  String signupResult;

  /// The server's `message`. Paired with an empty [signupResult] it is the
  /// already-registered answer: 200, no ID.
  String? signupMessage;
  Failure? signupFailure;

  /// Returned by [restoreSession]. Null means "no session".
  AuthUser? restoreResult;

  /// Artificial latency, so a test can observe the in-flight state.
  Duration delay = Duration.zero;

  // ---- call log -------------------------------------------------------------

  final List<({String email, String password})> loginCalls = [];
  final List<
      ({
        String fullName,
        String email,
        String password,
        UserRole role,
        String? uniqueId,
      })> signupCalls = [];
  int logoutCount = 0;
  int restoreCount = 0;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    loginCalls.add((email: email, password: password));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = loginFailure;
    if (failure != null) throw failure;
    return loginResult ??
        const AuthUser(
          role: UserRole.citizen,
          uniqueId: 'CIT001',
          email: 'someone@example.com',
        );
  }

  @override
  Future<SignupResult> signup({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? uniqueId,
  }) async {
    signupCalls.add(
      (
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        uniqueId: uniqueId,
      ),
    );
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = signupFailure;
    if (failure != null) throw failure;
    return SignupResult(uniqueId: signupResult, message: signupMessage);
  }

  @override
  Future<void> logout() async {
    logoutCount++;
  }

  @override
  Future<AuthUser?> restoreSession() async {
    restoreCount++;
    return restoreResult;
  }
}

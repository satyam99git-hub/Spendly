import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/signup_result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioClientProvider).dio),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    storage: ref.watch(secureStorageProvider),
    client: ref.watch(dioClientProvider),
  ),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Owns the session for the whole app.
///
/// The single source of truth for "who is signed in": the router redirects off
/// it, screens read it for identity, and nothing else is allowed to hold a
/// competing copy.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Starts as `unknown`, not `signedOut`. The router treats those differently
    // -- see AuthStatus -- and asserting "signed out" before asking the server
    // makes every launch flash the sign-in screen.
    _restore();
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    // Started before the request so the two overlap: the hold costs nothing when
    // the network is slower than it, which is the common case on a cold start.
    final hold = Future<void>.delayed(AppConfig.splashHold);

    AuthUser? user;
    try {
      user = await _repository
          .restoreSession()
          .timeout(AppConfig.sessionRestoreTimeout);
    } catch (_) {
      // restoreSession is documented not to throw, so this is either a bug or
      // the timeout above. Either way the answer to "is anyone signed in?" is
      // no, and it is not the splash's job to explain why -- sign-in will say so
      // when the next attempt fails there, where there is a form to say it
      // against.
      user = null;
    }

    // Let the brand mark finish. See AppConfig.splashHold.
    await hold;

    state =
        user == null ? const AuthState.signedOut() : AuthState.signedIn(user);
  }

  /// Signs in. Returns true on success.
  ///
  /// The boolean is for the *caller's* control flow (a screen deciding whether
  /// to stay put); the state change is what actually drives navigation, via the
  /// router's redirect. Screens must not navigate on the return value alone or
  /// the two mechanisms fight over the same transition.
  Future<bool> login({required String email, required String password}) async {
    state = const AuthState.authenticating();
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState.signedIn(user);
      return true;
    } catch (error) {
      state = AuthState.signedOut(failure: ErrorMapper.map(error));
      return false;
    }
  }

  /// Registers an account and returns what the server answered — the assigned
  /// unique ID, or no ID and a message for an already-registered email.
  ///
  /// Does not sign the user in — the server's `/signup` establishes no session,
  /// so the app deliberately does not pretend one exists. The sign-up screen
  /// shows the assigned ID and hands off to sign-in.
  ///
  /// Throws [Failure] so the calling screen can render the server's own message
  /// against the field it concerns.
  Future<SignupResult> signup({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? uniqueId,
  }) async {
    state = const AuthState.authenticating();
    try {
      final result = await _repository.signup(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        uniqueId: uniqueId,
      );
      state = const AuthState.signedOut();
      return result;
    } catch (error) {
      final failure = ErrorMapper.map(error);
      state = AuthState.signedOut(failure: failure);
      throw failure;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState.signedOut();
  }

  /// Drops a failure once a screen has shown it, so it does not resurface on
  /// the next rebuild.
  void clearFailure() {
    if (state.failure == null) return;
    state = AuthState(status: state.status, user: state.user);
  }
}

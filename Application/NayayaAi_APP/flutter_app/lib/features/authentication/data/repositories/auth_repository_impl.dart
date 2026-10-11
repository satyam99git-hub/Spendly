import 'dart:convert';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/signup_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_models.dart';

/// Coordinates the auth endpoints with local session storage.
///
/// Two things are persisted on sign-in, in two different places, for two
/// different reasons:
///   1. the Flask session cookie, held by the cookie jar inside [DioClient] —
///      this is the actual credential
///   2. the profile cache in secure storage — display name, email, unique ID,
///      none of which any server response returns on session restore
///
/// They are written together and cleared together. A cache without a cookie
/// would show a signed-in shell that every request 401s behind; a cookie without
/// a cache is recoverable (the app just knows less about the user), which is why
/// restore tolerates the second but never the first.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required SecureStorageService storage,
    required DioClient client,
  })  : _remote = remote,
        _storage = storage,
        _client = client;

  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;
  final DioClient _client;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final normalisedEmail = email.trim();

    // Any cookie from a previous account must go before the new sign-in, not
    // after. If the server rejects these credentials, the jar would otherwise
    // still hold the old valid session and the app would look signed in as
    // whoever used the handset last.
    await _client.clearSession();

    final response = await _remote.login(
      LoginRequest(email: normalisedEmail, password: password),
    );

    final user = response.toEntity(email: normalisedEmail);
    await _cache(user);
    return user;
  }

  @override
  Future<SignupResult> signup({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? uniqueId,
  }) async {
    final response = await _remote.signup(
      SignupRequest(
        fullName: fullName.trim(),
        email: email.trim(),
        password: password,
        role: role,
        uniqueId: uniqueId?.trim(),
      ),
    );
    return SignupResult(
      uniqueId: response.uniqueId,
      message: response.message,
    );
  }

  @override
  Future<void> logout() async {
    // Told-you-so ordering: try the server first so the session is invalidated
    // there too, but never let its failure stop the local clear below.
    try {
      await _remote.logout();
    } on Failure {
      // Offline, or the server is down. The local session still goes.
    }

    await _client.clearSession();
    await _storage.delete(StorageKeys.cachedUser);
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final SessionResponse session;
    try {
      session = await _remote.me();
    } on Failure {
      // Unreachable server. Treated as signed out — see AuthRepository docs for
      // why this direction is the safe one. Nothing is cleared: the cookie may
      // still be perfectly valid, and the next launch on a live network should
      // restore it rather than force a re-entry of credentials.
      return null;
    }

    if (!session.loggedIn) {
      // An authoritative "no". The cookie is dead, so the cache it belonged to
      // is stale and must not survive to be shown next launch.
      await _client.clearSession();
      await _storage.delete(StorageKeys.cachedUser);
      return null;
    }

    final cached = await _readCache();
    final serverRole = session.role;

    if (cached == null) {
      // Valid session, but the profile cache is gone — a fresh install restored
      // from backup, or storage that failed to decrypt. Enough is known to let
      // the user in; the name and unique ID stay blank until the next sign-in.
      return AuthUser(
        role: serverRole ?? UserRole.citizen,
        uniqueId: '',
        userId: session.userId,
      );
    }

    // The server's role wins over the cached one. Role drives what the user can
    // reach, so a role changed server-side must take effect on the next launch
    // rather than persisting until someone signs out.
    final user = cached.toEntity(
      authoritativeRole: serverRole,
      userId: session.userId,
    );

    if (serverRole != null && serverRole != cached.role) {
      await _cache(user);
    }

    return user;
  }

  Future<void> _cache(AuthUser user) async {
    final json = jsonEncode(CachedUser.fromEntity(user).toJson());
    await _storage.write(StorageKeys.cachedUser, json);
  }

  Future<CachedUser?> _readCache() async {
    final raw = await _storage.read(StorageKeys.cachedUser);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return CachedUser.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // Corrupt entry — drop it rather than failing startup over a cache.
      await _storage.delete(StorageKeys.cachedUser);
      return null;
    }
  }
}

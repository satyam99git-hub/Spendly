import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over platform secure storage (Android Keystore / iOS Keychain).
///
/// Exists so callers depend on an interface this project owns rather than on the
/// plugin directly, and so every read is null-safe: a keystore entry can fail to
/// decrypt after an OS restore or a backup migration, and the plugin throws
/// rather than returning null. A profile cache that throws on read would break
/// startup, so reads here degrade to null and the caller treats that as
/// "nothing stored".
class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  factory SecureStorageService.standard() => const SecureStorageService(
        FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        ),
      );

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Unreadable entry — treat as absent and let it be overwritten.
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // A cache that cannot be written is a degraded experience (the user signs
      // in again next launch), not a failure worth aborting the sign-in for.
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Nothing useful to do; the value is already unreachable.
    }
  }
}

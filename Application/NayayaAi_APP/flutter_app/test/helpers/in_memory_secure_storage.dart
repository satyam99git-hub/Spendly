import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nayaya_app/core/storage/secure_storage_service.dart';

/// [SecureStorageService] backed by a map.
///
/// Needed because the real one talks to the Android Keystore through a platform
/// channel, which in a widget test throws `MissingPluginException` — and the FIR
/// form reads storage on the way in, so without this every test of it would
/// fail before rendering a single field.
///
/// Extends rather than reimplements: the interface is three methods, and
/// subclassing keeps this honest about being the same type the app injects. The
/// [FlutterSecureStorage] handed to `super` is never touched — none of the three
/// overrides call it.
class InMemorySecureStorage extends SecureStorageService {
  InMemorySecureStorage([Map<String, String>? initial])
      : values = {...?initial},
        super(const FlutterSecureStorage());

  /// Readable by tests, so an assertion can be made about what the app *saved*
  /// rather than only about what it displayed.
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

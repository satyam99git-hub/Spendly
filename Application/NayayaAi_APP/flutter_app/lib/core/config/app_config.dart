import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Deployment-specific values, resolved once at startup.
///
/// The base URL is a `--dart-define` rather than a constant in source because
/// the same APK has to point at a laptop during development, a staging box in
/// QA, and a real host in production. Baking it in means rebuilding to move.
///
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.7:5000
///
/// See [defaultBaseUrl] for what happens when it is left unset.
abstract final class AppConfig {
  const AppConfig._();

  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Where the NyayaAI server lives.
  static String get baseUrl =>
      _baseUrlOverride.isNotEmpty ? _baseUrlOverride : defaultBaseUrl;

  /// Development fallback, per platform.
  ///
  /// `10.0.2.2` is the Android emulator's alias for the host machine's
  /// loopback: inside the emulator, `127.0.0.1` is the emulator itself, so a
  /// Flask server on the developer's laptop is unreachable at localhost. iOS
  /// simulators share the host's network stack and do not need the alias.
  ///
  /// A *physical* handset can reach neither — it needs the host's LAN address
  /// passed through `--dart-define`. That is the case [isUsingDevFallback]
  /// exists to warn about.
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:5000';
    return Platform.isAndroid
        ? 'http://10.0.2.2:5000'
        : 'http://127.0.0.1:5000';
  }

  /// True when no override was supplied and the emulator fallback is in play.
  /// Startup logs this in debug builds so "connection refused" on a real device
  /// points at the missing define instead of looking like a server outage.
  static bool get isUsingDevFallback => _baseUrlOverride.isEmpty;

  /// Generous enough for a cold Flask dev server, which loads model weights on
  /// the first request and can take several seconds to answer.
  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 30);

  /// The floor on how long a cold start stays on the splash.
  ///
  /// Session restore usually answers in well under a second, and without a floor
  /// the router would move off the splash a few frames in -- the brand mark
  /// appears, is cut mid-fade, and reads as a glitch rather than as a launch.
  ///
  /// INVARIANT: must be >= `SplashSequence.total + SplashSequence.hold` (2s + 1s
  /// at the time of writing), or the animation is still truncated. It lives here
  /// rather than beside those constants because AuthController enforces it, and
  /// a controller must not import from a presentation package.
  static const splashHold = Duration(seconds: 3);

  /// Ceiling on session restore. Past this the app stops waiting and treats the
  /// session as absent, so an unreachable server cannot strand anyone on the
  /// splash with no way forward.
  static const sessionRestoreTimeout = Duration(seconds: 8);
}

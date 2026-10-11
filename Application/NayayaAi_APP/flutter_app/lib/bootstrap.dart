import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/providers.dart';
import 'core/network/dio_client.dart';

/// Async startup work, kept out of `main()` so that file never needs a reason to
/// change.
///
/// Everything here has to finish before the first frame because the router's
/// redirect reads the auth state on its very first evaluation, and the auth
/// state cannot be resolved without an HTTP client that has already loaded the
/// stored session cookie.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only. This is a one-handed, in-the-field tool; a landscape sign-in
  // form on a phone puts the keyboard over both fields.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Draw behind the status and navigation bars; each screen sets its own glyph
  // colours through AnnotatedRegion.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Opens the cookie jar and restores any stored session. Async, which is why
  // the provider that exposes it is override-only — see core/di/providers.dart.
  final dioClient = await DioClient.create();

  if (kDebugMode) {
    developer.log('base URL: ${AppConfig.baseUrl}', name: 'boot');
    if (AppConfig.isUsingDevFallback) {
      developer.log(
        'No API_BASE_URL define — using the emulator fallback. A physical '
        'device cannot reach this; pass '
        '--dart-define=API_BASE_URL=http://<your-lan-ip>:5000',
        name: 'boot',
      );
    }
  }

  runApp(
    ProviderScope(
      overrides: [dioClientProvider.overrideWithValue(dioClient)],
      child: const NayayaApp(),
    ),
  );
}

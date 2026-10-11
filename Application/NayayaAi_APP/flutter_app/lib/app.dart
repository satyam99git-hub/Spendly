import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget: theme wiring and the router.
///
/// There is no `home:` — every screen is reached through a route, and which one
/// the app opens on is the router's auth redirect to decide, not this widget's.
/// See routes/app_router.dart.
class NayayaApp extends ConsumerWidget {
  const NayayaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NyayaAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the device setting until the settings feature persists a
      // preference; ThemeController then drives this.
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

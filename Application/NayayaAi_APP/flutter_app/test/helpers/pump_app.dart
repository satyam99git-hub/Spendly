import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nayaya_app/core/config/app_config.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:nayaya_app/features/authentication/presentation/screens/signup_screen.dart';
import 'package:nayaya_app/routes/app_routes.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import 'fake_auth_repository.dart';

/// Mounts the auth screens with a scripted repository behind them.
///
/// A real [GoRouter] is used rather than a bare `home:` because both screens
/// navigate by name -- sign-in pushes sign-up, sign-up pops back with the email
/// it collected -- and a Navigator without those routes registered would throw
/// on the first tap.
///
/// The full app router is deliberately NOT used: its first route is the splash,
/// which would put every test behind the startup hold for no benefit.
Future<void> pumpAuthApp(
  WidgetTester tester, {
  required FakeAuthRepository repository,
  String initialLocation = AppRoutes.login,
  Brightness brightness = Brightness.light,
}) async {
  // The default 800x600 test surface is shorter than a phone, and the sign-up
  // form is long enough that its submit button falls outside it -- taps then
  // land on nothing and the test fails for a reason that has nothing to do with
  // what it is checking. Use an iPhone-14-class portrait viewport instead.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: AppRoutes.signupName,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
      ),
    ),
  );

  await settleStartup(tester);
}

/// Advances past the startup session restore.
///
/// AuthController holds its answer for [AppConfig.splashHold] so the splash
/// animation is never cut short. In a test that shows up as a pending timer,
/// which the binding reports as a failure at teardown unless it is drained.
Future<void> settleStartup(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppConfig.splashHold + const Duration(milliseconds: 100));
}

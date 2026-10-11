import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:nayaya_app/features/authentication/presentation/screens/login_screen.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/golden_assets.dart';
import '../helpers/golden_fonts.dart';
import '../helpers/pump_app.dart';

/// Golden snapshots of the sign-in screen.
///
/// See loadGoldenFonts for why the fonts are bound by hand and why these are
/// tagged `golden`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

  /// iPhone-14-class logical size at 3x. Large enough that the sheet is not
  /// scrolled, so the whole form is visible in one frame.
  const logicalSize = Size(390, 844);
  const pixelRatio = 3.0;

  Future<void> pumpAt(
    WidgetTester tester, {
    required Brightness brightness,
  }) async {
    tester.view
      ..devicePixelRatio = pixelRatio
      ..physicalSize = logicalSize * pixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // The screen reads the auth controller, whose repository would otherwise
        // resolve through the override-only DioClient provider and throw.
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            // Tests report zero insets. Inject the notch and home-indicator
            // padding a real handset has, or the header sits too high and the
            // footer too low to tell whether the spacing is right.
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 47, bottom: 34),
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
          },
          home: const LoginScreen(),
        ),
      ),
    );
    await settleStartup(tester);
    await tester.pumpAndSettle();
    // The masthead crest is an asset. Without this it paints as an empty chip.
    await precacheBrandAssets(tester);
  }

  testWidgets(
    'login screen — light',
    (tester) async {
      await pumpAt(tester, brightness: Brightness.light);
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('images/login_light.png'),
      );
    },
    tags: 'golden',
  );

  testWidgets(
    'login screen — dark',
    (tester) async {
      await pumpAt(tester, brightness: Brightness.dark);
      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('images/login_dark.png'),
      );
    },
    tags: 'golden',
  );

  testWidgets(
    'login screen — filled, as a user would see it mid-entry',
    (tester) async {
      await pumpAt(tester, brightness: Brightness.light);

      await tester.enterText(
        find.byType(TextField).first,
        'officer@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('images/login_filled.png'),
      );
    },
    tags: 'golden',
  );

  testWidgets(
    'login screen — validation errors',
    (tester) async {
      await pumpAt(tester, brightness: Brightness.light);

      // `.last` — "Sign in" is also the masthead title.
      await tester.tap(find.text('Sign in').last);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LoginScreen),
        matchesGoldenFile('images/login_errors.png'),
      );
    },
    tags: 'golden',
  );
}

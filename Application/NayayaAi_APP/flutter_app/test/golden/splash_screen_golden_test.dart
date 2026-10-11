import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:nayaya_app/features/splash/presentation/widgets/splash_sequence.dart';
import 'package:nayaya_app/theme/app_theme.dart';

import '../helpers/golden_assets.dart';
import '../helpers/golden_fonts.dart';

/// Golden snapshots of the splash.
///
/// Captured at the END of the fade, which is the only frame worth pinning -- it
/// is the composition the officer actually reads. Mid-fade frames would pin the
/// stagger, and the stagger is a design decision that should stay free to
/// change.
///
/// See loadGoldenFonts for why the fonts are bound by hand and why these are
/// tagged `golden`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

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
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            // Tests report zero insets. Inject the notch and home-indicator
            // padding a real handset has, or the footnote sits flush against
            // the bottom edge and there is no telling whether it clears the
            // gesture bar.
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 47, bottom: 34),
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );

    // Fade complete, hold still running -- so nothing has navigated away and
    // every element is at full opacity.
    await tester.pump(SplashSequence.total);
    // The crest is an asset. Without this it paints as an empty chip.
    await precacheBrandAssets(tester);
  }

  testWidgets(
    'splash screen — light',
    (tester) async {
      await pumpAt(tester, brightness: Brightness.light);
      await expectLater(
        find.byType(SplashScreen),
        matchesGoldenFile('images/splash_light.png'),
      );
    },
    tags: 'golden',
  );

  testWidgets(
    'splash screen — dark',
    (tester) async {
      await pumpAt(tester, brightness: Brightness.dark);
      await expectLater(
        find.byType(SplashScreen),
        matchesGoldenFile('images/splash_dark.png'),
      );
    },
    tags: 'golden',
  );
}

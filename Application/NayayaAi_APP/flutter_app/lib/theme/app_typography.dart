import 'package:flutter/material.dart';

/// Type scale.
///
/// FONTS: the sign-in title is set in a serif to read as institutional rather
/// than product-y. `'serif'` resolves to the platform serif (Noto Serif on
/// Android) so this ships with no asset weight and no licence question.
///
/// To swap in a bundled face later: drop the .ttf files into assets/fonts/,
/// declare the family in pubspec.yaml, and change [serifFamily] here. Nothing
/// else in the app names a font.
abstract final class AppTypography {
  static const serifFamily = 'serif';

  /// The UI sans. Named explicitly rather than left null.
  ///
  /// Styles fed to ButtonStyle do NOT inherit the family that ThemeData applies
  /// to textTheme, so leaving this unset made button labels resolve through a
  /// different fallback path than every other string on the screen — visible
  /// immediately in a golden, and a latent inconsistency on any device whose
  /// system font is not Roboto. On Android 'Roboto' is the platform face.
  static const sansFamily = 'Roboto';

  /// Sign-in title. Weight 600 rather than bold -- at 30px a serif set in full
  /// bold reads as shouting, and this screen is meant to feel official, not loud.
  static const display = TextStyle(
    fontFamily: serifFamily,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.2,
  );

  /// The splash wordmark. Larger and a touch wider-tracked than [display]:
  /// [display] is a heading with a form under it and has to sit down; this is
  /// the only object on its screen and is read as a mark, not as a sentence.
  /// Weight 500, one step BELOW [display]. The sign-in title has a form under it
  /// competing for attention and needs the extra weight to stay on top; the
  /// wordmark has an empty screen and does not. At 34px, w600 serif stops
  /// reading as elegant and starts reading as loud.
  static const brand = TextStyle(
    fontFamily: serifFamily,
    fontSize: 34,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: 0.3,
  );

  /// "POLICE" beneath the wordmark.
  ///
  /// The wide tracking is doing the work here -- it is what makes a six-letter
  /// word read as a department mark rather than as a stray caption. Anything
  /// rendered in this style needs the optical-centring fix in SplashBrand,
  /// because trailing letter-spacing is painted after the final glyph.
  static const brandTag = TextStyle(
    fontFamily: sansFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 4.5,
  );

  /// The line under the title.
  static const subtitle = TextStyle(
    fontFamily: sansFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Field labels.
  static const label = TextStyle(
    fontFamily: sansFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Text the officer typed. Slight positive tracking because badge numbers are
  /// read character-by-character, not as a word.
  static const fieldValue = TextStyle(
    fontFamily: sansFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const button = TextStyle(
    fontFamily: sansFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// "Forgot password?"
  static const link = TextStyle(
    fontFamily: sansFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  /// The "OR" divider.
  static const divider = TextStyle(
    fontFamily: sansFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );

  /// Station line in the footer.
  static const footer = TextStyle(
    fontFamily: sansFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// Build / statute line.
  static const footerFine = TextStyle(
    fontFamily: sansFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const error = TextStyle(
    fontFamily: sansFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );
}

import 'package:flutter/material.dart';

/// Raw brand palette. Nothing outside `theme/` should reference these directly --
/// screens read colours off `Theme.of(context)` so light and dark stay in step.
///
/// The palette is deliberately small. Every value here appears in the sign-in
/// design; resist adding shades that no screen actually uses.
abstract final class AppColors {
  // ---- navy: the authority surface -----------------------------------------
  /// Sign-in header background.
  static const navy = Color(0xFF1D3D5C);

  /// Deeper navy for the dark-theme scaffold and system chrome.
  static const navyDeep = Color(0xFF14293C);

  /// Dark-theme card surface -- lifted off [navyDeep] so the card still reads as
  /// a distinct plane rather than merging with the header.
  static const navySurface = Color(0xFF1B3450);

  // ---- action ---------------------------------------------------------------
  static const blue = Color(0xFF3068E5);
  static const blueDark = Color(0xFF5B8BF0); // legible on navy

  // ---- saffron: station identity + entered credentials ----------------------
  /// Used for the officer ID value and the station footer. Carries meaning --
  /// it marks operator-supplied and deployment-specific text, so do not reuse it
  /// as a generic accent.
  static const saffron = Color(0xFFB4531B);
  static const saffronDark = Color(0xFFE08A4F); // legible on navy

  // ---- neutrals (light) -----------------------------------------------------
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2937);
  static const inkMuted = Color(0xFF374151);
  static const slate = Color(0xFF9AA3AF);
  static const border = Color(0xFFDDE3EA);
  static const borderStrong = Color(0xFFD5DBE3);
  static const fieldFill = Color(0xFFFFFFFF);

  // ---- neutrals (dark) ------------------------------------------------------
  static const inkDark = Color(0xFFE8EEF4);
  static const inkMutedDark = Color(0xFFB6C4D2);
  static const slateDark = Color(0xFF7F91A3);
  static const borderDark = Color(0xFF2F4A66);
  static const fieldFillDark = Color(0xFF16304A);

  // ---- on-navy text ---------------------------------------------------------
  /// Subtitle under the sign-in title. Muted enough to sit behind the heading,
  /// still above the 4.5:1 contrast floor on [navy].
  static const onNavyMuted = Color(0xFFA9BBCD);

  static const danger = Color(0xFFDC2626);
  static const dangerDark = Color(0xFFF87171);
}

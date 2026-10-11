import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_typography.dart';

/// Material 3 themes for light and dark.
///
/// The sign-in header is navy in BOTH themes -- it is the brand surface, not a
/// background. What changes between themes is the sheet that lifts over it:
/// white in light, [AppColors.navySurface] in dark.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.blueDark : AppColors.blue,
      onPrimary: isDark ? AppColors.navyDeep : AppColors.white,
      secondary: isDark ? AppColors.saffronDark : AppColors.saffron,
      onSecondary: AppColors.white,
      surface: isDark ? AppColors.navySurface : AppColors.white,
      onSurface: isDark ? AppColors.inkDark : AppColors.ink,
      error: isDark ? AppColors.dangerDark : AppColors.danger,
      onError: AppColors.white,
      outline: isDark ? AppColors.borderDark : AppColors.border,
      outlineVariant: isDark ? AppColors.borderDark : AppColors.borderStrong,
    );

    final onSurfaceMuted = isDark ? AppColors.inkMutedDark : AppColors.inkMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.navyDeep : AppColors.navy,

      // Material 3's ink response. Named explicitly so it survives a future
      // ThemeData default change rather than shifting under us.
      splashFactory: InkSparkle.splashFactory,

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.fieldFillDark : AppColors.fieldFill,
        // Vertical padding is 0: the field's height is pinned by a SizedBox in
        // AppTextField so inputs and buttons line up exactly. Let the content
        // centre itself inside that box instead of fighting it with padding.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
        ),
        border: _outline(scheme.outline),
        enabledBorder: _outline(scheme.outline),
        focusedBorder: _outline(scheme.primary, width: 1.6),
        errorBorder: _outline(scheme.error),
        focusedErrorBorder: _outline(scheme.error, width: 1.6),
        hintStyle: AppTypography.fieldValue.copyWith(
          color: isDark ? AppColors.slateDark : AppColors.slate,
          fontWeight: FontWeight.w400,
        ),
        // Errors render beneath the field via AppTextField, not inside the
        // decoration -- an inline error would change the field's height and
        // shunt the whole form downward mid-typing.
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.5),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.8),
          elevation: 0,
          textStyle: AppTypography.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: AppTypography.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.controlBorder,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppTypography.link,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 40), // keeps the 40dp touch target
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      textTheme: TextTheme(
        displaySmall: AppTypography.display.copyWith(color: scheme.onSurface),
        bodyMedium: TextStyle(color: onSurfaceMuted),
        labelLarge: AppTypography.label.copyWith(color: onSurfaceMuted),
      ),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.controlBorder,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

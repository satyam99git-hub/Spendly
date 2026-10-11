import 'package:flutter/widgets.dart';

/// Spacing scale. A 4pt grid -- every gap in the app is one of these, which is
/// what stops screens drifting into 13px-here / 15px-there inconsistency.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

/// Corner radii.
abstract final class AppRadius {
  /// Inputs and buttons.
  static const control = 10.0;

  /// The icon chip in the sign-in header.
  static const chip = 12.0;

  /// The white sheet that lifts over the navy header.
  static const sheet = 28.0;

  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
}

/// Fixed sizes that several widgets must agree on.
abstract final class AppSizes {
  /// Applies to text fields and both button styles. They stack vertically in the
  /// sign-in form, so a shared height is what makes the column look deliberate.
  static const controlHeight = 52.0;

  static const iconChip = 44.0;

  /// Beyond this the form stops growing and centres instead. A 52px-tall field
  /// stretched across a tablet is a long mouse-trip to a small target.
  static const maxFormWidth = 420.0;
}

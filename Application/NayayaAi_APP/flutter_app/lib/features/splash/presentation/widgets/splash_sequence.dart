import 'package:flutter/animation.dart';

/// Timing for the splash.
///
/// One controller runs for [total] and every element takes its opacity from an
/// [Interval] of it, rather than each element owning a controller and a delay
/// timer. That is what guarantees the stagger cannot drift, and it means a
/// reduced-motion device can skip the whole sequence by setting a single value
/// to 1.
///
/// The intervals OVERLAP deliberately. A strict relay -- icon finishes, then
/// title starts -- reads as three separate events and makes 2s feel like 4. With
/// the overlap the eye follows one continuous rise down the column.
abstract final class SplashSequence {
  /// Fade-in, end to end. The brief asks for ~2s and this is the whole of it.
  static const total = Duration(milliseconds: 2000);

  /// Beat between the last element landing and the session check. Lets the
  /// finished mark be read as a finished mark rather than as a flash.
  static const hold = Duration(seconds: 1);

  /// Ceiling on the session check itself. A storage read that never returns must
  /// not strand the officer on a splash with no way forward -- past this, the
  /// splash gives up and shows sign-in.
  static const gateTimeout = Duration(seconds: 5);

  // Fractions of [total]: 0.00-0.35 = 0-700ms, and so on.
  static const crest = Interval(0.0, 0.35, curve: Curves.easeOut);
  static const wordmark = Interval(0.25, 0.6, curve: Curves.easeOut);
  static const tagline = Interval(0.45, 0.8, curve: Curves.easeOut);

  /// The provenance line at the foot of the screen. Last, and slowest, because
  /// it is the least important thing on the screen.
  static const footnote = Interval(0.65, 1.0, curve: Curves.easeOut);
}

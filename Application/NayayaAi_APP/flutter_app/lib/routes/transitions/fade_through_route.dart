import 'package:flutter/material.dart';

/// Material "fade through": the outgoing screen fades out over the first third,
/// the incoming one fades in and settles up from 92% scale over the rest.
///
/// Used for the splash -> sign-in handoff, where there is no spatial or
/// hierarchical relationship between the two screens for a slide to express. A
/// default MaterialPageRoute would push sign-in in from the right, which reads as
/// "you navigated somewhere" rather than "the app finished starting".
///
/// This is a transition, not a router. When go_router lands it becomes the
/// `pageBuilder` of a CustomTransitionPage and the class body stays as it is.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute({
    required Widget page,
    super.settings,
  }) : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: _build,
        );

  static Widget _build(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: fadeIn,
      child: ScaleTransition(
        // Barely perceptible on its own; what it does is stop the fade from
        // feeling like a dissolve and give the arrival a direction.
        scale: Tween<double>(begin: 0.94, end: 1).animate(fadeIn),
        child: child,
      ),
    );
  }
}

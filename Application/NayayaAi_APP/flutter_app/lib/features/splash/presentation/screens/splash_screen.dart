import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_dimensions.dart';
import '../../../authentication/presentation/widgets/auth_header.dart';
import '../widgets/splash_brand.dart';
import '../widgets/splash_sequence.dart';

/// Cold-start screen: the brand mark, held while the session is resolved.
///
/// ---------------------------------------------------------------------------
/// THIS SCREEN DOES NOT NAVIGATE. It is a pure animation.
///
/// AuthController resolves the session on startup, and the router's redirect
/// moves off this route the moment the answer arrives -- to `/home` if the
/// stored session is still good, to `/login` otherwise. Having the splash push a
/// route as well would mean two mechanisms racing to perform the same
/// transition, which is how you get a screen that occasionally appears twice or
/// is popped out from under itself.
///
/// The pacing is coordinated the other way round: AuthController will not report
/// its answer before `AppConfig.splashHold`, so the sequence below always gets to
/// finish. See that constant for the invariant tying the two together.
/// ---------------------------------------------------------------------------
///
/// The background is [AuthHeader.backgroundFor] -- the same navy the sign-in
/// masthead paints. That is deliberate: at the handoff the top of the screen
/// does not change colour, so sign-in reads as the splash resolving into a form
/// rather than as a second screen replacing the first.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.appName = 'NyayaAI',
    this.tagline = 'JUSTICE, SIMPLIFIED',
    this.footnote = 'Government of India • Advanced FIR System',
  });

  final String appName;

  /// The department line under the wordmark. Uppercased by the caller, not by
  /// the widget -- `toUpperCase()` on a localised string is a bug waiting for a
  /// Turkish locale.
  final String tagline;

  /// Provenance line above the bottom safe area.
  final String footnote;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashSequence.total,
  );

  /// Guards against a second start from a didChangeDependencies re-entry -- a
  /// theme or metrics change fires it again.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not initState: the reduced-motion check reads MediaQuery, which is not
    // available until the widget is in the tree.
    if (_started) return;
    _started = true;

    // "Remove animations" in Android accessibility settings. With nothing
    // moving, a staggered fade is just a delay, so jump to the end state.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = AuthHeader.backgroundFor(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // Light glyphs: the splash is navy edge to edge, in both themes.
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              children: [
                // The mark centres in whatever is left after the footnote takes
                // its line, so it stays optically centred on a 16:9 handset and
                // on a 21:9 one without a hard-coded top offset.
                Expanded(
                  child: Center(
                    child: SplashBrand(
                      animation: _controller,
                      appName: widget.appName,
                      tagline: widget.tagline,
                    ),
                  ),
                ),
                Padding(
                  // Sits above the gesture bar: SafeArea has already inset the
                  // system area, this is the breathing room on top of it.
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  child: SplashFootnote(
                    animation: _controller,
                    text: widget.footnote,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

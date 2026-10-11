import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nayaya_app/shared/widgets/images/justice_crest.dart';

/// Loads the brand emblem into the image cache so a golden can capture it.
///
/// [Image.asset] resolves through the asset bundle asynchronously. Test
/// pumping runs in a fake-async zone where that I/O never completes, so the
/// first frames paint an empty chip — and a golden taken then records the app
/// as having no logo, which is exactly the regression these tests exist to
/// catch.
///
/// [WidgetTester.runAsync] steps outside that zone for long enough to do the
/// real load. Resolution goes through [precacheImage] against a context from the
/// live tree rather than through a hand-built cache key, so it uses the same
/// [DefaultAssetBundle] and scale the widget will use — a hand-built key that
/// disagrees on either silently caches an entry nothing ever reads.
///
/// Call after `pumpWidget` and before `expectLater`. The image cache is cleared
/// between tests, so this is per test, not `setUpAll`.
///
/// Returns without doing anything when the tree has no crest, so a golden that
/// does not show one (the FIR form, the evidence locker) can call it unconditionally.
Future<void> precacheBrandAssets(WidgetTester tester) async {
  final crest = find.byType(JusticeCrest);
  if (crest.evaluate().isEmpty) return;

  final context = tester.element(crest.first);
  await tester.runAsync(
    () => precacheImage(const AssetImage(JusticeCrest.asset), context),
  );
  await tester.pump();
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

/// Binds real font faces to the families the app requests, for golden tests.
///
/// flutter_test substitutes a placeholder face for every glyph, so an
/// un-prepared golden renders as rows of black boxes. This binds real Noto files
/// to the two families the app asks for -- the default sans and the `serif` that
/// AppTypography uses for the title and the splash wordmark -- so goldens show
/// actual type. Without it the images are worthless for judging the design.
///
/// Call once from `setUpAll`, after `TestWidgetsFlutterBinding.ensureInitialized`.
///
/// PLATFORM: font rasterisation differs between Linux, macOS and CI images, so
/// byte-identical goldens across machines are not a reasonable expectation. Tag
/// golden tests `golden`, exclude them from cross-platform CI with
/// `flutter test --exclude-tags golden`, and regenerate deliberately with
/// `flutter test --update-goldens test/golden`.
Future<void> loadGoldenFonts() async {
  Future<void> bind(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var loadedAny = false;
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loadedAny = true;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    if (loadedAny) await loader.load();
  }

  // Roboto and the icon font ship inside the SDK, so the goldens use the exact
  // faces a device would. Located at runtime rather than hard-coded so this
  // works on any machine.
  final materialFonts = _findMaterialFonts();

  // The app never names a sans family for the ambient default, so Flutter falls
  // back to it -- which in a test binding is the placeholder face. Registering
  // under the default family name makes that fallback resolve to real glyphs.
  await bind('Roboto', [
    '$materialFonts/Roboto-Regular.ttf',
    '$materialFonts/Roboto-Medium.ttf',
    '$materialFonts/Roboto-Bold.ttf',
  ]);

  // Without this every Icon renders as an empty box.
  await bind('MaterialIcons', ['$materialFonts/MaterialIcons-Regular.otf']);

  // AppTypography.serifFamily. Not bundled with Flutter, so this comes from the
  // system; if it is absent the title falls back rather than failing the test.
  const notoDir = '/usr/share/fonts/truetype/noto';
  await bind('serif', [
    '$notoDir/NotoSerif-Regular.ttf',
    '$notoDir/NotoSerif-Medium.ttf',
    '$notoDir/NotoSerif-SemiBold.ttf',
    '$notoDir/NotoSerif-Bold.ttf',
  ]);
}

/// Locates the SDK's bundled font directory.
///
/// Tests execute under `flutter_tester`, not `dart`, so a fixed number of
/// .parent hops from resolvedExecutable lands in the wrong place. Prefer
/// FLUTTER_ROOT (which the test harness sets) and fall back to walking up for
/// the cache directory.
///
/// Returns an empty-ish path if nothing is found; [loadGoldenFonts] skips files
/// that do not exist, so a miss degrades to placeholder glyphs rather than an
/// error.
String _findMaterialFonts() {
  const suffix = 'bin/cache/artifacts/material_fonts';

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && Directory('$root/$suffix').existsSync()) {
    return '$root/$suffix';
  }

  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory('${dir.path}/artifacts/material_fonts');
    if (candidate.existsSync()) return candidate.path;
    final nested = Directory('${dir.path}/$suffix');
    if (nested.existsSync()) return nested.path;
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return '';
}

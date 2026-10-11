import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../theme/app_dimensions.dart';

/// A registered photograph or a sighting's.
///
/// ---------------------------------------------------------------------------
/// WHY THERE ARE TWO SHAPES AND NOT ONE
///
/// This drew every photograph as a square and cropped to fill it. On a headshot
/// that is fine. On the photograph people actually take of a missing person —
/// full body, phone held portrait — a centre crop keeps the torso and **cuts
/// the head off**, which on this feature is the one part that matters: the
/// face is what every sighting is compared against, and an officer holding the
/// handset up against somebody's face was being shown their knees.
///
///   - [PersonPhoto] — a square thumbnail for a list, still cropped to fill
///     because a list of mixed aspect ratios is a ragged list. Aligned to the
///     **top**, so the head is what survives the crop rather than the middle of
///     the body.
///   - [PersonPhoto.whole] — the entire photograph, letterboxed into a box of
///     bounded height. Nothing is hidden. Used everywhere the photograph is the
///     subject of the screen rather than a row's illustration: the case detail
///     header, and both pickers — where the officer has to see exactly what the
///     server is about to run its face detector over, because its refusal
///     ("no face detected") only makes sense against a picture they can see.
///
/// The file itself is never touched. The picker sends what was chosen, at full
/// resolution — see `PlatformEvidenceFilePicker`, which deliberately passes no
/// `maxWidth`/`maxHeight` — so this is a rendering decision and nothing more.
/// ---------------------------------------------------------------------------
///
/// ## Why this does not go through Dio
///
/// `/static/uploads/...` is served by Flask's static handler with no session
/// check, exactly like `/evidence-file/...` — which is what lets [Image.network]
/// fetch it without the cookie jar the app's Dio client holds. Routing it
/// through Dio to get bytes into memory would buy nothing and lose Flutter's own
/// image cache, which is what keeps a list of thirty faces scrolling.
///
/// Every failure is a picture that is not there: a file deleted from the
/// server's disk, a record restored from a backup onto a different machine, a
/// handset with no route to the station. All three read the same to an officer —
/// no photograph — so they get one placeholder rather than three.
class PersonPhoto extends StatelessWidget {
  /// A square thumbnail, cropped to fill and biased to the top.
  const PersonPhoto({
    super.key,
    required this.path,
    this.size = 64,
    this.radius = AppRadius.control,
  })  : localFile = null,
        whole = false,
        height = 0;

  /// The whole photograph, letterboxed into a box [height] tall and as wide as
  /// its parent. Nothing cropped.
  const PersonPhoto.whole({
    super.key,
    required this.path,
    this.height = 260,
    this.radius = 16,
  })  : localFile = null,
        whole = true,
        size = 0;

  /// A photograph chosen on this handset and not yet uploaded, as a square
  /// thumbnail.
  const PersonPhoto.local({
    super.key,
    required String this.localFile,
    this.size = 96,
    this.radius = AppRadius.control,
  })  : path = '',
        whole = false,
        height = 0;

  /// A photograph chosen on this handset, whole. What both pickers show.
  const PersonPhoto.localWhole({
    super.key,
    required String this.localFile,
    this.height = 220,
    this.radius = 16,
  })  : path = '',
        whole = true,
        size = 0;

  /// Server-relative, as the column holds it. Empty renders the placeholder.
  final String path;

  /// An absolute path on this device. Non-null for the two `local` shapes.
  final String? localFile;

  /// Whether to show the entire image rather than crop it to a square.
  final bool whole;

  /// Side of the square, for the thumbnail shapes.
  final double size;

  /// Height of the box, for the whole shapes. Width follows the parent.
  final double height;

  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final local = localFile;
    final url = local == null ? _absolute(path) : '';
    final missing = local == null && url.isEmpty;

    final Widget image;
    if (missing) {
      image = _Placeholder(scheme: scheme, extent: whole ? height : size);
    } else if (local != null) {
      image = Image.file(
        File(local),
        fit: whole ? BoxFit.contain : BoxFit.cover,
        alignment: whole ? Alignment.center : Alignment.topCenter,
        // A picked file can be gone by the time it is drawn — a camera capture
        // the OS cleaned up, a cloud photo that never downloaded.
        errorBuilder: (_, __, ___) =>
            _Placeholder(scheme: scheme, extent: whole ? height : size),
      );
    } else {
      image = Image.network(
        url,
        fit: whole ? BoxFit.contain : BoxFit.cover,
        alignment: whole ? Alignment.center : Alignment.topCenter,
        errorBuilder: (_, __, ___) =>
            _Placeholder(scheme: scheme, extent: whole ? height : size),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : ColoredBox(color: scheme.onSurface.withValues(alpha: 0.05)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: whole
          ? Container(
              width: double.infinity,
              height: height,
              // A backdrop behind the letterboxing, so a portrait photograph
              // reads as a photograph on a card rather than as one floating in
              // a hole in the screen.
              color: scheme.onSurface.withValues(alpha: 0.06),
              child: image,
            )
          : SizedBox(width: size, height: size, child: image),
    );
  }

  /// Joins the server-relative path onto the configured base URL.
  static String _absolute(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http')) return trimmed;

    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.scheme, required this.extent});

  final ColorScheme scheme;
  final double extent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.06),
      child: Icon(
        Icons.person_outline_rounded,
        // Capped, so the icon in a 260-tall header is not a 130-point glyph.
        size: (extent * 0.5).clamp(16.0, 56.0),
        color: scheme.onSurface.withValues(alpha: 0.35),
      ),
    );
  }
}

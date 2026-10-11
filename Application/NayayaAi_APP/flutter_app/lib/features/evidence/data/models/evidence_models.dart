/// Wire models for the evidence endpoints.
///
/// Hand-written, like the rest of this app's models: three shapes, and
/// build_runner would cost more than it saves.
library;

import '../../domain/entities/evidence_category.dart';
import '../../domain/entities/evidence_item.dart';

/// Reads `GET /api/evidence?fir_no=` — one item per stored file, with metadata.
abstract final class EvidenceItemResponse {
  const EvidenceItemResponse._();

  /// Returns null for a row with no filename.
  ///
  /// A nameless row cannot be fetched, previewed or addressed by the detail
  /// route, so rendering it would put a tappable line on the list that leads
  /// nowhere. The server has no constraint preventing one — the collection is
  /// seeded from the filesystem by `seed_evidence_from_filesystem` — so this is
  /// a real case, not defensive noise.
  static EvidenceItem? fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';

    final filename = text('filename');
    if (filename.isEmpty) return null;

    return EvidenceItem(
      firNo: text('fir_no'),
      filename: filename,
      category: EvidenceCategory.fromWire(
        text('file_type'),
        filename: filename,
      ),
      uploadedAt: text('uploaded_at'),
    );
  }
}

/// Reads `GET /get-all-evidence` — `{"<fir_no>": ["a.jpg", "b.pdf"], …}`.
///
/// Flattens the grouping rather than preserving it. The list screen regroups for
/// display, but it also searches and filters across every FIR at once, and a
/// map-of-lists makes that a nested loop at every call site. One flat list, and
/// the grouping is a presentation decision made where the presenting happens.
abstract final class AllEvidenceResponse {
  const AllEvidenceResponse._();

  static List<EvidenceItem> fromJson(Map<String, dynamic> json) {
    final items = <EvidenceItem>[];

    for (final entry in json.entries) {
      final firNo = entry.key.trim();
      final filenames = entry.value;
      if (firNo.isEmpty || filenames is! List) continue;

      for (final raw in filenames) {
        final filename = raw?.toString().trim() ?? '';
        if (filename.isEmpty) continue;
        items.add(
          EvidenceItem(
            firNo: firNo,
            filename: filename,
            // No `file_type` in this payload — the extension is all there is.
            category: EvidenceCategory.fromExtension(filename),
          ),
        );
      }
    }

    return items;
  }
}

/// Reads the 200 from `POST /upload-evidence`: `{message, file, fir_no}`.
///
/// The filename comes back from the *server*, not from the picked file, because
/// `secure_filename` may have rewritten it — `scene 1.jpg` is stored as
/// `scene_1.jpg`. An app that assumed its own name would then build a detail
/// route to a file that is not there.
abstract final class EvidenceUploadResponse {
  const EvidenceUploadResponse._();

  static EvidenceItem fromJson(
    Map<String, dynamic> json, {
    required String fallbackFirNo,
    required String fallbackFilename,
  }) {
    String text(String key) => json[key]?.toString().trim() ?? '';

    final filename = text('file').isEmpty ? fallbackFilename : text('file');
    final firNo = text('fir_no').isEmpty ? fallbackFirNo : text('fir_no');

    return EvidenceItem(
      firNo: firNo,
      filename: filename,
      category: EvidenceCategory.fromExtension(filename),
      // The handler does not echo `uploaded_at`. Left empty rather than stamped
      // client-side: the row's timestamp is the server's UTC clock, and a
      // handset's guess at it would be a different number in the same column.
    );
  }
}

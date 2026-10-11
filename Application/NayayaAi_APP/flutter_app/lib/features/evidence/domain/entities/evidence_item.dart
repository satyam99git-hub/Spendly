import 'evidence_category.dart';

/// One file in the locker.
///
/// The locker has no identifier of its own: the server keys evidence on
/// `(fir_no, filename)` and de-duplicates on that pair, so those two fields
/// together *are* the identity. That is why the detail route addresses an item
/// by both rather than by an id — there is no id to address it by.
class EvidenceItem {
  const EvidenceItem({
    required this.firNo,
    required this.filename,
    required this.category,
    this.uploadedAt = '',
  });

  /// The FIR this was filed against. Always present: the server refuses an
  /// upload whose FIR does not exist, so an orphaned file cannot be created
  /// through the API.
  final String firNo;

  final String filename;

  final EvidenceCategory category;

  /// The server's `uploaded_at`, as it stringifies it — a Python `datetime`
  /// through `str()`, e.g. `2026-08-09 10:11:12.345678`, in UTC.
  ///
  /// **Empty when the item came from `GET /get-all-evidence`**, which returns
  /// filenames only. Screens must treat this as "not known here" rather than as
  /// "never recorded", and the list does: it shows no timestamp at all rather
  /// than a blank line where one should be.
  final String uploadedAt;

  /// Built from the two identifying fields rather than read from `file_url`, so
  /// an item that never went through `GET /api/evidence` still knows where its
  /// bytes are.
  bool get hasTimestamp => uploadedAt.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceItem &&
          other.firNo == firNo &&
          other.filename == filename &&
          other.category == category &&
          other.uploadedAt == uploadedAt;

  @override
  int get hashCode => Object.hash(firNo, filename, category, uploadedAt);

  @override
  String toString() => 'EvidenceItem($firNo/$filename)';
}

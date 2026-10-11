import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_status.dart';
import '../../domain/repositories/complaint_repository.dart';
import '../datasources/complaint_remote_data_source.dart';
import '../models/complaint_models.dart';

/// The complaints repository over the live server.
///
/// Thin, like the FIR one, and for the same reason: there is no offline queue,
/// because "the desk has responded" has to mean the server says so. The two
/// things it does add are the ordering, which the server cannot be relied on
/// for, and the read-modify-write around the PATCH, which the server's handler
/// makes mandatory.
class ComplaintRepositoryImpl implements ComplaintRepository {
  const ComplaintRepositoryImpl({required ComplaintRemoteDataSource remote})
      : _remote = remote;

  final ComplaintRemoteDataSource _remote;

  @override
  Future<List<Complaint>> all() async {
    final complaints = await _remote.all();
    return _newestFirst(complaints);
  }

  @override
  Future<Complaint> byTrackingId(String trackingId) =>
      _remote.byTrackingId(trackingId.trim().toUpperCase());

  /// Newest first, sorted here rather than on screen so every reader of the
  /// inbox agrees on the order.
  ///
  /// The handler already says `ORDER BY created_at DESC`, so this usually
  /// changes nothing — and it is still worth doing. `created_at` is a TEXT
  /// column in SQLite, so that ORDER BY is a *string* sort: it holds for the
  /// `YYYY-MM-DD HH:MM:SS` the default writes, and stops holding the moment a
  /// row arrives with a different spelling, which is exactly the kind of thing
  /// a seed script or a restored backup does. Sorting on the parsed instant
  /// costs nothing on a list already in memory and cannot be wrong.
  ///
  /// Rows with no readable timestamp sink to the bottom rather than floating to
  /// the top: an unparseable value is not evidence of recency, and putting it
  /// first would make it the first thing seen on every open. Ties break on the
  /// tracking ID so two calls return the same order.
  static List<Complaint> _newestFirst(List<Complaint> complaints) {
    final sorted = [...complaints];
    sorted.sort((a, b) {
      final left = a.receivedAt;
      final right = b.receivedAt;

      if (left != null && right != null && left != right) {
        return right.compareTo(left);
      }
      if (left == null && right != null) return 1;
      if (left != null && right == null) return -1;

      return b.trackingId.compareTo(a.trackingId);
    });
    return sorted;
  }

  /// Writes the desk's three columns.
  ///
  /// ---------------------------------------------------------------------------
  /// WHY THE WHOLE COMPLAINT GOES IN AND A RE-READ COMES OUT
  ///
  /// `PATCH /api/complaints/<id>` is not a patch. It writes all three columns
  /// from `data.get(...)`, so a body carrying only `status` stores NULL over
  /// `fir_no` and `officer_notes`. Composing the full triple from [current] is
  /// what stops "Close this complaint" from also deleting the FIR number and
  /// every note attached to it.
  ///
  /// The handler then replies `{message, tracking_id}` — not the row — so the
  /// only way to learn the new `updated_at` is to read it back. That second call
  /// is also the confirmation: it is what proves the write landed on the row the
  /// officer was looking at rather than on nothing, since the PATCH's own 404 is
  /// the only other signal and it is easy to lose behind a proxy.
  /// ---------------------------------------------------------------------------
  @override
  Future<Complaint> update(
    Complaint current, {
    ComplaintStatus? status,
    String? firNo,
    String? officerNotes,
  }) async {
    // The status has to be one the server accepts, and `current` may hold a word
    // the app does not recognise. Falling back to "Under Review" rather than to
    // "Pending" says what is true at that moment: an officer is acting on this
    // complaint right now.
    final nextStatus =
        status ?? current.status ?? ComplaintStatus.underReview;

    final change = ComplaintUpdate(
      status: nextStatus,
      firNo: firNo ?? current.firNo,
      officerNotes: officerNotes ?? current.officerNotes,
    );

    await _remote.update(current.trackingId, change);

    // What the app believes it just wrote. Returned as-is if the read-back
    // cannot be made, so a flaky second call downgrades the freshness of one
    // timestamp instead of reporting a successful write as a failure.
    final applied = current.copyWith(
      statusRaw: change.status.wireValue,
      firNo: change.firNo,
      officerNotes: change.officerNotes,
    );

    try {
      final stored = await _remote.byTrackingId(current.trackingId);
      // `phone` is restored from what we already had: the single-complaint
      // handler does not select that column, so trusting the read-back wholesale
      // would blank the complainant's number on the screen the officer is about
      // to ring them from.
      return stored.copyWith(phone: current.phone);
    } catch (_) {
      return applied;
    }
  }
}

import '../entities/complaint.dart';
import '../entities/complaint_status.dart';

/// What the complaints feature needs from the outside world.
///
/// Three calls, because the server has three: read them all, read one, change
/// one. There is no create — filing a complaint is a citizen's action and this
/// app's complaints surface is the police inbox; `POST /api/complaint` is
/// deliberately not wired up here.
abstract interface class ComplaintRepository {
  /// Every complaint in the table, newest arrival first.
  Future<List<Complaint>> all();

  /// One complaint by its tracking ID.
  ///
  /// The fallback path only. Callers should prefer resolving out of [all], which
  /// is the sole endpoint that returns the complainant's phone number — see
  /// `ApiEndpoints.complaint`. A 404 arrives as a `ValidationFailure` carrying
  /// the server's own wording.
  Future<Complaint> byTrackingId(String trackingId);

  /// Applies an officer's change and returns the stored complaint.
  ///
  /// Takes the **whole** [current] complaint rather than just the edit, and that
  /// is load-bearing: `PATCH /api/complaints/<id>` writes `status`, `fir_no` and
  /// `officer_notes` unconditionally, so anything not sent is stored as NULL.
  /// Passing only the changed field would erase the other two. The implementation
  /// composes the full triple from [current] and whichever of the named arguments
  /// were given.
  ///
  /// Null means "leave as it is". Clearing the FIR link is `firNo: ''`.
  Future<Complaint> update(
    Complaint current, {
    ComplaintStatus? status,
    String? firNo,
    String? officerNotes,
  });
}

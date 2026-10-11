import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_status.dart';
import 'package:nayaya_app/features/complaints/domain/repositories/complaint_repository.dart';

/// Scriptable [ComplaintRepository] for widget and controller tests.
///
/// Hand-written rather than mocked, like `FakeFirRepository`: three methods, and
/// a fake that keeps what it was handed reads better in a failing test than a
/// mock's verification syntax.
///
/// [updates] is the part that matters. Almost everything worth asserting about
/// this feature is "what did the desk actually write" — which status, which FIR
/// number, and whether the note was appended to the trail or dropped on it — and
/// that is only answerable by keeping the arguments of every call.
class FakeComplaintRepository implements ComplaintRepository {
  /// Answered by [all], in the order given.
  ///
  /// The real repository sorts; this deliberately does not, so a test can hand
  /// it complaints out of order and assert on what the screen shows.
  List<Complaint> complaints = const [];

  /// Thrown by [all] when set.
  Failure? allFailure;

  /// Thrown by [byTrackingId] when set. Otherwise it answers from [complaints],
  /// and an unknown ID fails the way the server does.
  Failure? lookupFailure;

  /// Thrown by [update] when set, so the failure banner and the FIR link's retry
  /// path can both be exercised.
  Failure? updateFailure;

  /// Artificial latency, so a test can observe the in-flight state.
  Duration delay = Duration.zero;

  // ---- call log -------------------------------------------------------------

  /// How many times the whole table has been asked for. The assertion that
  /// opening a complaint and coming back does not re-download the inbox.
  int allCalls = 0;

  final List<String> lookups = [];

  /// Every write, with the complaint it started from. The status and the notes
  /// are what the assertions are about; [base] is there so a test can prove the
  /// update was composed from the row as it stood rather than from nothing —
  /// which is the whole point of the read-modify-write.
  final List<
      ({
        Complaint base,
        ComplaintStatus? status,
        String? firNo,
        String? officerNotes,
      })> updates = [];

  @override
  Future<List<Complaint>> all() async {
    allCalls++;
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    final failure = allFailure;
    if (failure != null) throw failure;
    return complaints;
  }

  @override
  Future<Complaint> byTrackingId(String trackingId) async {
    final id = trackingId.trim().toUpperCase();
    lookups.add(id);
    if (delay != Duration.zero) await Future<void>.delayed(delay);

    final failure = lookupFailure;
    if (failure != null) throw failure;

    for (final complaint in complaints) {
      if (complaint.trackingId.toUpperCase() == id) return complaint;
    }
    // The server's own 404 wording, so a screen that renders the message is
    // rendering the same sentence in a test as in the field.
    throw const ValidationFailure(
      'Complaint not found. Check your tracking ID.',
    );
  }

  @override
  Future<Complaint> update(
    Complaint current, {
    ComplaintStatus? status,
    String? firNo,
    String? officerNotes,
  }) async {
    updates.add(
      (
        base: current,
        status: status,
        firNo: firNo,
        officerNotes: officerNotes,
      ),
    );
    if (delay != Duration.zero) await Future<void>.delayed(delay);

    final failure = updateFailure;
    if (failure != null) throw failure;

    final updated = current.copyWith(
      statusRaw:
          (status ?? current.status ?? ComplaintStatus.underReview).wireValue,
      firNo: firNo ?? current.firNo,
      officerNotes: officerNotes ?? current.officerNotes,
      // Stamped, like the handler's `updated_at = CURRENT_TIMESTAMP`, so a
      // screen reading `wasUpdated` sees what it would see in the field.
      updatedAt: '2026-08-09 09:00:00',
    );

    // Written back into the list, so the next `all()` — which every action
    // triggers by invalidating the provider — answers with the changed row.
    complaints = [
      for (final complaint in complaints)
        complaint.trackingId == current.trackingId ? updated : complaint,
    ];

    return updated;
  }
}

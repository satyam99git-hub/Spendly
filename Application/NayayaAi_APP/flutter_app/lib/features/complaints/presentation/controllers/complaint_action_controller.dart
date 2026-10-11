import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_status.dart';
import '../../domain/entities/escalation_desk.dart';
import 'complaint_write.dart';

/// What the detail screen's actions are doing.
class ComplaintActionState {
  const ComplaintActionState({
    this.isSaving = false,
    this.failure,
    this.notice,
  });

  final bool isSaving;

  /// The last write failure, held so the sheet that caused it can keep it on
  /// screen while the officer decides what to do — a snackbar would be gone
  /// before the keyboard had finished animating away.
  final Failure? failure;

  /// A one-shot confirmation for the screen to raise and then clear. Not a
  /// lasting part of the state: the changed complaint is the real confirmation
  /// once the inbox refreshes, and a notice that outlived its snackbar would
  /// come back on the next rebuild.
  final String? notice;

  ComplaintActionState copyWith({
    bool? isSaving,
    Failure? failure,
    String? notice,
    bool clearFailure = false,
    bool clearNotice = false,
  }) {
    return ComplaintActionState(
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : (failure ?? this.failure),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// One complaint's write actions, keyed by tracking ID.
///
/// A family rather than a single controller, so two complaints opened one after
/// the other cannot share a busy state or inherit each other's failure.
/// `autoDispose`, because what a completed action leaves behind is a changed row
/// in `complaintsProvider` — nothing worth keeping lives here once the detail
/// screen is gone.
final complaintActionControllerProvider = NotifierProvider.autoDispose
    .family<ComplaintActionController, ComplaintActionState, String>(
  ComplaintActionController.new,
);

/// Responding to a complaint and escalating it.
///
/// Both are the same server call — the `PATCH` with the three columns the desk
/// owns — and they differ only in what goes into them. They stay two named
/// methods rather than one generic `update(...)` because each is a decision an
/// officer makes and each writes a differently-worded note; a generic setter
/// would let a caller invent a third kind of change that reads like nothing in
/// the trail.
///
/// Recording the FIR a complaint became is deliberately *not* here. That write
/// fires when `/generate_fir` answers, which may be long after this controller's
/// screen is gone — see `ComplaintFirLinkController`.
class ComplaintActionController
    extends AutoDisposeFamilyNotifier<ComplaintActionState, String> {
  @override
  ComplaintActionState build(String trackingId) => const ComplaintActionState();

  /// Writes an officer's reply and, optionally, moves the complaint on.
  ///
  /// [note] may be empty when the status change says everything — closing a
  /// complaint that needs no words. `ComplaintNote.append` drops an empty entry
  /// rather than stamping a blank one.
  ///
  /// [firNo] is here so the path that is *not* an in-app conversion can still
  /// record a number: an FIR registered at the desk, on paper, or by a colleague,
  /// which this app never saw filed. Without it a complaint whose FIR exists
  /// elsewhere could be marked "FIR filed" with nothing attached.
  Future<bool> respond(
    Complaint current, {
    required String note,
    required ComplaintStatus status,
    String? firNo,
  }) {
    final number = firNo?.trim();
    return _write(
      current,
      status: status,
      firNo: number,
      note: [
        if (note.trim().isNotEmpty) note.trim(),
        // Appended to the officer's own words rather than replacing them: the
        // number is a fact about the complaint, the note is what they wanted to
        // say about it, and a trail that swallowed one to record the other would
        // be missing whichever the reader needed.
        if (number != null &&
            number.isNotEmpty &&
            number != current.firNo.trim())
          'FIR $number recorded against this complaint.',
      ].join(' '),
      notice: 'Response saved.',
    );
  }

  /// Sends the complaint to another desk and says why.
  ///
  /// Moves it to [ComplaintStatus.underReview], because the server has no
  /// "escalated" status to move it to and leaving it Pending would say nobody
  /// has touched it. What records the escalation is the note, worded identically
  /// every time so the inbox can be searched for it — see [EscalationDesk],
  /// which is also honest about the fact that nothing is actually *sent*.
  ///
  /// [reason] is required by the app rather than by the server: an escalation
  /// with no reason hands the next desk a complaint and no idea why they have
  /// it, and this column is the only place that reason can be written down.
  Future<bool> escalate(
    Complaint current, {
    required EscalationDesk desk,
    required String reason,
  }) {
    return _write(
      current,
      status: ComplaintStatus.underReview,
      note: 'Escalated to ${desk.label}. Reason: ${reason.trim()}',
      notice: 'Escalated to ${desk.label}.',
    );
  }

  /// The one write, and the only place either action touches the server.
  ///
  /// **Not retried automatically.** The body carries the whole notes column,
  /// composed from the complaint as it was read — so a silent retry after an
  /// ambiguous timeout could overwrite an entry the first attempt had already
  /// appended. The failure is shown and the officer decides, which is the same
  /// call the FIR form and the evidence upload make.
  Future<bool> _write(
    Complaint current, {
    required ComplaintStatus status,
    required String note,
    required String notice,
    String? firNo,
  }) async {
    if (state.isSaving) return false;

    state = state.copyWith(
      isSaving: true,
      clearFailure: true,
      clearNotice: true,
    );

    try {
      await writeComplaintChange(
        ref,
        current,
        status: status,
        firNo: firNo,
        note: note,
      );

      state = state.copyWith(
        isSaving: false,
        notice: notice,
        clearFailure: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        failure: ErrorMapper.map(error, context: 'complaints/$arg'),
      );
      return false;
    }
  }

  /// Clears a failure once its sheet has shown it.
  void clearFailure() {
    if (state.failure == null) return;
    state = state.copyWith(clearFailure: true);
  }

  /// Clears a notice once its snackbar has been raised.
  void clearNotice() {
    if (state.notice == null) return;
    state = state.copyWith(clearNotice: true);
  }
}

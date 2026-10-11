import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/form_dates.dart';
import '../../../fir/presentation/controllers/fir_form_controller.dart';
import '../../../fir/presentation/controllers/fir_form_state.dart';
import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_status.dart';
import 'complaint_providers.dart';
import 'complaint_write.dart';

/// Whether a complaint is waiting for an FIR, and how the last one went.
class ComplaintFirLinkState {
  const ComplaintFirLinkState({
    this.pendingTrackingId,
    this.linkedFirNo,
    this.linkedTrackingId,
    this.failure,
  });

  /// The complaint whose FIR is being written right now, or null.
  ///
  /// Set the moment the officer sends a complaint to the FIR form, cleared the
  /// moment a receipt arrives. A single value rather than a set: the FIR form
  /// holds one draft, so there cannot be two conversions in flight, and
  /// modelling it as a queue would invent a state the app cannot reach.
  final String? pendingTrackingId;

  /// The last conversion that completed, for the confirmation the inbox shows.
  final String? linkedFirNo;
  final String? linkedTrackingId;

  /// Set when the FIR was filed but the complaint could not be updated. The
  /// distinction matters enormously and the message says so: the record exists,
  /// it is only the link that is missing, and re-filing the FIR would be a
  /// duplicate.
  final Failure? failure;

  bool get isPending => pendingTrackingId != null;
}

/// Turning a citizen's complaint into an FIR, and recording that it happened.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS A CONTROLLER AND NOT A CALLBACK ON A BUTTON
///
/// "Convert to FIR" is two writes separated by an unbounded amount of time and a
/// screen the officer can leave. The complaint is seeded into the FIR form, and
/// then the officer may spend ten minutes choosing sections, back out to check
/// the station register, come back, and file — or never file at all. The link
/// can only be written when `/generate_fir` answers, because until then there is
/// no FIR number and the one being typed may still be rejected as a duplicate.
///
/// So the connection between the two features is a listener that outlives both
/// screens, rather than an `await` inside a button. It lives here, in the
/// complaints feature, and reaches *into* the FIR form — never the other way
/// round. The FIR feature knows nothing about complaints, which is what keeps a
/// statutory record's own code free of an inbox's concerns.
///
/// **If the app dies between filing and linking, the link is lost.** The FIR is
/// safe — it is on the server — and the complaint simply stays as it was. The
/// officer can attach the number by hand from the respond sheet, which is why
/// that sheet has an FIR-number box at all.
/// ---------------------------------------------------------------------------
final complaintFirLinkProvider =
    NotifierProvider<ComplaintFirLinkController, ComplaintFirLinkState>(
  ComplaintFirLinkController.new,
);

class ComplaintFirLinkController extends Notifier<ComplaintFirLinkState> {
  @override
  ComplaintFirLinkState build() {
    // Registered once, for the life of the container. The provider is created
    // the first time a screen reads it — the inbox does, to show the outcome —
    // and is not autoDispose, so the listener is still attached when a receipt
    // arrives minutes later on a completely different screen.
    ref.listen<FirFormState>(firFormControllerProvider, (previous, next) {
      final receipt = next.receipt;
      if (receipt == null) return;
      // Only the transition, not every rebuild that still carries the receipt.
      if (previous?.receipt?.firNo == receipt.firNo) return;

      _onFirFiled(receipt.firNo);
    });

    return const ComplaintFirLinkState();
  }

  /// Seeds the FIR form from [complaint] and remembers to link it afterwards.
  ///
  /// The caller is responsible for asking before this throws away an unfinished
  /// draft — see [FirDraft.hasEnteredSomething] and the detail screen, which
  /// puts the question in front of the officer rather than deciding for them.
  ///
  /// What carries over is what a citizen can supply and an officer would
  /// otherwise re-type: who complained, what they said happened, where, and
  /// when. What does not carry over is everything only the station can decide —
  /// the FIR number, the district, the police station, and above all the acts
  /// and sections. Pre-filling a charge from a citizen's description would be
  /// the app making a charging decision, which is not its to make.
  void start(Complaint complaint) {
    ref.read(firFormControllerProvider.notifier).seedFrom(
          (seeded) => seeded.copyWith(
            complainantName: complaint.fullName,
            statement: complaint.incidentDescription,
            placeOfOccurrence: complaint.location,
            // Only when it is genuinely a date. `incident_date` is free text a
            // citizen typed, so it can hold "last Tuesday" — and the FIR's
            // occurrence date is a `yyyy-MM-dd` column that the year and the day
            // of the week are both derived from. Copying prose into it would put
            // a malformed date into a statutory record; leaving it blank asks
            // the officer for one, which is the right outcome.
            occurrenceDate:
                FormDates.parseWireDate(complaint.incidentDate) == null
                    ? ''
                    : complaint.incidentDate.trim(),
          ),
        );

    state = ComplaintFirLinkState(pendingTrackingId: complaint.trackingId);
  }

  /// Abandons a pending conversion without touching the draft.
  ///
  /// For the officer who sends a complaint to the FIR form and then decides the
  /// FIR they are writing is about something else — without this, the next FIR
  /// they file from any screen would be attached to a complaint it has nothing
  /// to do with.
  void cancel() {
    if (!state.isPending) return;
    state = const ComplaintFirLinkState();
  }

  /// Clears the outcome once the inbox has shown it.
  void acknowledge() {
    if (state.linkedFirNo == null && state.failure == null) return;
    state = ComplaintFirLinkState(pendingTrackingId: state.pendingTrackingId);
  }

  Future<void> _onFirFiled(String firNo) async {
    final trackingId = state.pendingTrackingId;
    if (trackingId == null) return;

    // Consumed before the await, not after. A second receipt arriving while this
    // one is still writing would otherwise link the same complaint twice, and
    // the second write would be composed from a complaint read before the first
    // had landed — overwriting the note it had just appended.
    state = const ComplaintFirLinkState();

    try {
      final current = await _complaint(trackingId);
      await writeComplaintChange(
        ref,
        current,
        status: ComplaintStatus.firFiled,
        firNo: firNo,
        note: 'Registered as FIR $firNo.',
      );

      state = ComplaintFirLinkState(
        linkedFirNo: firNo,
        linkedTrackingId: trackingId,
      );
    } catch (error) {
      state = ComplaintFirLinkState(
        linkedFirNo: firNo,
        linkedTrackingId: trackingId,
        failure: ErrorMapper.map(error, context: 'complaints/$trackingId'),
      );
    }
  }

  /// The complaint as it stands, from the inbox if it is loaded and from the
  /// server if it is not.
  ///
  /// The full row matters here rather than just the ID: the update sends the
  /// notes column in full, so linking has to start from what is actually stored
  /// or it would erase whatever was written while the FIR was being typed.
  Future<Complaint> _complaint(String trackingId) async {
    final cached = ref.read(complaintsProvider).valueOrNull;
    if (cached != null) {
      for (final complaint in cached) {
        if (complaint.trackingId == trackingId) return complaint;
      }
    }
    return ref.read(complaintRepositoryProvider).byTrackingId(trackingId);
  }
}

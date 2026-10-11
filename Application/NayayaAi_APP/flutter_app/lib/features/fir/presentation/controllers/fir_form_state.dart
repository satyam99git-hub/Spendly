import '../../../../core/error/failure.dart';
import '../../../evidence/domain/entities/evidence_file.dart';
import '../../domain/entities/fir_draft.dart';
import '../../domain/entities/fir_proof_outcome.dart';
import '../../domain/entities/fir_receipt.dart';

/// Where a submission is in its lifecycle.
///
/// [filed] is terminal for a given draft: the server has written the record and
/// the FIR number is now taken, so there is nothing to go back and edit. The
/// only ways out are a fresh draft or leaving.
enum FirSubmissionStatus { editing, submitting, filed }

/// The whole state of the FIR form.
class FirFormState {
  const FirFormState({
    this.ready = false,
    this.epoch = 0,
    this.draft = const FirDraft(),
    this.step = FirFormStep.registration,
    this.status = FirSubmissionStatus.editing,
    this.showErrors = false,
    this.failure,
    this.receipt,
    this.proofs = const [],
    this.proofOutcome,
    this.restoredFromStorage = false,
  });

  /// False until the saved draft has been read back from storage.
  ///
  /// The form holds a spinner rather than building itself while this is false,
  /// and that is not cosmetic: every text box is seeded from [draft] when it is
  /// first built, so a form built before the restore lands would show empty
  /// boxes over a populated draft — and the officer's first keystroke would then
  /// overwrite the recovered value.
  final bool ready;

  /// Bumped whenever [draft] is replaced wholesale rather than edited — a
  /// restore, a reset, a discard.
  ///
  /// The screen keys its form on this, which tears down and rebuilds every
  /// [TextEditingController] from the new draft. Without it, "discard" would
  /// clear the state and leave the officer looking at the text they just asked
  /// to throw away.
  final int epoch;

  final FirDraft draft;

  /// Which of the four entry steps, or the review, is on screen.
  ///
  /// Held here rather than in the screen's [State] for the same reason the draft
  /// is: the controller is not `autoDispose`, so an officer who backs out of the
  /// form to check the station register and comes back returns to the step they
  /// were on rather than to the start of a form they have already half-filled.
  ///
  /// Not persisted, unlike the draft. A cold start reopens at step 1 with every
  /// entry still in place — which is a reasonable place to resume from, and
  /// cheaper than writing a cursor to the keystore on every Next.
  final FirFormStep step;

  final FirSubmissionStatus status;

  /// Whether required-but-blank entries may show their message.
  ///
  /// False until the first refused Next or Submit. A form that flags every
  /// required box the moment it opens — before the officer has had a chance to
  /// fill anything — looks broken, and trains people to ignore red.
  ///
  /// Reset on every successful step change, so entering step 3 does not open
  /// with the red left over from a refused Next on step 1.
  final bool showErrors;

  /// The last submission failure, held so the form can keep it on screen while
  /// the officer fixes what it names. Cleared on the next attempt.
  final Failure? failure;

  /// Non-null exactly when [status] is [FirSubmissionStatus.filed].
  final FirReceipt? receipt;

  /// Files the officer attached while writing the FIR, waiting on the record to
  /// exist so they have something to be filed against.
  ///
  /// **Not part of [draft], and not autosaved.** Everything in the draft is text
  /// that survives being written to the keystore and read back a day later; a
  /// picked file is a path into a cache directory the OS is free to empty, and
  /// restoring a draft that claimed three photographs it could no longer open
  /// would be worse than restoring one that claimed none.
  ///
  /// The website holds them the same way — `selectedProofFiles` in `script.js`,
  /// in memory, uploaded by `uploadProofsForFIR` once `/generate_fir` answers
  /// with a number.
  final List<EvidenceFile> proofs;

  /// What became of [proofs] once the record existed. Null until the FIR is
  /// filed; see [FirProofOutcome] for why a failure here does not fail the
  /// filing.
  final FirProofOutcome? proofOutcome;

  /// True when [draft] came back from storage rather than starting empty. Drives
  /// the one-time "draft restored" notice; dismissed, never re-shown.
  final bool restoredFromStorage;

  bool get isSubmitting => status == FirSubmissionStatus.submitting;
  bool get isFiled => status == FirSubmissionStatus.filed;

  FirFormState copyWith({
    bool? ready,
    int? epoch,
    FirDraft? draft,
    FirFormStep? step,
    FirSubmissionStatus? status,
    bool? showErrors,
    FirReceipt? receipt,
    List<EvidenceFile>? proofs,
    FirProofOutcome? proofOutcome,
    bool? restoredFromStorage,
    // Failure is cleared far more often than it is set, and `failure: null`
    // cannot express that through the usual `?? this.failure`. An explicit flag
    // keeps clearing honest instead of forcing a sentinel value.
    bool clearFailure = false,
    Failure? failure,
  }) {
    return FirFormState(
      ready: ready ?? this.ready,
      epoch: epoch ?? this.epoch,
      draft: draft ?? this.draft,
      step: step ?? this.step,
      status: status ?? this.status,
      showErrors: showErrors ?? this.showErrors,
      failure: clearFailure ? null : (failure ?? this.failure),
      receipt: receipt ?? this.receipt,
      proofs: proofs ?? this.proofs,
      proofOutcome: proofOutcome ?? this.proofOutcome,
      restoredFromStorage: restoredFromStorage ?? this.restoredFromStorage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirFormState &&
          other.ready == ready &&
          other.epoch == epoch &&
          other.draft == draft &&
          other.step == step &&
          other.status == status &&
          other.showErrors == showErrors &&
          other.failure == failure &&
          other.receipt == receipt &&
          // Identity, not deep equality: the list is replaced wholesale on
          // every add and remove, so a new list is always a new state and an
          // unchanged one is always the same instance.
          identical(other.proofs, proofs) &&
          other.proofOutcome == proofOutcome &&
          other.restoredFromStorage == restoredFromStorage;

  @override
  int get hashCode => Object.hash(
        ready,
        epoch,
        draft,
        step,
        status,
        showErrors,
        failure,
        receipt,
        Object.hashAll(proofs),
        proofOutcome,
        restoredFromStorage,
      );

  @override
  String toString() =>
      'FirFormState(${status.name}, ${step.name}, ${draft.firNo})';
}

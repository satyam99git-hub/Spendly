import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/form_dates.dart';
import '../../../evidence/domain/entities/evidence_file.dart';
import '../../../evidence/domain/entities/evidence_item.dart';
import '../../../evidence/presentation/controllers/evidence_providers.dart';
import '../../domain/entities/fir_draft.dart';
import '../../domain/entities/fir_proof_outcome.dart';
import '../../domain/repositories/fir_repository.dart';
import 'fir_form_state.dart';
import 'fir_history_providers.dart';
import 'fir_providers.dart';

// The feature's wiring moved to `fir_providers.dart` when the history screen
// became a second reader of it. Re-exported so every existing import of
// `firRepositoryProvider` from this file still resolves.
export 'fir_providers.dart';

/// The FIR form's state.
///
/// **Not `autoDispose`, and that is the point.** An officer taking a call
/// mid-form, or checking the station register for a free number, leaves the
/// screen and comes back to find the draft exactly as it was. Autodisposing here
/// would throw away the typing every time the screen was popped.
final firFormControllerProvider =
    NotifierProvider<FirFormController, FirFormState>(FirFormController.new);

/// Owns the in-progress FIR: its entries and the one submission that ends it.
///
/// Nothing else holds the draft. The screen's text boxes each own a
/// [TextEditingController] for the text being typed — a screen has to — but
/// every keystroke lands here on the same frame, so the draft is what gets
/// autosaved and submitted, and there is never a second version of an entry to
/// reconcile.
class FirFormController extends Notifier<FirFormState> {
  /// How long typing has to pause before the draft is written to storage.
  ///
  /// Saving on every keystroke would put a keystore write in the middle of the
  /// frame that renders it. A second is short enough that nothing meaningful is
  /// lost to a crash and long enough that a burst of typing is one write.
  static const _autosaveDelay = Duration(seconds: 1);

  Timer? _autosaveTimer;

  /// Whether anything has been typed since the last time the draft and the
  /// stored copy agreed.
  ///
  /// Without it, every flush writes — and the draft is never quite empty,
  /// because it is seeded with today's FIR date. Opening the form and backing
  /// straight out would leave a "draft" nobody wrote, and the next visit would
  /// greet the officer with "picked up where you left off" over a blank page.
  /// Discarding one and leaving would do the same, immediately after the
  /// officer asked for it to be gone.
  bool _dirty = false;

  @override
  FirFormState build() {
    ref.onDispose(() => _autosaveTimer?.cancel());
    _restore();
    return const FirFormState();
  }

  FirRepository get _repository => ref.read(firRepositoryProvider);
  SecureStorageService get _storage => ref.read(secureStorageProvider);

  // ---- draft lifecycle ------------------------------------------------------

  /// Reads back the saved draft, then opens the form.
  ///
  /// Failure here is not worth reporting: a draft that will not decode is
  /// indistinguishable to the officer from never having had one, and an error
  /// about local storage on the way into a form is noise they cannot act on. The
  /// unreadable value is dropped so it cannot fail again on the next launch.
  Future<void> _restore() async {
    FirDraft? saved;
    try {
      final raw = await _storage.read(StorageKeys.firDraft);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final draft = FirDraft.fromJson(decoded);
          if (!draft.isEmpty) saved = draft;
        }
      }
    } catch (_) {
      await _storage.delete(StorageKeys.firDraft);
    }

    // A restored draft already matches what is on disk, and a seeded one is not
    // worth putting there.
    _dirty = false;

    state = FirFormState(
      ready: true,
      epoch: state.epoch + 1,
      draft: saved ?? _seeded(),
      restoredFromStorage: saved != null,
    );
  }

  /// A new draft with the one entry the app can fill without guessing.
  ///
  /// The FIR date is the date of registration, which *is* now — an FIR is
  /// registered when it is written, and the year follows from it. Nothing else
  /// is pre-filled. A form that helpfully assumes a place or a date of
  /// occurrence records a value nobody stated, in a document read as a statement
  /// of fact.
  FirDraft _seeded() => FirDraft(firDate: FormDates.toWireDate(DateTime.now()));

  /// Applies an edit and schedules an autosave.
  ///
  /// Takes a transform rather than a whole draft so a caller cannot accidentally
  /// write a stale copy over a newer one.
  void edit(FirDraft Function(FirDraft draft) transform) {
    // Editing after filing would silently diverge from the record the server
    // holds. The screen closes itself on success, so this is a guard against a
    // late callback (a debounced text field, a dismissed picker), not a path
    // anyone can take deliberately.
    if (state.isFiled) return;

    final next = transform(state.draft);
    if (next == state.draft) return;

    _dirty = true;
    state = state.copyWith(draft: next, clearFailure: true);
    _scheduleSave();
  }

  /// Replaces the draft wholesale with one built from somewhere other than the
  /// officer's typing, and writes it straight out.
  ///
  /// This is how a citizen's complaint becomes the starting point for an FIR:
  /// the complaints inbox hands over the complainant, the narrative, the place
  /// and the date it already holds, so an officer converting a complaint types
  /// the FIR number and the sections rather than re-keying a statement somebody
  /// else has already written down.
  ///
  /// Deliberately not [edit]. That applies a change to whatever is there and is
  /// how the form reports keystrokes; this *discards* what is there, which is a
  /// destructive act. So it starts from a freshly seeded draft — today's FIR
  /// date, nothing else, exactly as [_seeded] defines it, which is what keeps
  /// that rule in this file rather than in a feature that knows nothing about
  /// FORM IF-1 — and bumps the epoch, so every text box on the form is torn down
  /// and rebuilt from the new values instead of keeping what it was built with.
  ///
  /// Saved immediately rather than on the autosave debounce, because the very
  /// next thing that happens is a navigation.
  ///
  /// **The caller is responsible for asking before this throws work away** — see
  /// [FirDraft.hasEnteredSomething], which is what the complaint detail screen
  /// checks before calling.
  Future<void> seedFrom(FirDraft Function(FirDraft seeded) transform) async {
    _autosaveTimer?.cancel();

    state = FirFormState(
      ready: true,
      epoch: state.epoch + 1,
      draft: transform(_seeded()),
    );

    _dirty = true;
    await _saveNow();
  }

  void _scheduleSave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _saveNow);
  }

  /// Writes the draft out immediately, cancelling any pending debounce.
  Future<void> _saveNow() async {
    _autosaveTimer?.cancel();
    if (!_dirty) return;

    final draft = state.draft;
    if (draft.isEmpty) {
      await _storage.delete(StorageKeys.firDraft);
      _dirty = false;
      return;
    }
    await _storage.write(StorageKeys.firDraft, jsonEncode(draft.toJson()));
    _dirty = false;
  }

  /// Flushes any pending autosave. Called when the screen goes away, so leaving
  /// is a save point regardless of when the last keystroke was.
  Future<void> flush() => _saveNow();

  /// Dismisses the "draft restored" notice. One-way: it is a statement about how
  /// this session started, and re-showing it after every edit would nag.
  void acknowledgeRestore() {
    if (!state.restoredFromStorage) return;
    state = state.copyWith(restoredFromStorage: false);
  }

  // ---- moving through the wizard --------------------------------------------

  /// Moves to the next step, or refuses and shows what is missing.
  ///
  /// Returns true when the move happened. The screen uses that to scroll back to
  /// the top; it does not need to know why a refusal happened, because the
  /// messages are already beside the boxes that caused it.
  ///
  /// **Validation is per step, and only of that step.** An officer on step 2
  /// with a blank narrative on step 4 is not doing anything wrong yet, and
  /// refusing Next for it would be refusing a page they have not reached.
  bool next() {
    if (state.isSubmitting || state.isFiled) return false;

    final blanks = state.draft.missingIn(state.step);
    if (blanks.isNotEmpty) {
      // Raised on the page that can fix it, rather than four pages later at
      // Submit — which is the whole reason the wizard validates per step.
      state = state.copyWith(showErrors: true, clearFailure: true);
      return false;
    }

    final next = state.step.next;
    if (next == null) return false;

    state = state.copyWith(
      step: next,
      // Cleared, so arriving on a page does not open with red left over from the
      // page before it.
      showErrors: false,
      clearFailure: true,
    );
    return true;
  }

  /// Moves back a step. Never validates: going back to correct something is the
  /// one action that must always work, and refusing it would trap the officer on
  /// a page they are trying to leave *because* it is wrong.
  bool back() {
    if (state.isSubmitting || state.isFiled) return false;

    final previous = state.step.previous;
    if (previous == null) return false;

    state = state.copyWith(step: previous, showErrors: false);
    return true;
  }

  /// Jumps straight to [step]. What the review's Edit links use.
  ///
  /// Unvalidated in both directions, for the same reason as [back]: the review
  /// exists to send an officer to the entry that is wrong, and a jump that
  /// checked the page being left would refuse to leave the review at all.
  void goTo(FirFormStep step) {
    if (state.isSubmitting || state.isFiled || step == state.step) return;
    state = state.copyWith(step: step, showErrors: false);
  }

  // ---- proof attachments ----------------------------------------------------

  /// Adds a file to be filed against the FIR once it exists.
  ///
  /// Held in state rather than uploaded now, because there is nothing to upload
  /// it against: `/upload-evidence` rejects an FIR number that is not yet in the
  /// register, which is the whole reason the website defers its own proof
  /// uploads until `/generate_fir` has answered.
  ///
  /// Duplicates by path are ignored. Picking the same photograph twice is a
  /// double-tap on the gallery, not an instruction to file it twice — and the
  /// server would silently overwrite the second against the first anyway.
  void attachProof(EvidenceFile file) {
    if (state.isSubmitting || state.isFiled) return;
    if (state.proofs.any((f) => f.path == file.path)) return;
    state = state.copyWith(proofs: [...state.proofs, file]);
  }

  /// Removes one attachment. Nothing has been sent yet, so this is free.
  void detachProof(EvidenceFile file) {
    if (state.isSubmitting || state.isFiled) return;
    state = state.copyWith(
      proofs: state.proofs.where((f) => f.path != file.path).toList(),
    );
  }

  // ---- submission -----------------------------------------------------------

  /// Files the FIR. Returns true when the server has it.
  ///
  /// The boolean is for the caller's control flow — the screen navigates to the
  /// receipt on true. It deliberately does not navigate itself: a controller
  /// that routes is a controller that cannot be tested without a navigator.
  ///
  /// An incomplete draft is refused here rather than by disabling the button. A
  /// greyed-out Submit gives an officer nothing to press and no reason why;
  /// pressing it and being shown the entries that are missing is the shorter
  /// path to a filed FIR.
  ///
  /// A refusal here also **moves the officer to the step that is wrong**. Submit
  /// is pressed from the review, where the offending box is not on screen — so
  /// flipping `showErrors` alone would put a message on a page nobody is
  /// looking at. In practice this is nearly unreachable, because Next validates
  /// each step on the way through; it is the backstop for the one path that
  /// skips them, an Edit link back into a step the officer then empties.
  ///
  /// **Never retried automatically.** A timeout is ambiguous — the record may
  /// have been written before the connection dropped — and a silent retry would
  /// either file a duplicate or come back with the server's "already exists"
  /// against an FIR the officer did successfully file.
  Future<bool> submit() async {
    if (state.isSubmitting || state.isFiled) return false;

    if (!state.draft.isSubmittable) {
      final firstBadStep = FirFormStep.entrySteps.firstWhere(
        (step) => state.draft.missingIn(step).isNotEmpty,
      );
      state = state.copyWith(
        step: firstBadStep,
        showErrors: true,
        clearFailure: true,
      );
      return false;
    }

    state = state.copyWith(
      status: FirSubmissionStatus.submitting,
      clearFailure: true,
    );

    try {
      final receipt = await _repository.register(state.draft);

      // The draft is now a record. Drop the saved copy before anything else can
      // fail, so a crash on the receipt screen cannot leave a filed FIR sitting
      // in storage waiting to be offered back as "unfinished".
      _autosaveTimer?.cancel();
      _dirty = false;
      await _storage.delete(StorageKeys.firDraft);

      // The history list in memory no longer matches police records. Invalidated
      // rather than appended to: the server owns the stored document — it fills
      // in `fir_id`, `created_at` and, when the app leaves them empty, the
      // sections — so re-reading it is the only way the list shows what was
      // actually filed rather than what was sent.
      ref.invalidate(firHistoryProvider);

      // The attachments, now that there is a number to file them against.
      //
      // After the state above would be wrong: the officer would sit on a
      // spinner while three photographs go up, over a record that is already
      // written. But before it, and the receipt cannot say what happened to
      // them — so the filing is completed here and the outcome carried with it.
      final proofs = await _fileProofs(receipt.firNo);

      state = state.copyWith(
        status: FirSubmissionStatus.filed,
        receipt: receipt,
        proofOutcome: proofs,
        clearFailure: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: FirSubmissionStatus.editing,
        failure: ErrorMapper.map(error, context: 'generate_fir'),
      );
      return false;
    }
  }

  /// Clears a failure once its screen has shown it.
  void clearFailure() {
    if (state.failure == null) return;
    state = state.copyWith(clearFailure: true);
  }

  // ---- reset ----------------------------------------------------------------

  /// Throws the draft away and starts clean.
  ///
  /// Used by "Discard draft", and by the receipt screen on the way out — a filed
  /// FIR must not be the starting point for the next one, or the officer
  /// inherits a complainant and a narrative belonging to a different case.
  /// Files each attachment against the FIR just registered, and reports what
  /// happened to each.
  ///
  /// **Never throws, and never fails the filing.** The record is written by the
  /// time this runs; an upload that fails is a file still on the handset, which
  /// the officer can add from the locker against the number they now have. See
  /// [FirProofOutcome].
  ///
  /// One at a time rather than in parallel, matching the website's own loop.
  /// A station handset on a rural link uploading four photographs at once gets
  /// four timeouts instead of two files.
  Future<FirProofOutcome> _fileProofs(String firNo) async {
    if (state.proofs.isEmpty) return const FirProofOutcome();

    final filed = <EvidenceItem>[];
    final failed = <({String name, String reason})>[];

    for (final file in state.proofs) {
      try {
        filed.add(
          await ref
              .read(evidenceRepositoryProvider)
              .upload(firNo: firNo, file: file),
        );
      } catch (error) {
        final failure = ErrorMapper.map(error, context: 'upload-evidence');
        failed.add((name: file.name, reason: failure.message));
      }
    }

    // The locker's list is now out of date on this device.
    if (filed.isNotEmpty) ref.invalidate(allEvidenceProvider);

    return FirProofOutcome(filed: filed, failed: failed);
  }

  Future<void> reset() async {
    _autosaveTimer?.cancel();
    _dirty = false;
    state = FirFormState(
      ready: true,
      epoch: state.epoch + 1,
      draft: _seeded(),
    );
    await _storage.delete(StorageKeys.firDraft);
  }
}

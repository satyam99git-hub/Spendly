import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import 'evidence_providers.dart';

/// Whether the locker is open, and what the last attempt did.
class EvidenceLockState {
  const EvidenceLockState({
    this.unlocked = false,
    this.verifying = false,
    this.failedAttempts = 0,
    this.error,
  });

  final bool unlocked;

  /// A PIN is with the server and no answer has come back yet.
  ///
  /// The check used to be a string comparison and finished within the frame, so
  /// there was nothing to show. It is a round trip now, and on a station
  /// handset over a slow link an Unlock button that looks inert is one an
  /// officer taps four more times.
  final bool verifying;

  /// Consecutive wrong PINs. Reset by a correct one.
  ///
  /// Shown back to the officer from the second failure, because on a shared
  /// station handset "wrong password" twice in a row usually means the PIN was
  /// changed and nobody said so — and a count is the difference between trying a
  /// third time and going to ask.
  final int failedAttempts;

  /// The message under the PIN box. Null when nothing has been tried yet, or
  /// once the officer starts typing again.
  final String? error;

  EvidenceLockState copyWith({
    bool? unlocked,
    bool? verifying,
    int? failedAttempts,
    String? error,
    bool clearError = false,
  }) {
    return EvidenceLockState(
      unlocked: unlocked ?? this.unlocked,
      verifying: verifying ?? this.verifying,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceLockState &&
          other.unlocked == unlocked &&
          other.verifying == verifying &&
          other.failedAttempts == failedAttempts &&
          other.error == error;

  @override
  int get hashCode =>
      Object.hash(unlocked, verifying, failedAttempts, error);
}

/// The locker's PIN gate.
///
/// ---------------------------------------------------------------------------
/// THIS IS NOT A SECURITY CONTROL, AND SAYING SO IS PART OF THE DESIGN
///
/// The PIN goes to `POST /verify-locker-access`, which is the same check the
/// website's console makes. It used to be compared here in Dart against a
/// constant of the app's own, and that was the bug: the handset and the console
/// were two doors onto one locker that opened to two different strings, so an
/// officer given the station PIN by a colleague working on the website could
/// not get in on the phone. Whatever the PIN is, there is now one of it.
///
/// Neither arrangement protects anything. `/upload-evidence`, `/api/evidence`,
/// `/get-all-evidence` and `/evidence-file/...` have **no session check of any
/// kind** — anyone who can reach the server can read or write the locker without
/// ever seeing a PIN. Asking the server bought parity with the website, not
/// safety, and the gate is still only for what it always was: stopping a phone
/// left unlocked on a desk from showing a complainant's evidence to whoever
/// picks it up, in a screen an officer reaches by mis-tapping a tab.
///
/// The real fix is a session check on those four routes, server-side. Until then
/// this is a curtain, and the code should not pretend otherwise.
///
/// ## Failing closed
///
/// A PIN the server never answered is not a wrong PIN, and the two must not read
/// the same. An unreachable server leaves the locker shut and says it could not
/// ask — reporting "Wrong PIN" would send an officer to the station in-charge
/// over a dropped connection, and opening anyway would make the gate a
/// decoration that a flight-mode toggle removes.
/// ---------------------------------------------------------------------------
///
/// State is in memory only — never written to storage — so the locker relocks on
/// every cold start.
///
/// It is closed again by three things, none of which live in this file:
///
///   - **leaving the Evidence tab** — `PoliceDashboardScreen._selectTab`, which
///     is what makes the PIN a gate on every visit rather than once a shift;
///   - **signing out** — wired in `app_router`, with the rest of the auth-driven
///     resets;
///   - **the padlock in the app bar**, for handing the phone to somebody without
///     leaving the screen.
final evidenceLockControllerProvider =
    NotifierProvider<EvidenceLockController, EvidenceLockState>(
  EvidenceLockController.new,
);

class EvidenceLockController extends Notifier<EvidenceLockState> {
  @override
  EvidenceLockState build() => const EvidenceLockState();

  /// Asks the server whether [entered] opens the locker, and returns what it
  /// said.
  ///
  /// Sent exactly as typed — not trimmed, not case-folded. A PIN is a string the
  /// station was given, the server compares it strictly, and quietly accepting
  /// `india@123 ` here would teach people a value the website rejects.
  ///
  /// Concurrent taps are dropped rather than queued: the officer has one PIN box
  /// and a second answer for the same one cannot say anything different.
  Future<bool> unlock(String entered) async {
    if (state.verifying) return false;
    state = state.copyWith(verifying: true, clearError: true);

    final bool accepted;
    try {
      accepted = await ref.read(evidenceRepositoryProvider).verifyPin(entered);
    } on Failure catch (failure) {
      // Could not ask. Say so instead of blaming the PIN, and leave the attempt
      // count alone — nothing about it was rejected.
      state = state.copyWith(
        unlocked: false,
        verifying: false,
        error: failure.message,
      );
      return false;
    }

    if (accepted) {
      state = const EvidenceLockState(unlocked: true);
      return true;
    }

    final attempts = state.failedAttempts + 1;
    state = state.copyWith(
      unlocked: false,
      verifying: false,
      failedAttempts: attempts,
      error: attempts >= 2
          ? 'Wrong PIN. $attempts failed attempts — check with the station '
              'in-charge before trying again.'
          : 'Wrong PIN.',
    );
    return false;
  }

  /// Clears the message as soon as the officer starts correcting the entry.
  /// The attempt count deliberately survives: it is a fact about this session,
  /// not about the current keystroke.
  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(clearError: true);
  }

  /// Closes the locker again. Offered as an explicit action, because an officer
  /// handing their phone to someone should not have to sign out of the whole app
  /// to put the evidence away.
  void lock() => state = const EvidenceLockState();
}

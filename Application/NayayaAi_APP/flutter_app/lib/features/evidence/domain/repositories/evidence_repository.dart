import '../entities/evidence_file.dart';
import '../entities/evidence_item.dart';

/// What the evidence locker needs from the outside world.
///
/// Every method throws `Failure` and nothing else — no `DioException` crosses
/// this line, so a controller can render `failure.message` without knowing that
/// HTTP exists.
///
/// **The PIN is here now.** It used to be compared in Dart against a constant of
/// the app's own, which meant the handset and the website's console opened the
/// same locker with two different strings. [verifyPin] asks the server, which is
/// what the website does and therefore what "the same PIN works in both" means.
///
/// It is still not a security control. `/upload-evidence`, `/api/evidence`,
/// `/get-all-evidence` and `/evidence-file` have no session check at all, so
/// anything the gate protects is protected from the officer's own mis-taps, not
/// from an attacker. Moving the comparison to the server bought parity, not
/// safety; the fix for safety is a session check on those four routes.
abstract interface class EvidenceRepository {
  /// Whether [pin] opens the locker, as `POST /verify-locker-access` judges it.
  ///
  /// `false` is a wrong PIN and nothing more. A server that cannot be reached,
  /// or that answers something other than accept or reject, throws — the gate
  /// must not open on a network error, and must not silently report the PIN
  /// wrong when it never got to ask.
  Future<bool> verifyPin(String pin);

  /// Everything in the locker, newest FIR grouping order unspecified by the
  /// server.
  ///
  /// Built on `GET /get-all-evidence`, which returns filenames only, so every
  /// item comes back with an empty `uploadedAt` and a category inferred from the
  /// extension. Call [forFir] when the timestamp matters.
  Future<List<EvidenceItem>> all();

  /// The files filed against one FIR, with their server-side metadata. Answers
  /// an empty list — not a failure — for an FIR that has none, and for one that
  /// does not exist.
  Future<List<EvidenceItem>> forFir(String firNo);

  /// Uploads [file] against an existing FIR.
  ///
  /// Rejected with a [ValidationFailure] carrying the server's own wording when
  /// `firNo` names no FIR. Not idempotent in the useful direction either: the
  /// server overwrites a file of the same name in the same FIR folder without
  /// saying so, so the returned item's filename is the one to trust.
  Future<EvidenceItem> upload({
    required String firNo,
    required EvidenceFile file,
  });

  /// Records that someone looked at an item.
  ///
  /// Fire-and-forget by contract: it must never throw, and a caller must never
  /// wait on it before showing the file. A locker that refuses to open because
  /// its audit log is down is a locker that gets worked around.
  Future<void> logAccess({
    required String firNo,
    required String filename,
    required String action,
  });
}

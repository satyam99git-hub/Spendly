/// How an FIR number is written when it needs the word in front of it.
///
/// In `core/` rather than with the FIR feature because two features label the
/// same value: the history list and the record viewer, and the evidence locker,
/// which groups files under the FIR they were filed against. Two copies of this
/// rule is how the same record ends up reading `FIR 41/2026` on one screen and
/// `FIR FIR 41/2026` on the next.
abstract final class FirNumber {
  const FirNumber._();

  /// `41/2026` → `FIR 41/2026`, and `FIR001` → `FIR001`, unchanged.
  ///
  /// Stations number their FIRs both ways. `41/2026` needs the label to read as
  /// anything at all; `FIR001` already carries it, and prefixing anyway gives
  /// "FIR FIR001" — which looks like a bug on every row of a list and in the
  /// title bar above every record.
  ///
  /// Matched case-insensitively and on the prefix only: `fir001` is the same
  /// number typed by someone in a hurry, and `FIRE_DEPT_02` — were it ever an
  /// FIR number — is better off unlabelled than double-labelled.
  static String label(String firNo) {
    final trimmed = firNo.trim();
    if (trimmed.isEmpty) return 'FIR';
    return trimmed.toUpperCase().startsWith('FIR') ? trimmed : 'FIR $trimmed';
  }
}

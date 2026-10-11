import '../../../evidence/domain/entities/evidence_item.dart';

/// What became of the files attached while the FIR was being written.
///
/// ---------------------------------------------------------------------------
/// WHY A FILED FIR WITH A FAILED UPLOAD IS A SUCCESS, NOT A FAILURE
///
/// The two halves are not the same kind of act. `POST /generate_fir` writes the
/// record; each `POST /upload-evidence` afterwards files one photograph against
/// it. The record is what makes the offence registered, and it exists the
/// moment the first call returns — so an upload that fails afterwards must not
/// be reported as "filing failed", and must never make the app retry the
/// filing. That would put a second FIR in the register.
///
/// So this rides on the receipt: the FIR is filed, and here is what happened to
/// the attachments. Whatever did not go up is still on the handset and can be
/// added from the locker's Add screen against the number the officer now has.
/// ---------------------------------------------------------------------------
class FirProofOutcome {
  const FirProofOutcome({
    this.filed = const [],
    this.failed = const [],
  });

  /// The items the server confirmed, with the names it actually stored — which
  /// `secure_filename` may have rewritten, so these are read back rather than
  /// assumed.
  final List<EvidenceItem> filed;

  /// The name of each file that did not go up, with the reason, in the order
  /// they were attempted.
  final List<({String name, String reason})> failed;

  int get attempted => filed.length + failed.length;

  bool get isEmpty => attempted == 0;
  bool get allFiled => failed.isEmpty && filed.isNotEmpty;
  bool get hasFailures => failed.isNotEmpty;

  /// One line for the receipt.
  ///
  /// Counts rather than a list, because the receipt already lists the filenames
  /// underneath and a sentence that repeats them reads as two different facts.
  String get summary {
    if (isEmpty) return 'No files were attached.';
    if (allFiled) {
      return filed.length == 1
          ? '1 file filed against this FIR.'
          : '${filed.length} files filed against this FIR.';
    }
    if (filed.isEmpty) {
      return failed.length == 1
          ? 'The attached file could not be filed. The FIR is registered.'
          : 'None of the ${failed.length} attached files could be filed. '
              'The FIR is registered.';
    }
    return '${filed.length} of $attempted files filed. The FIR is registered.';
  }

  @override
  String toString() => 'FirProofOutcome(${filed.length} filed, '
      '${failed.length} failed)';
}

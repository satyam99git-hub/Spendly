import '../entities/fir_draft.dart';
import '../entities/fir_receipt.dart';
import '../entities/fir_record.dart';
import '../entities/section_suggestion.dart';

/// What the FIR feature needs from the outside world.
///
/// Every method throws [Failure] and nothing else — no [DioException] crosses
/// this line, so a controller can render `failure.message` without knowing that
/// HTTP exists.
abstract interface class FirRepository {
  /// Files the FIR.
  ///
  /// **Not idempotent, and the server is what makes it so:** a second call with
  /// the same `fir_no` is rejected with HTTP 400, which arrives as a
  /// [ValidationFailure] carrying the server's own "FIR number X already
  /// exists". A retry after a *timeout* is therefore ambiguous — the record may
  /// well have been written before the connection dropped — which is why the
  /// controller never retries automatically and the screen tells the officer to
  /// check FIR history before filing again.
  Future<FirReceipt> register(FirDraft draft);

  /// Every FIR in police records, newest first.
  ///
  /// The whole collection, because the server has no paging, no filter and no
  /// sort — `GET /api/fir-records` answers with all of it or with nothing. The
  /// ordering is applied here rather than on screen so every reader agrees on
  /// what "newest" means; see the implementation for what happens to a record
  /// with no usable timestamp.
  ///
  /// Answers an empty list, not a failure, when no FIR has ever been filed.
  Future<List<FirRecord>> history();

  /// One stored FIR, by its number.
  ///
  /// Throws a [ValidationFailure] carrying the server's own "FIR record X not
  /// found" when there is none — which is the honest answer for a viewer opened
  /// on a record that has since been removed, or on a number typed by hand.
  Future<FirRecord> record(String firNo);

  /// Downloads the PDF the server generated for [firNo] and writes it to
  /// [savePath].
  ///
  /// The caller supplies the path — the repository fetches bytes and does not
  /// decide where they live. Choosing the location, and opening the file
  /// afterwards, both need platform channels and belong to `FirPdfStore`.
  ///
  /// Throws a [ValidationFailure] when the station server has no PDF for this
  /// FIR, which is common enough to be a normal branch rather than an error: the
  /// `generated_firs/` folder is local to whichever machine filed the record.
  Future<void> downloadPdf({required String firNo, required String savePath});

  /// Acts and sections the server thinks [narrative] discloses, with a reason
  /// for each.
  ///
  /// Advisory in the strongest sense: nothing here is filed, and the form is
  /// free to ignore every word of it. `/generate_fir` still writes whatever the
  /// officer ended up with.
  ///
  /// Answers an empty [SectionSuggestions] rather than throwing when the
  /// narrative discloses no offence, or is too short to work from — both are
  /// ordinary outcomes rather than errors. Throws only on transport failure, or
  /// on the 403 a non-police account gets, which unlike the FIR form's own gate
  /// is enforced server-side.
  Future<SectionSuggestions> suggestSections(String narrative);

  /// The district list behind the step-1 picker. Sorted by the server.
  Future<List<String>> districts();

  /// Stations for one district. Never empty: an unrecognised district gets a
  /// single synthesised `"<district> PS"` back rather than a 404.
  Future<List<String>> policeStations(String district);

  /// The eight act codes the section tables are keyed by.
  Future<List<String>> acts();
}

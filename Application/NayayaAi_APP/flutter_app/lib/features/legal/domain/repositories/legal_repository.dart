import '../entities/legal_section.dart';
import '../entities/outcome_finding.dart';

/// What the law library and the two AI surfaces need from the server.
///
/// Every method throws `Failure` and nothing else, like every other repository
/// here — no `DioException` crosses this line.
///
/// **Nothing is cached.** `IndiaLaw.db` is static and caching it would be safe,
/// but the library is opened to check one section and closed again; holding
/// 575 IPC rows in memory for the rest of the shift buys nothing an officer can
/// feel. If that changes, the place to add it is here and not in the data
/// source.
abstract interface class LegalRepository {
  /// The eight act codes the section tables are keyed by, in the server's own
  /// order: `IPC`, `CRPC`, `NIA`, `IEA`, `HMA`, `CPC`, `IDA`, `MVA`.
  ///
  /// Shared with the FIR form's act picker, which reads the same endpoint —
  /// they are the same eight, and two lists that could disagree would let an
  /// officer file an FIR under an act the library cannot open.
  Future<List<String>> acts();

  /// One page of [act]'s sections, optionally narrowed by [search].
  ///
  /// [search] matches the number, the title and the text. Rejected with a
  /// [ValidationFailure] carrying the server's "Invalid act" for anything not
  /// in [acts].
  Future<LegalSectionPage> sections(
    String act, {
    String search = '',
    int page = 1,
    int limit = 20,
  });

  /// One section in full. A 404 becomes a [ValidationFailure] with the server's
  /// own wording, because "there is no Section 9999 of the IPC" is an answer
  /// rather than a fault.
  Future<LegalSection> section(String act, String sectionNo);

  /// Sections matching [query] across all eight acts.
  ///
  /// Each hit carries no description — see [LegalSection.isSummary] — so
  /// opening one costs a [section] call.
  Future<List<LegalSection>> search(String query);

  /// The server's prose answer to a legal question. Never empty: a question it
  /// cannot match comes back as a sentence saying so.
  Future<String> ask(String question);

  /// Sections the outcome search matched for a described situation, best first.
  ///
  /// Empty when nothing matched, which is an answer and not a failure.
  Future<List<OutcomeFinding>> predictOutcome(String situation);
}

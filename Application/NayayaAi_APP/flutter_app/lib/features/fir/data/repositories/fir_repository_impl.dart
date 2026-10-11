import '../../domain/entities/fir_draft.dart';
import '../../domain/entities/fir_receipt.dart';
import '../../domain/entities/fir_record.dart';
import '../../domain/entities/section_suggestion.dart';
import '../../domain/repositories/fir_repository.dart';
import '../datasources/fir_remote_data_source.dart';
import '../models/fir_models.dart';

/// The FIR repository over the live server.
///
/// Thin by design. There is no caching layer and no offline queue: an FIR is a
/// statutory record whose number the server alone can accept or reject as a
/// duplicate, so "filed" has to mean the server said so. Anything that stored
/// FIRs locally and drained them later would report success for records that
/// might never be accepted, which is a worse failure than a visible one.
///
/// The lookups are not cached here either — see `fir_lookup_providers.dart`,
/// where Riverpod already keeps each answer for as long as the app is running.
class FirRepositoryImpl implements FirRepository {
  const FirRepositoryImpl({required FirRemoteDataSource remote})
      : _remote = remote;

  final FirRemoteDataSource _remote;

  @override
  Future<FirReceipt> register(FirDraft draft) =>
      _remote.register(FirSubmission(draft));

  @override
  Future<List<FirRecord>> history() async {
    final records = await _remote.history();
    return _newestFirst(records);
  }

  @override
  Future<FirRecord> record(String firNo) => _remote.record(firNo.trim());

  @override
  Future<SectionSuggestions> suggestSections(String narrative) async {
    final text = narrative.trim();
    // The server declines anything under 20 characters with a message, and a
    // round trip to be told the box is nearly empty is a round trip wasted.
    // Answered here instead, with the server's own sentence: an empty result
    // with nothing to read would show the officer a dead end where the server
    // would have given them an instruction.
    if (text.length < 20) {
      return const SectionSuggestions(
        message: 'Write a little more of the narrative first.',
      );
    }
    return _remote.suggestSections(text);
  }

  @override
  Future<void> downloadPdf({
    required String firNo,
    required String savePath,
  }) =>
      _remote.downloadPdf(firNo: firNo.trim(), savePath: savePath);

  /// Newest first, and sorted here rather than on screen so every reader of the
  /// history agrees on the order.
  ///
  /// `GET /api/fir-records` returns the collection in insertion order and takes
  /// no `sort` parameter, so this is the only place it can happen at all.
  ///
  /// The ordering is by `created_at` — when the server stored the record — not
  /// by the FIR date on the form. The two differ on a back-dated filing, and a
  /// list an officer scans for "the one I filed this morning" is asking about
  /// the former. Records whose timestamp is missing or unreadable sort to the
  /// bottom rather than to the top: an unparseable value is not evidence of
  /// recency, and floating one to the head of the list would make it the first
  /// thing seen every time.
  ///
  /// Ties break on the FIR number, descending, so the order is stable between
  /// two calls instead of following whatever Mongo happened to return.
  static List<FirRecord> _newestFirst(List<FirRecord> records) {
    final sorted = [...records];
    sorted.sort((a, b) {
      final left = a.filedAt;
      final right = b.filedAt;

      if (left != null && right != null && left != right) {
        return right.compareTo(left);
      }
      if (left == null && right != null) return 1;
      if (left != null && right == null) return -1;

      return b.firNo.toLowerCase().compareTo(a.firNo.toLowerCase());
    });
    return sorted;
  }

  @override
  Future<List<String>> districts() => _remote.districts();

  @override
  Future<List<String>> policeStations(String district) =>
      _remote.policeStations(district);

  @override
  Future<List<String>> acts() => _remote.acts();
}

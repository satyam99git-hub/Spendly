import '../../domain/entities/legal_section.dart';
import '../../domain/entities/outcome_finding.dart';
import '../../domain/repositories/legal_repository.dart';
import '../datasources/legal_remote_data_source.dart';

/// The law library over the live server.
///
/// Thin, and deliberately so: `IndiaLaw.db` is read-only and the server already
/// paginates, searches and sorts, so there is nothing left for a repository to
/// arrange. What it does do is refuse queries the server would only answer with
/// an error — a blank search, a blank question — because a round trip to be
/// told the box is empty is a round trip an officer waits for.
class LegalRepositoryImpl implements LegalRepository {
  const LegalRepositoryImpl({required LegalRemoteDataSource remote})
      : _remote = remote;

  final LegalRemoteDataSource _remote;

  @override
  Future<List<String>> acts() => _remote.acts();

  @override
  Future<LegalSectionPage> sections(
    String act, {
    String search = '',
    int page = 1,
    int limit = 20,
  }) =>
      _remote.sections(
        act.trim(),
        search: search.trim(),
        // The handler floors the page at 1 itself; doing it here too means the
        // returned page number always matches the one that was asked for.
        page: page < 1 ? 1 : page,
        limit: limit,
      );

  @override
  Future<LegalSection> section(String act, String sectionNo) =>
      _remote.section(act.trim(), sectionNo.trim());

  @override
  Future<List<LegalSection>> search(String query) {
    final needle = query.trim();
    // The endpoint answers a blank `q` with the whole table, which is not what
    // an empty search box means.
    if (needle.isEmpty) return Future.value(const []);
    return _remote.search(needle);
  }

  @override
  Future<String> ask(String question) => _remote.ask(question.trim());

  @override
  Future<List<OutcomeFinding>> predictOutcome(String situation) =>
      _remote.predictOutcome(situation.trim());
}

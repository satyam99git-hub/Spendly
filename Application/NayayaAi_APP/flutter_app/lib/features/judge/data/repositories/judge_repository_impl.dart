import '../../domain/repositories/judge_repository.dart';
import '../datasources/judge_remote_data_source.dart';
import '../models/judge_models.dart';

class JudgeRepositoryImpl implements JudgeRepository {
  const JudgeRepositoryImpl({required JudgeRemoteDataSource remote})
      : _remote = remote;

  final JudgeRemoteDataSource _remote;

  @override
  Future<List<DocketEntry>> docket({String status = '', String urgency = ''}) =>
      _remote.docket(status: status, urgency: urgency);

  @override
  Future<void> createEntry(DocketPayload payload) =>
      _remote.createEntry(payload);

  @override
  Future<void> updateEntry(int id, DocketPayload payload) =>
      _remote.updateEntry(id, payload);

  @override
  Future<void> deleteEntry(int id) => _remote.deleteEntry(id);

  @override
  Future<List<JudgeFir>> firOptions() => _remote.firOptions();

  @override
  Future<JudgeFir> fir(String caseId) => _remote.fir(caseId);

  @override
  Future<PrecedentResearch> research(String query) => _remote.research(query);
}

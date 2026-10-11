import '../../domain/repositories/lawyer_repository.dart';
import '../datasources/lawyer_remote_data_source.dart';
import '../models/lawyer_models.dart';

class LawyerRepositoryImpl implements LawyerRepository {
  const LawyerRepositoryImpl({required LawyerRemoteDataSource remote})
      : _remote = remote;

  final LawyerRemoteDataSource _remote;

  @override
  Future<List<LawyerCase>> cases() => _remote.cases();

  /// `input.value.trim()` (line 1481).
  @override
  Future<void> claim(String firNo) => _remote.claim(firNo.trim());

  @override
  Future<LawyerCase> caseDetail(String firNo) => _remote.caseDetail(firNo);

  @override
  Future<void> updateStatus(String firNo, String status) =>
      _remote.updateStatus(firNo, status);

  @override
  Future<void> setClientVisibility(
    String firNo, {
    required bool visible,
    required String note,
  }) =>
      _remote.setClientVisibility(firNo, visible: visible, note: note);

  @override
  Future<List<CaseDocument>> documents(String firNo) =>
      _remote.documents(firNo);

  @override
  Future<List<CaseHearing>> hearings(String firNo) => _remote.hearings(firNo);

  @override
  Future<void> addHearing(String firNo, String date, String note) =>
      _remote.addHearing(firNo, date, note);

  @override
  Future<List<CaseDeadline>> deadlines(String firNo) =>
      _remote.deadlines(firNo);

  @override
  Future<void> addDeadline(
    String firNo, {
    required String deadlineType,
    required String dueDate,
    required String note,
  }) =>
      _remote.addDeadline(
        firNo,
        deadlineType: deadlineType,
        dueDate: dueDate,
        note: note,
      );

  @override
  Future<void> setDeadlineCompleted(
    String firNo,
    Object? deadlineId, {
    required bool completed,
  }) =>
      _remote.setDeadlineCompleted(firNo, deadlineId, completed: completed);

  @override
  Future<void> deleteDeadline(String firNo, Object? deadlineId) =>
      _remote.deleteDeadline(firNo, deadlineId);

  @override
  Future<List<CaseDraft>> drafts(String firNo) => _remote.drafts(firNo);

  @override
  Future<void> saveDraft(String firNo, String kind, String content) =>
      _remote.saveDraft(firNo, kind, content);

  @override
  Future<void> deleteDraft(String firNo, Object? draftId) =>
      _remote.deleteDraft(firNo, draftId);

  @override
  Future<String> generateDraft({required bool bail, required String prompt}) =>
      _remote.generateDraft(bail: bail, prompt: prompt);

  @override
  Future<String?> findPrecedents(String query) => _remote.findPrecedents(query);

  @override
  Future<List<CaseDraft>> allDrafts() => _remote.allDrafts();

  @override
  Future<List<CaseDeadline>> upcomingDeadlines() => _remote.upcomingDeadlines();

  @override
  Future<LawyerProfile?> profile() => _remote.profile();

  @override
  Future<void> saveProfile(LawyerProfileUpdate update) =>
      _remote.saveProfile(update);

  @override
  Future<String> uploadPhoto({
    required String path,
    required String filename,
  }) =>
      _remote.uploadPhoto(path: path, filename: filename);
}

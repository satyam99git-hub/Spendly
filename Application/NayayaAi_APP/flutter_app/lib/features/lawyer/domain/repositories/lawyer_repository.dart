import '../../data/models/lawyer_models.dart';

/// Everything the Lawyer Portal asks the server. Each method behaves as the
/// matching function in `lawyer_dashboard.html` does — see
/// `LawyerRemoteDataSource` for the reply handling behind each.
///
/// Failures are either a `Failure` carrying the page's own words, or a
/// `LawyerSilentFailure` for the cases the page only logs.
abstract interface class LawyerRepository {
  Future<List<LawyerCase>> cases();
  Future<void> claim(String firNo);

  Future<LawyerCase> caseDetail(String firNo);
  Future<void> updateStatus(String firNo, String status);
  Future<void> setClientVisibility(
    String firNo, {
    required bool visible,
    required String note,
  });

  Future<List<CaseDocument>> documents(String firNo);

  Future<List<CaseHearing>> hearings(String firNo);
  Future<void> addHearing(String firNo, String date, String note);

  Future<List<CaseDeadline>> deadlines(String firNo);
  Future<void> addDeadline(
    String firNo, {
    required String deadlineType,
    required String dueDate,
    required String note,
  });
  Future<void> setDeadlineCompleted(
    String firNo,
    Object? deadlineId, {
    required bool completed,
  });
  Future<void> deleteDeadline(String firNo, Object? deadlineId);

  Future<List<CaseDraft>> drafts(String firNo);
  Future<void> saveDraft(String firNo, String kind, String content);
  Future<void> deleteDraft(String firNo, Object? draftId);

  Future<String> generateDraft({required bool bail, required String prompt});
  Future<String?> findPrecedents(String query);

  Future<List<CaseDraft>> allDrafts();
  Future<List<CaseDeadline>> upcomingDeadlines();

  Future<LawyerProfile?> profile();
  Future<void> saveProfile(LawyerProfileUpdate update);
  Future<String> uploadPhoto({required String path, required String filename});
}

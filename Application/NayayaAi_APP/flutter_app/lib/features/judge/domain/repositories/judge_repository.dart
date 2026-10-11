import '../../data/models/judge_models.dart';

/// Everything the Judge Portal asks the server, each call behaving as the
/// matching function in `judge_dashboard.html` does.
///
/// Every method throws a `Failure` whose message is safe to show. Where the page
/// shows a sentence of its own for a failure, that sentence is the message.
abstract interface class JudgeRepository {
  /// `GET /judge/docket`, with the page's two filters when set
  /// (`loadDocket`, JD:582-594). Empty strings mean "no filter".
  Future<List<DocketEntry>> docket({String status = '', String urgency = ''});

  /// `POST /judge/docket` (JD:749-759).
  Future<void> createEntry(DocketPayload payload);

  /// `PUT /judge/docket/<id>` (JD:749-759).
  Future<void> updateEntry(int id, DocketPayload payload);

  /// `DELETE /judge/docket/<id>` (`deleteEntry`, JD:691-695).
  Future<void> deleteEntry(int id);

  /// `GET /api/fir-records` in the server's order — the hearing modal's
  /// suggestions (`loadFirOptions`, JD:500-507).
  Future<List<JudgeFir>> firOptions();

  /// `GET /api/fir-records/<case_id>` — the workspace's FIR details (JD:822).
  Future<JudgeFir> fir(String caseId);

  /// `POST /judge/precedents` (JD:1160-1188).
  Future<PrecedentResearch> research(String query);
}

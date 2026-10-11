import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/judge/data/models/judge_models.dart';
import 'package:nayaya_app/features/judge/domain/repositories/judge_repository.dart';

/// A `case_docket` row as `GET /judge/docket` returns it.
Map<String, dynamic> docketRow({
  int id = 1,
  String caseId = 'FIR001',
  String hearingDate = '2099-01-15 10:30',
  String? caseType = 'Criminal',
  String urgency = 'normal',
  String status = 'scheduled',
  String? remarks = 'First listing',
  String judgeId = 'JUDGE_ID',
}) =>
    {
      'id': id,
      'judge_id': judgeId,
      'case_id': caseId,
      'hearing_date': hearingDate,
      'case_type': caseType,
      'urgency': urgency,
      'status': status,
      'remarks': remarks,
    };

/// A `firs` row with the fields the judge page reads.
Map<String, dynamic> judgeFirRow({
  String firNo = 'FIR001',
  String? complainant = 'Asha Rao',
  String? dist = 'Pune',
  String? ps = 'Shivajinagar PS',
  String? sections = 'BNS 303',
  String? status = 'Saved to Police Records',
}) =>
    {
      'fir_no': firNo,
      'complainant_name': complainant,
      'dist': dist,
      'ps': ps,
      'act_sections': sections,
      'status': status,
    };

/// Stands in for every judge endpoint, behaving like the server where the
/// behaviour matters to a screen: filters filter, POST stores `scheduled`
/// whatever it was sent, PUT ignores `case_id`, DELETE removes.
class FakeJudgeRepository implements JudgeRepository {
  FakeJudgeRepository({
    List<Map<String, dynamic>>? docketRows,
    List<Map<String, dynamic>>? firRows,
  })  : rows = docketRows ?? [docketRow()],
        firs = firRows ?? [judgeFirRow()];

  List<Map<String, dynamic>> rows;
  List<Map<String, dynamic>> firs;

  Object? docketFailure;
  Object? saveFailure;
  Object? deleteFailure;
  Object? firOptionsFailure;
  Object? firFailure;
  Object? researchFailure;

  /// Returned by [research].
  PrecedentResearch researchResult = PrecedentResearch.fromJson(const {
    'current_law': null,
    'directly_relevant': [],
    'related_authorities': [],
    'principles': [],
    'statutory_sections': [],
    'synthesis': null,
    'sources': [],
    'no_result_notice': null,
    'ai_notice': null,
  });

  /// Held open by a test to observe in-flight states.
  Future<void>? gate;

  // ---- call log ------------------------------------------------------------

  final List<({String status, String urgency})> docketCalls = [];
  final List<DocketPayload> created = [];
  final List<(int, DocketPayload)> updated = [];
  final List<int> deleted = [];
  final List<String> firLookups = [];
  final List<String> researchQueries = [];
  int firOptionsCalls = 0;

  int _nextId = 100;

  Future<void> _wait() async {
    final g = gate;
    if (g != null) await g;
  }

  @override
  Future<List<DocketEntry>> docket({
    String status = '',
    String urgency = '',
  }) async {
    docketCalls.add((status: status, urgency: urgency));
    await _wait();
    final failure = docketFailure;
    if (failure != null) throw failure;
    return [
      for (final r in rows)
        if ((status.isEmpty || r['status'] == status) &&
            (urgency.isEmpty || r['urgency'] == urgency))
          DocketEntry.fromJson(r),
    ];
  }

  @override
  Future<void> createEntry(DocketPayload payload) async {
    created.add(payload);
    await _wait();
    final failure = saveFailure;
    if (failure != null) throw failure;
    rows = [
      ...rows,
      docketRow(
        id: _nextId++,
        caseId: payload.caseId,
        hearingDate: payload.hearingDate,
        caseType: payload.caseType,
        urgency: payload.urgency,
        status: 'scheduled',
        remarks: payload.remarks,
      ),
    ];
  }

  @override
  Future<void> updateEntry(int id, DocketPayload payload) async {
    updated.add((id, payload));
    await _wait();
    final failure = saveFailure;
    if (failure != null) throw failure;
    rows = [
      for (final r in rows)
        if (r['id'] == id)
          {
            ...r,
            'hearing_date': payload.hearingDate,
            'case_type': payload.caseType,
            'urgency': payload.urgency,
            'status': payload.status,
            'remarks': payload.remarks,
          }
        else
          r,
    ];
  }

  @override
  Future<void> deleteEntry(int id) async {
    deleted.add(id);
    final failure = deleteFailure;
    if (failure != null) throw failure;
    rows = [
      for (final r in rows)
        if (r['id'] != id) r,
    ];
  }

  @override
  Future<List<JudgeFir>> firOptions() async {
    firOptionsCalls++;
    final failure = firOptionsFailure;
    if (failure != null) throw failure;
    return [for (final f in firs) JudgeFir.fromJson(f)];
  }

  @override
  Future<JudgeFir> fir(String caseId) async {
    firLookups.add(caseId);
    final failure = firFailure;
    if (failure != null) throw failure;
    for (final f in firs) {
      if (f['fir_no'] == caseId) return JudgeFir.fromJson(f);
    }
    throw const ValidationFailure(
      'No linked FIR record found for this Case ID.',
    );
  }

  @override
  Future<PrecedentResearch> research(String query) async {
    researchQueries.add(query);
    await _wait();
    final failure = researchFailure;
    if (failure != null) throw failure;
    return researchResult;
  }
}

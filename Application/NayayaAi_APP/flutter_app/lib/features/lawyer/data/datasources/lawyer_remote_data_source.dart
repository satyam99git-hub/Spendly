import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/lawyer_content.dart';
import '../models/lawyer_models.dart';

/// Every call the website's Lawyer Portal makes, made the way it makes them.
///
/// Each method reproduces what `lawyer_dashboard.html` does with the reply, not
/// just which URL it hits: some handlers check `res.ok` and some never do; most
/// call `res.json()` first, so a body that is not JSON — no connection, or a
/// Flask 500 page — fails the whole call; and a JSON object where a list was
/// expected makes `!list.length` true, so the page shows its empty message.
///
/// Failures are thrown as a [Failure] whose message is the page's own words
/// for that action, or, where the page only logs to the console, a
/// [LawyerSilentFailure] the screens do not render.
class LawyerRemoteDataSource {
  const LawyerRemoteDataSource(this._dio);

  final Dio _dio;

  // ---- plumbing ----------------------------------------------------------

  /// Sends a request and hands back the status and decoded body, whatever the
  /// status. Only "no reply at all" throws.
  Future<_Reply> _send(
    String method,
    String path, {
    Object? data,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      );
      return _Reply(response.statusCode ?? 0, response.data);
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) throw _NoReply(e.type.name);
      return _Reply(response.statusCode ?? 0, response.data);
    }
  }

  /// `const list = await res.json(); if (!list.length) …` — a JSON list is
  /// parsed, any other JSON is the empty list, and a non-JSON body throws.
  Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final reply = await _sendOrSilent('GET', path);
    if (!reply.isJson) throw LawyerSilentFailure('$path: not JSON');
    final body = reply.body;
    if (body is! List) return const [];
    return [
      for (final row in body)
        if (row is Map) parse(Map<String, dynamic>.from(row)),
    ];
  }

  Future<_Reply> _sendOrSilent(
    String method,
    String path, {
    Object? data,
  }) async {
    try {
      return await _send(method, path, data: data);
    } on _NoReply catch (e) {
      throw LawyerSilentFailure('$path: ${e.reason}');
    }
  }

  // ---- My Cases ----------------------------------------------------------

  /// The lawyer's cases.
  ///
  /// The website has no JSON route for this: `/lawyer_dashboard` renders
  /// `get_firs_by_lawyer(session['user_id'])` into the page (app.py:1086),
  /// which is `firs` where `assigned_lawyer_id` equals the signed-in user's
  /// id. The same rows come from `GET /api/fir-records` (every FIR, `select *`)
  /// filtered on the id `GET /api/me` reports — the same predicate over the
  /// same table, in the same order (limitation LL-1).
  Future<List<LawyerCase>> cases() async {
    final _Reply me;
    final _Reply firs;
    try {
      me = await _send('GET', ApiEndpoints.me);
      firs = await _send('GET', ApiEndpoints.firRecords);
    } on _NoReply catch (e) {
      throw NetworkFailure(debugDetail: 'lawyer cases: ${e.reason}');
    }

    final session = me.body;
    if (session is! Map || session['logged_in'] != true) {
      throw const AuthFailure.sessionExpired(debugDetail: 'lawyer cases');
    }
    final userId = session['user_id']?.toString() ?? '';

    final rows = firs.body;
    if (!firs.ok || rows is! List) {
      throw ServerFailure(
        debugDetail: 'lawyer cases: /api/fir-records HTTP ${firs.status}',
      );
    }
    return [
      for (final row in rows)
        if (row is Map) LawyerCase.fromJson(Map<String, dynamic>.from(row)),
    ].where((c) => userId.isNotEmpty && c.assignedLawyerId == userId).toList();
  }

  /// `claimCase()` (lines 1478-1511). Returns on success; otherwise throws the
  /// message the page shows in red.
  Future<void> claim(String firNo) async {
    final _Reply reply;
    try {
      reply = await _send('POST', ApiEndpoints.assignLawyer(firNo));
    } on _NoReply catch (e) {
      throw NetworkFailure(
        message: 'Something went wrong. Please try again.',
        debugDetail: 'assign-lawyer: ${e.reason}',
      );
    }
    if (!reply.isJson) {
      throw NetworkFailure(
        message: 'Something went wrong. Please try again.',
        debugDetail: 'assign-lawyer: HTTP ${reply.status}, not JSON',
      );
    }
    if (!reply.ok) {
      throw ValidationFailure(
        jsOr(reply.field('error'), 'Could not add case.'),
        debugDetail: 'assign-lawyer: HTTP ${reply.status}',
      );
    }
  }

  // ---- Case Workspace ----------------------------------------------------

  /// `cwLoadOverview()` (lines 876-901): the FIR row, or a console-only
  /// failure.
  Future<LawyerCase> caseDetail(String firNo) async {
    final reply = await _sendOrSilent('GET', ApiEndpoints.firRecord(firNo));
    final body = reply.body;
    if (!reply.ok || body is! Map) {
      throw LawyerSilentFailure('fir-record: HTTP ${reply.status}');
    }
    return LawyerCase.fromJson(Map<String, dynamic>.from(body));
  }

  /// `cwUpdateStatus()` (lines 903-937).
  Future<void> updateStatus(String firNo, String status) async {
    const network = 'Something went wrong.';
    final _Reply reply;
    try {
      reply = await _send(
        'PATCH',
        ApiEndpoints.caseStatus(firNo),
        data: {'status': status},
      );
    } on _NoReply catch (e) {
      throw NetworkFailure(message: network, debugDetail: e.reason);
    }
    if (!reply.isJson) {
      throw const NetworkFailure(
        message: network,
        debugDetail: 'status: not JSON',
      );
    }
    if (!reply.ok) {
      throw ValidationFailure(
        jsOr(reply.field('error'), 'Could not update status.'),
      );
    }
  }

  /// `cwSendToClient()` / `cwStopSharing()` (lines 939-989).
  ///
  /// Throws with the page's `e.message`: the server's `error` (or `'Failed'`)
  /// for a JSON refusal, and the browser's fetch failure otherwise.
  Future<void> setClientVisibility(
    String firNo, {
    required bool visible,
    required String note,
  }) async {
    const network = 'Failed to fetch';
    final _Reply reply;
    try {
      reply = await _send(
        'PATCH',
        ApiEndpoints.caseClientVisibility(firNo),
        data: {'visible': visible, 'note': note},
      );
    } on _NoReply catch (e) {
      throw NetworkFailure(message: network, debugDetail: e.reason);
    }
    if (!reply.isJson) {
      throw const NetworkFailure(
        message: network,
        debugDetail: 'client-visibility: not JSON',
      );
    }
    if (!reply.ok) {
      throw ValidationFailure(jsOr(reply.field('error'), 'Failed'));
    }
  }

  /// `cwLoadDocuments()` (lines 1005-1028).
  Future<List<CaseDocument>> documents(String firNo) =>
      _list(ApiEndpoints.evidenceForFir(firNo), CaseDocument.fromJson);

  /// `cwLoadHearings()` (lines 1030-1052).
  Future<List<CaseHearing>> hearings(String firNo) =>
      _list(ApiEndpoints.caseHearings(firNo), CaseHearing.fromJson);

  /// `cwAddHearing()` (lines 1054-1074): only `res.ok` is looked at.
  Future<void> addHearing(String firNo, String date, String note) async {
    final reply = await _sendOrSilent(
      'POST',
      ApiEndpoints.caseHearings(firNo),
      data: {'hearing_date': date, 'note': note},
    );
    if (!reply.ok) throw LawyerSilentFailure('add hearing: ${reply.status}');
  }

  /// `cwLoadDeadlines()` (lines 1076-1118).
  Future<List<CaseDeadline>> deadlines(String firNo) =>
      _list(ApiEndpoints.caseDeadlines(firNo), CaseDeadline.fromJson);

  /// `cwAddDeadline()` (lines 1120-1141): only `res.ok` is looked at.
  Future<void> addDeadline(
    String firNo, {
    required String deadlineType,
    required String dueDate,
    required String note,
  }) async {
    final reply = await _sendOrSilent(
      'POST',
      ApiEndpoints.caseDeadlines(firNo),
      data: {'deadline_type': deadlineType, 'due_date': dueDate, 'note': note},
    );
    if (!reply.ok) throw LawyerSilentFailure('add deadline: ${reply.status}');
  }

  /// `cwToggleDeadline()` (lines 1143-1155): the reply is not read.
  Future<void> setDeadlineCompleted(
    String firNo,
    Object? deadlineId, {
    required bool completed,
  }) async {
    await _sendOrSilent(
      'PATCH',
      ApiEndpoints.caseDeadline(firNo, deadlineId ?? ''),
      data: {'completed': completed},
    );
  }

  /// `cwDeleteDeadline()` (lines 1157-1165): the reply is not read.
  Future<void> deleteDeadline(String firNo, Object? deadlineId) async {
    await _sendOrSilent(
      'DELETE',
      ApiEndpoints.caseDeadline(firNo, deadlineId ?? ''),
    );
  }

  /// `cwLoadDrafts()` (lines 1307-1335).
  Future<List<CaseDraft>> drafts(String firNo) =>
      _list(ApiEndpoints.caseDrafts(firNo), CaseDraft.fromJson);

  /// `cwSaveDraft()` (lines 1284-1305): only `res.ok` is looked at.
  Future<void> saveDraft(String firNo, String kind, String content) async {
    final reply = await _sendOrSilent(
      'POST',
      ApiEndpoints.caseDrafts(firNo),
      data: {'kind': kind, 'content': content},
    );
    if (!reply.ok) throw LawyerSilentFailure('save draft: ${reply.status}');
  }

  /// `cwDeleteDraft()` (lines 1344-1352): the reply is not read.
  Future<void> deleteDraft(String firNo, Object? draftId) async {
    await _sendOrSilent('DELETE', ApiEndpoints.caseDraft(firNo, draftId ?? ''));
  }

  // ---- AI ----------------------------------------------------------------

  /// `cwGenerateDraft()` (lines 1264-1281). The status is never checked: any
  /// JSON body yields `data.text || 'No draft returned.'`.
  Future<String> generateDraft({
    required bool bail,
    required String prompt,
  }) async {
    final reply = await _sendOrSilent(
      'POST',
      bail ? ApiEndpoints.lawyerBailDraft : ApiEndpoints.lawyerDraftDocument,
      data: {'prompt': prompt},
    );
    if (!reply.isJson) throw const LawyerSilentFailure('draft: not JSON');
    return jsOr(reply.field('text'), 'No draft returned.');
  }

  /// `POST /api/lawyer/find-precedents` with `type: 'laws'`, as both the
  /// Legal Assistant and the AI Summary send it. Returns `data.answer` when it
  /// is truthy, null when the JSON has none (each caller has its own
  /// fallback), and throws when the body is not JSON — the 500 of LL-2.
  Future<String?> findPrecedents(String query) async {
    final reply = await _sendOrSilent(
      'POST',
      ApiEndpoints.lawyerFindPrecedents,
      data: {'query': query, 'type': 'laws'},
    );
    if (!reply.isJson) {
      throw LawyerSilentFailure('find-precedents: HTTP ${reply.status}');
    }
    final answer = reply.field('answer');
    return jsTruthy(answer) ? answer.toString() : null;
  }

  // ---- lists across cases ------------------------------------------------

  /// `loadGlobalDrafts()` (lines 1520-1558).
  Future<List<CaseDraft>> allDrafts() =>
      _list(ApiEndpoints.lawyerDrafts, CaseDraft.fromJson);

  /// `loadHomeDeadlines()` (lines 1168-1205).
  Future<List<CaseDeadline>> upcomingDeadlines() =>
      _list(ApiEndpoints.lawyerDeadlines, CaseDeadline.fromJson);

  // ---- profile -----------------------------------------------------------

  /// `openProfileModal()` (lines 1612-1630). Null when the server refused —
  /// the page then leaves the fields as they were.
  Future<LawyerProfile?> profile() async {
    final reply = await _sendOrSilent('GET', ApiEndpoints.lawyerProfile);
    if (!reply.isJson) throw const LawyerSilentFailure('profile: not JSON');
    final body = reply.body;
    if (!reply.ok || body is! Map) return null;
    return LawyerProfile.fromJson(Map<String, dynamic>.from(body));
  }

  /// `saveProfile()` (lines 1712-1726): only `res.ok` is looked at.
  Future<void> saveProfile(LawyerProfileUpdate update) async {
    final reply = await _sendOrSilent(
      'PATCH',
      ApiEndpoints.lawyerProfile,
      data: update.toJson(),
    );
    if (!reply.ok) throw LawyerSilentFailure('save profile: ${reply.status}');
  }

  /// `uploadProfilePhoto()` (lines 1653-1678). Returns the new `photo_url`.
  Future<String> uploadPhoto({
    required String path,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path, filename: filename),
    });
    final reply = await _sendOrSilent(
      'POST',
      ApiEndpoints.lawyerProfilePhoto,
      data: form,
    );
    if (!reply.isJson || !reply.ok) {
      throw LawyerSilentFailure('photo: HTTP ${reply.status}');
    }
    return jsOr(reply.field('photo_url'), '');
  }
}

/// A failure the website only sends to `console.error`. The screens show what
/// the page shows in that case — usually nothing — and do not render this.
final class LawyerSilentFailure implements Exception {
  const LawyerSilentFailure(this.debugDetail);

  final String debugDetail;

  @override
  String toString() => 'LawyerSilentFailure($debugDetail)';
}

class _Reply {
  const _Reply(this.status, this.body);

  final int status;
  final Object? body;

  bool get ok => status >= 200 && status < 300;

  /// Whether `res.json()` would have succeeded.
  bool get isJson => body is Map || body is List;

  Object? field(String key) {
    final b = body;
    return b is Map ? b[key] : null;
  }
}

class _NoReply implements Exception {
  const _NoReply(this.reason);

  final String reason;
}

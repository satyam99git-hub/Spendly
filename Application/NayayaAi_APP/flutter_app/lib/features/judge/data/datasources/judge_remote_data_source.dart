import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/judge_content.dart';
import '../models/judge_models.dart';

/// Every call `judge_dashboard.html` makes, with the reply read the way the
/// page reads it.
///
/// The page itself has almost no error handling — a failed docket load leaves
/// "Loading…" on screen for good. Where it says nothing, this class still
/// throws a [Failure] with a plain sentence, so the screens can offer a retry
/// instead of hanging (analysis OQ-J6). Where the page has words of its own,
/// those are the message.
class JudgeRemoteDataSource {
  const JudgeRemoteDataSource(this._dio);

  final Dio _dio;

  /// `_require_judge()` answers 403 to anyone the session does not name a
  /// judge — including a session that has simply expired (judge_routes.py:11-14).
  static const _notJudge = AuthFailure.sessionExpired(
    message: 'Your judge session has ended. Please sign in again.',
    debugDetail: 'judge: HTTP 403',
  );

  // ---- plumbing ----------------------------------------------------------

  /// Sends a request and returns the status and body whatever the status.
  /// Only "no reply at all" throws, as a [NetworkFailure].
  Future<_Reply> _send(String method, String path, {Object? data}) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method),
      );
      return _Reply(response.statusCode ?? 0, response.data);
    } on DioException catch (e) {
      final response = e.response;
      if (response == null) {
        throw NetworkFailure(debugDetail: '$path: ${e.type.name}');
      }
      return _Reply(response.statusCode ?? 0, response.data);
    }
  }

  // ---- the docket --------------------------------------------------------

  Future<List<DocketEntry>> docket({
    String status = '',
    String urgency = '',
  }) async {
    final reply = await _send(
      'GET',
      ApiEndpoints.judgeDocketFiltered(status: status, urgency: urgency),
    );
    if (reply.status == 403) throw _notJudge;
    final body = reply.body;
    if (!reply.ok || body is! List) {
      throw ServerFailure(debugDetail: 'judge docket: HTTP ${reply.status}');
    }
    return [
      for (final row in body)
        if (row is Map) DocketEntry.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> createEntry(DocketPayload payload) =>
      _save('POST', ApiEndpoints.judgeDocket, payload);

  Future<void> updateEntry(int id, DocketPayload payload) =>
      _save('PUT', ApiEndpoints.judgeDocketEntry(id), payload);

  /// `if (!res.ok) { const err = await res.json().catch(() => ({}));
  /// return showWarn(err.message || err.error || "Could not save hearing."); }`
  /// (JD:756-759). A body that is not JSON — a Flask 500 page — falls through
  /// to the page's own sentence.
  Future<void> _save(String method, String path, DocketPayload payload) async {
    final reply = await _send(method, path, data: payload.toJson());
    if (reply.ok) return;
    final message = jsOrText(reply.field('message'), '');
    final error = jsOrText(reply.field('error'), '');
    throw ValidationFailure(
      message.isNotEmpty
          ? message
          : error.isNotEmpty
              ? error
              : JudgeContent.saveFailed,
      debugDetail: 'judge docket $method: HTTP ${reply.status}',
    );
  }

  /// The page sends the DELETE and reloads without looking at the reply. The
  /// app does look, so a refused delete is not reported as done.
  Future<void> deleteEntry(int id) async {
    final reply = await _send('DELETE', ApiEndpoints.judgeDocketEntry(id));
    if (reply.status == 403) throw _notJudge;
    if (!reply.ok) {
      throw ValidationFailure(
        jsOrText(reply.field('error'), 'Could not delete this hearing entry.'),
        debugDetail: 'judge docket DELETE: HTTP ${reply.status}',
      );
    }
  }

  // ---- FIR records (read only) -------------------------------------------

  Future<List<JudgeFir>> firOptions() async {
    final reply = await _send('GET', ApiEndpoints.firRecords);
    final body = reply.body;
    if (!reply.ok || body is! List) {
      throw ServerFailure(debugDetail: 'fir-records: HTTP ${reply.status}');
    }
    return [
      for (final row in body)
        if (row is Map) JudgeFir.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// `if (!res.ok) throw new Error("not found")` (JD:823): any refusal is "no
  /// linked FIR", a [ValidationFailure] with the page's sentence. Only a
  /// missing reply is a network failure.
  Future<JudgeFir> fir(String caseId) async {
    final reply = await _send('GET', ApiEndpoints.firRecord(caseId));
    final body = reply.body;
    if (!reply.ok || body is! Map) {
      throw ValidationFailure(
        JudgeContent.noLinkedFir,
        debugDetail: 'fir-records/<id>: HTTP ${reply.status}',
      );
    }
    return JudgeFir.fromJson(Map<String, dynamic>.from(body));
  }

  // ---- precedent research ------------------------------------------------

  /// `const data = await res.json(); if (data.error) … else render(data)`
  /// (JD:1176-1181). The status is not consulted: a JSON `error` is shown as
  /// is, and a body that is not JSON is the page's catch-all sentence.
  Future<PrecedentResearch> research(String query) async {
    final _Reply reply;
    try {
      reply = await _send(
        'POST',
        ApiEndpoints.judgePrecedents,
        data: {'query': query},
      );
    } on NetworkFailure catch (e) {
      throw NetworkFailure(
        message: JudgeContent.researchFailed,
        debugDetail: e.debugDetail,
      );
    }
    final body = reply.body;
    if (body is! Map) {
      throw ServerFailure(
        message: JudgeContent.researchFailed,
        debugDetail: 'judge precedents: HTTP ${reply.status}, not JSON',
      );
    }
    final error = jsOrText(body['error'], '');
    if (error.isNotEmpty) {
      throw ValidationFailure(
        error,
        debugDetail: 'judge precedents: HTTP ${reply.status}',
      );
    }
    return PrecedentResearch.fromJson(Map<String, dynamic>.from(body));
  }
}

class _Reply {
  const _Reply(this.status, this.body);

  final int status;
  final Object? body;

  bool get ok => status >= 200 && status < 300;

  Object? field(String key) {
    final b = body;
    return b is Map ? b[key] : null;
  }
}

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_item.dart';
import '../models/evidence_models.dart';

/// Talks to the evidence endpoints. Knows about HTTP and about the filesystem;
/// knows nothing about lock state, navigation or how a file was chosen.
///
/// Each method converts transport errors into [Failure]s at its own boundary, so
/// the repository above never sees a [DioException].
class EvidenceRemoteDataSource {
  const EvidenceRemoteDataSource(this._dio);

  final Dio _dio;

  /// `POST /verify-locker-access`, body `{pin}`.
  ///
  /// True when the server accepts the PIN, false when it rejects it. A rejection
  /// is a 401, which the client's interceptor turns into a [DioException] —
  /// caught here and answered as `false`, because a wrong PIN is an ordinary
  /// outcome of a PIN box and not a failure the officer needs a red banner for.
  ///
  /// Anything that is not a clean accept or a clean reject — no server, a
  /// timeout, a 500 — throws. The gate then fails closed and says why, which is
  /// the only honest answer: the app cannot tell an unreachable server from a
  /// server that would have said no.
  Future<bool> verifyLockerPin(String pin) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.verifyLockerAccess,
        data: {'pin': pin},
      );
      final body = response.data;
      return body is Map && body['success'] == true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return false;
      throw ErrorMapper.map(e, context: 'verify-locker-access');
    } catch (e) {
      throw ErrorMapper.map(e, context: 'verify-locker-access');
    }
  }

  /// `GET /get-all-evidence`.
  Future<List<EvidenceItem>> all() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.allEvidence);
      return AllEvidenceResponse.fromJson(
        _asMap(response.data, 'get-all-evidence'),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'get-all-evidence');
    }
  }

  /// `GET /api/evidence?fir_no=`.
  Future<List<EvidenceItem>> forFir(String firNo) async {
    try {
      final response =
          await _dio.get<dynamic>(ApiEndpoints.evidenceForFir(firNo));
      final data = response.data;

      if (data is! List) {
        throw ServerFailure(
          debugDetail: 'api/evidence: expected a JSON array, got '
              '${data.runtimeType}',
        );
      }

      return data
          .whereType<Map>()
          .map(
            (row) => EvidenceItemResponse.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .whereType<EvidenceItem>()
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/evidence');
    }
  }

  /// `POST /upload-evidence`, multipart.
  ///
  /// The one request in the app that is not JSON. `contentType` is overridden
  /// per-request rather than on the client: `DioClient` sets a JSON default for
  /// every other call, and a multipart body sent with that header arrives at
  /// Flask as an empty `request.files`, which the handler reports as the
  /// thoroughly misleading "Missing FIR or file".
  Future<EvidenceItem> upload({
    required String firNo,
    required EvidenceFile file,
  }) async {
    try {
      final body = FormData.fromMap({
        'fir_no': firNo,
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });

      final response = await _dio.post<dynamic>(
        ApiEndpoints.uploadEvidence,
        data: body,
        options: Options(contentType: 'multipart/form-data'),
      );

      return EvidenceUploadResponse.fromJson(
        _asMap(response.data, 'upload-evidence'),
        fallbackFirNo: firNo,
        fallbackFilename: file.name,
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'upload-evidence');
    }
  }

  /// `POST /api/evidence/log-access`. Never throws — see the repository.
  Future<void> logAccess(Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(ApiEndpoints.logEvidenceAccess, data: body);
    } catch (_) {
      // Swallowed deliberately. The caller is showing a file and cannot act on
      // this, and the handler is a stub that discards the body anyway.
    }
  }

  /// Guards against a handler that answered 200 with something other than a JSON
  /// object — an HTML error page, or a bare string. Without this the cast throws
  /// a raw `TypeError` that ErrorMapper would file as unknown.
  Map<String, dynamic> _asMap(Object? data, String context) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerFailure(
      debugDetail: '$context: expected a JSON object, got ${data.runtimeType}',
    );
  }
}

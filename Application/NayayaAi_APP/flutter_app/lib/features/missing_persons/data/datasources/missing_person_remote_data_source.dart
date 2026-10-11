import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/confirmed_match.dart';
import '../../domain/entities/missing_person.dart';
import '../../domain/entities/sighting.dart';
import '../../domain/repositories/missing_person_repository.dart';
import '../models/missing_person_models.dart';

/// Talks to the missing-persons blueprint.
///
/// ---------------------------------------------------------------------------
/// EVERY ANSWER IS WRAPPED IN `{success: bool, ...}`
///
/// Alone among this server's blueprints, these handlers report failure in the
/// body as well as in the status. A 403 carries `{success: false, error:
/// "Police login required."}`, and so does a 400 for a photograph with no face
/// in it — so the status alone does not say what went wrong and the body has to
/// be read on the way past.
///
/// [_unwrap] does that once, for every method: a non-2xx has already become a
/// [DioException] by the time it reaches here (the client's interceptor), so
/// what this catches is the other case — an HTTP 200 whose body says
/// `success: false`, which the server does send.
/// ---------------------------------------------------------------------------
class MissingPersonRemoteDataSource {
  const MissingPersonRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /get_missing_persons`.
  Future<List<MissingPerson>> all() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.missingPersons);
      final rows = _unwrap(response.data, 'get_missing_persons')
          ['missing_persons'];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (row) => MissingPersonResponse.fromJson(
              row.cast<String, dynamic>(),
            ),
          )
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'get_missing_persons');
    }
  }

  /// `POST /upload_missing_person`, multipart.
  ///
  /// `contentType` is overridden per request for the same reason the evidence
  /// upload overrides it: the client sends JSON by default, and a multipart
  /// body under a JSON header reaches Flask as an empty `request.files`, which
  /// this handler reports as the thoroughly misleading "No photo file
  /// received."
  Future<String> register(MissingPersonDraft draft) async {
    try {
      final body = FormData.fromMap({
        'name': draft.name,
        'photo': await MultipartFile.fromFile(
          draft.photoPath,
          filename: draft.photoName,
        ),
        // Sent even when blank. The handler reads each with `.get(...) or ''`
        // and stores the result, so an omitted key and an empty one are the
        // same column value — and sending all of them keeps the request one
        // shape rather than several.
        'age': draft.age,
        'gender': draft.gender,
        'description': draft.description,
        'last_seen_location': draft.lastSeenLocation,
        'last_seen_date': draft.lastSeenDate,
      });

      final response = await _dio.post<dynamic>(
        ApiEndpoints.uploadMissingPerson,
        data: body,
        options: Options(contentType: 'multipart/form-data'),
      );

      final json = _unwrap(response.data, 'upload_missing_person');
      final id = '${json['person_id'] ?? ''}'.trim();
      if (id.isEmpty) {
        throw const ServerFailure(
          message: 'The case was accepted but the server returned no ID.',
          debugDetail: 'upload_missing_person: no person_id',
        );
      }
      return id;
    } catch (e) {
      throw ErrorMapper.map(e, context: 'upload_missing_person');
    }
  }

  /// `GET /get_sightings/<person_id>`.
  Future<List<Sighting>> sightings(String personId) async {
    try {
      final response =
          await _dio.get<dynamic>(ApiEndpoints.sightings(personId));
      final rows = _unwrap(response.data, 'get_sightings')['sightings'];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map((row) => SightingResponse.fromJson(row.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'get_sightings');
    }
  }

  /// `POST /report_sighting/<person_id>`, multipart.
  Future<SightingResult> reportSighting({
    required String personId,
    required String photoPath,
    required String photoName,
    required String location,
    String sightingDate = '',
  }) async {
    try {
      final body = FormData.fromMap({
        'photo': await MultipartFile.fromFile(photoPath, filename: photoName),
        'location': location,
        // Omitted rather than blank: the handler defaults an absent or empty
        // date to today, and sending '' would work but reads as a value.
        if (sightingDate.trim().isNotEmpty) 'sighting_date': sightingDate.trim(),
      });

      final response = await _dio.post<dynamic>(
        ApiEndpoints.reportSighting(personId),
        data: body,
        options: Options(contentType: 'multipart/form-data'),
      );

      return SightingResultResponse.fromJson(
        _unwrap(response.data, 'report_sighting'),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'report_sighting');
    }
  }

  /// `GET /get_confirmed_matches`.
  Future<List<ConfirmedMatch>> confirmedMatches() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.confirmedMatches);
      final rows =
          _unwrap(response.data, 'get_confirmed_matches')['confirmed_matches'];
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(
            (row) => ConfirmedMatchResponse.fromJson(
              row.cast<String, dynamic>(),
            ),
          )
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'get_confirmed_matches');
    }
  }

  /// `POST /update_missing_person_status/<person_id>`.
  Future<void> setStatus(String personId, MissingPersonStatus status) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.updateMissingPersonStatus(personId),
        data: {'status': status.wireValue},
      );
      _unwrap(response.data, 'update_missing_person_status');
    } catch (e) {
      throw ErrorMapper.map(e, context: 'update_missing_person_status');
    }
  }

  /// Reads the `{success, ...}` envelope, throwing the server's own sentence
  /// when `success` is false.
  ///
  /// A 200 that says `success: false` is a real shape here — see the class doc.
  /// The message is lifted out verbatim because these are the only refusals in
  /// the app the officer can actually act on: "No face detected in the photo.
  /// Please upload a clear frontal image." tells them to take another one.
  Map<String, dynamic> _unwrap(dynamic data, String context) {
    if (data is! Map) {
      throw ServerFailure(
        message: 'The server sent something this screen could not read.',
        debugDetail: '$context: not an object',
      );
    }

    final json = data.cast<String, dynamic>();
    if (json['success'] == false) {
      final error = '${json['error'] ?? ''}'.trim();
      throw ValidationFailure(
        error.isEmpty ? 'The server refused that.' : error,
        debugDetail: '$context: success=false',
      );
    }
    return json;
  }
}

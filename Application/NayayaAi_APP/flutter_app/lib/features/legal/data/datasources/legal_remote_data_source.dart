import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/legal_section.dart';
import '../../domain/entities/outcome_finding.dart';
import '../models/legal_models.dart';

/// Talks to the law-library and legal-AI endpoints.
///
/// Converts transport errors into [Failure]s at its own boundary, like every
/// other data source here, so the repository above never sees a
/// [DioException].
class LegalRemoteDataSource {
  const LegalRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /api/acts`.
  Future<List<String>> acts() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.acts);
      final data = response.data;
      if (data is! List) {
        throw const ServerFailure(
          message: 'The server sent something other than the list of acts.',
          debugDetail: 'api/acts: not a list',
        );
      }
      return data.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/acts');
    }
  }

  /// `GET /api/sections/<act>`.
  Future<LegalSectionPage> sections(
    String act, {
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.sections(act, search: search, page: page, limit: limit),
      );
      return LegalSectionPageResponse.fromJson(
        _asMap(response.data, 'api/sections'),
        fallbackAct: act,
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/sections');
    }
  }

  /// `GET /api/section-detail/<act>/<no>`.
  Future<LegalSection> section(String act, String sectionNo) async {
    try {
      final response =
          await _dio.get<dynamic>(ApiEndpoints.sectionDetail(act, sectionNo));
      return LegalSectionResponse.fromJson(
        _asMap(response.data, 'api/section-detail'),
        fallbackAct: act,
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/section-detail');
    }
  }

  /// `GET /api/search-sections?q=`.
  ///
  /// A bare array, unlike [sections]'s envelope — see [ApiEndpoints].
  Future<List<LegalSection>> search(String query) async {
    try {
      final response =
          await _dio.get<dynamic>(ApiEndpoints.searchSections(query));
      final data = response.data;
      if (data is! List) {
        throw const ServerFailure(
          message: 'The server sent something other than a list of sections.',
          debugDetail: 'api/search-sections: not a list',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (row) => LegalSectionResponse.fromJson(
              row.cast<String, dynamic>(),
              // Every hit carries its own act; this is only reached for a row
              // that somehow does not, and an empty one is honest.
              fallbackAct: '',
            ),
          )
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/search-sections');
    }
  }

  /// `POST /api/ask-law`.
  ///
  /// Returns the answer text. The 400 for a blank question also carries an
  /// `answer`, but the app never sends one — the screen refuses first, because
  /// a round trip to be told the box is empty is a round trip wasted.
  Future<String> ask(String question) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.askLaw,
        data: {'question': question},
      );
      final answer = _asMap(response.data, 'api/ask-law')['answer'];
      final text = answer == null ? '' : '$answer'.trim();
      if (text.isEmpty) {
        throw const ServerFailure(
          message: 'The server answered with nothing.',
          debugDetail: 'api/ask-law: empty answer',
        );
      }
      return text;
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/ask-law');
    }
  }

  /// `POST /api/predict-outcome`.
  ///
  /// Reads `results`, not `prediction` — see [ApiEndpoints.predictOutcome].
  /// A server that predates that key answers with `prediction` alone, and the
  /// app reports no matches rather than crashing: the alternative is parsing
  /// Tailwind markup.
  Future<List<OutcomeFinding>> predictOutcome(String situation) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.predictOutcome,
        data: {'situation': situation},
      );
      final results = _asMap(response.data, 'api/predict-outcome')['results'];
      if (results is! List) return const [];
      return results
          .whereType<Map>()
          .map(
            (row) => OutcomeFindingResponse.fromJson(
              row.cast<String, dynamic>(),
            ),
          )
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'api/predict-outcome');
    }
  }

  Map<String, dynamic> _asMap(dynamic data, String context) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw ServerFailure(
      message: 'The server sent something this screen could not read.',
      debugDetail: '$context: not an object',
    );
  }
}

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/fir_receipt.dart';
import '../../domain/entities/fir_record.dart';
import '../../domain/entities/section_suggestion.dart';
import '../models/fir_models.dart';

/// Talks to the FIR endpoints. Knows about HTTP; knows nothing about form state,
/// storage or navigation.
///
/// Each method converts transport errors into [Failure]s at its own boundary, so
/// the repository above never sees a [DioException].
class FirRemoteDataSource {
  const FirRemoteDataSource(this._dio);

  final Dio _dio;

  /// Files the FIR.
  ///
  /// A duplicate FIR number comes back as HTTP 400 with the server's own
  /// message, which [ErrorMapper] turns into a [ValidationFailure] — the screen
  /// shows it verbatim against the FIR-number field, because the server is the
  /// only thing that knows which numbers are taken.
  Future<FirReceipt> register(FirSubmission submission) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.generateFir,
        data: submission.toJson(),
      );
      return FirReceiptResponse.fromJson(_asMap(response.data, 'generate_fir'));
    } catch (e) {
      throw ErrorMapper.map(e, context: 'generate_fir');
    }
  }

  /// `POST /api/suggest-sections` — acts and sections for a narrative.
  ///
  /// Never throws for "no suggestions": an empty list is a real answer, and a
  /// narrative that discloses no offence is a normal thing for an officer to
  /// have typed. Only a transport or auth failure raises, which is what the
  /// caller shows as an error.
  Future<SectionSuggestions> suggestSections(String narrative) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.suggestSections,
        // `statement` and not `narrative`: it is what FORM IF-1 calls this entry
        // and what `/generate_fir` reads, so the two requests carry the same
        // text under the same name.
        data: {'statement': narrative},
      );
      return SectionSuggestionsResponse.fromJson(
        _asMap(response.data, 'suggest-sections'),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'suggest-sections');
    }
  }

  /// `GET /api/fir-records` — the whole collection.
  ///
  /// A row that is not a JSON object is skipped rather than fatal. This is a
  /// schemaless collection that four other things write to, and one malformed
  /// document should cost the officer that record, not the entire history.
  Future<List<FirRecord>> history() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.firRecords);
      final data = response.data;

      if (data is! List) {
        throw ServerFailure(
          debugDetail: 'fir-records: expected a JSON array, got '
              '${data.runtimeType}',
        );
      }

      return data
          .whereType<Map>()
          .map((row) => FirRecordResponse.fromJson(Map<String, dynamic>.from(row)))
          // A document with no FIR number cannot be opened, downloaded or filed
          // evidence against — there is nothing to key it on — so it is dropped
          // rather than shown as a row that does nothing when tapped.
          .where((record) => record.firNo.isNotEmpty)
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'fir-records');
    }
  }

  /// `GET /api/fir-records/<fir_no>` — one record. 404 arrives as a
  /// [ValidationFailure] carrying the server's own wording.
  Future<FirRecord> record(String firNo) async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.firRecord(firNo));
      return FirRecordResponse.fromJson(
        _asMap(response.data, 'fir-records/$firNo'),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'fir-records/$firNo');
    }
  }

  /// `GET /fir/download/<fir_no>` streamed straight to [savePath].
  ///
  /// Streamed rather than buffered because the caller wants a file, not bytes:
  /// `Dio.download` writes as it reads and leaves nothing in memory. Nothing is
  /// written at all unless the response was a success — the client's
  /// `validateStatus` lets every status through and the rejecting interceptor
  /// turns a non-2xx into a [DioException] before the body reaches the disk, so
  /// a 404's JSON error can never end up saved as a PDF.
  Future<void> downloadPdf({
    required String firNo,
    required String savePath,
  }) async {
    try {
      await _dio.download(ApiEndpoints.firDownload(firNo), savePath);
    } on DioException catch (e) {
      // Restated rather than passed to ErrorMapper, which would produce its bare
      // "Not found." fallback here: a download is fetched as a stream, so the
      // server's `{"error": "PDF for FIR X not found"}` is never parsed into a
      // Map for the message to be lifted out of.
      if (e.response?.statusCode == 404) {
        throw ValidationFailure(
          'The station server has no PDF for this FIR. It was generated on '
          'whichever machine filed the record.',
          debugDetail: 'fir/download: HTTP 404 $firNo',
        );
      }
      throw ErrorMapper.map(e, context: 'fir/download');
    } catch (e) {
      // Everything that is not HTTP: a full disk, a path that cannot be written.
      throw ErrorMapper.map(e, context: 'fir/download');
    }
  }

  Future<List<String>> districts() => _stringList(
        ApiEndpoints.districts,
        context: 'districts',
      );

  Future<List<String>> policeStations(String district) => _stringList(
        ApiEndpoints.policeStations(district),
        context: 'police-stations',
      );

  Future<List<String>> acts() => _stringList(
        ApiEndpoints.acts,
        context: 'acts',
      );

  /// The three lookup endpoints all answer with a bare JSON array of strings.
  ///
  /// Empties and duplicates are dropped here rather than in the widget: an empty
  /// option in a dropdown is a selectable value that means nothing, and a
  /// repeated one makes the list look broken. Order is the server's — the
  /// district list arrives sorted and the act list is in the order the section
  /// tables are documented, neither of which is ours to rearrange.
  Future<List<String>> _stringList(
    String path, {
    required String context,
  }) async {
    try {
      final response = await _dio.get<dynamic>(path);
      final data = response.data;

      if (data is! List) {
        throw ServerFailure(
          debugDetail: '$context: expected a JSON array, got '
              '${data.runtimeType}',
        );
      }

      final seen = <String>{};
      final values = <String>[];
      for (final item in data) {
        final value = item?.toString().trim() ?? '';
        if (value.isEmpty || !seen.add(value)) continue;
        values.add(value);
      }
      return values;
    } catch (e) {
      throw ErrorMapper.map(e, context: context);
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

import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/complaint.dart';
import '../models/complaint_models.dart';

/// Talks to the complaints endpoints. Knows about HTTP; knows nothing about
/// filters, notes or navigation.
///
/// Each method converts transport errors into [Failure]s at its own boundary,
/// so the repository above never sees a [DioException].
class ComplaintRemoteDataSource {
  const ComplaintRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /api/complaints/all` — the whole table.
  ///
  /// A row that is not a JSON object is skipped rather than fatal, and so is one
  /// with no tracking ID: it cannot be opened, updated or converted to an FIR,
  /// because the ID is the only thing either write route is keyed on. Dropping
  /// it costs the officer that row; throwing would cost them the inbox.
  Future<List<Complaint>> all() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.allComplaints);
      final data = response.data;

      if (data is! List) {
        throw ServerFailure(
          debugDetail: 'complaints/all: expected a JSON array, got '
              '${data.runtimeType}',
        );
      }

      return data
          .whereType<Map>()
          .map(
            (row) => ComplaintResponse.fromJson(Map<String, dynamic>.from(row)),
          )
          .where((complaint) => complaint.trackingId.isNotEmpty)
          .toList();
    } catch (e) {
      throw ErrorMapper.map(e, context: 'complaints/all');
    }
  }

  /// `GET /api/complaint/<tracking_id>` — one complaint, without its phone
  /// number. 404 arrives as a [ValidationFailure] carrying the server's own
  /// wording ("Complaint not found. Check your tracking ID.").
  Future<Complaint> byTrackingId(String trackingId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.complaint(trackingId),
      );
      return ComplaintResponse.fromJson(
        _asMap(response.data, 'complaint/$trackingId'),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'complaint/$trackingId');
    }
  }

  /// `PATCH /api/complaints/<tracking_id>`.
  ///
  /// Returns nothing: the handler replies `{message, tracking_id}` and not the
  /// updated row, so there is no stored complaint here to hand back. The
  /// repository re-reads instead — see `ComplaintRepositoryImpl.update`.
  ///
  /// **Never retried automatically.** The write is not idempotent in the way
  /// that matters: [update] carries the notes column in full, so a retry after
  /// an ambiguous timeout would re-send a body composed from a complaint read
  /// *before* whatever the first attempt may already have written, and quietly
  /// undo it.
  Future<void> update(String trackingId, ComplaintUpdate change) async {
    try {
      await _dio.patch<dynamic>(
        ApiEndpoints.updateComplaint(trackingId),
        data: change.toJson(),
      );
    } catch (e) {
      throw ErrorMapper.map(e, context: 'complaints/$trackingId');
    }
  }

  /// Guards against a handler that answered 200 with something other than a
  /// JSON object — an HTML error page, or a bare string. Without this the cast
  /// throws a raw `TypeError` that ErrorMapper would file as unknown.
  Map<String, dynamic> _asMap(Object? data, String context) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ServerFailure(
      debugDetail: '$context: expected a JSON object, got ${data.runtimeType}',
    );
  }
}

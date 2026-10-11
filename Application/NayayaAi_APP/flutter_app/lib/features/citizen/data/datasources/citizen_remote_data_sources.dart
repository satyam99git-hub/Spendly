import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/failure.dart';
import '../../../complaints/data/models/complaint_models.dart';
import '../../../complaints/domain/entities/complaint.dart';
import '../models/case_client_status.dart';
import '../models/citizen_complaint_models.dart';
import 'citizen_failure.dart';

/// The website's network sentence for the complaint and case-status pages.
const _networkError = 'Network error. Please try again.';

/// Filing and tracking a complaint, as `citizen_dashboard.html` does.
///
/// Its own data source rather than two more methods on the police
/// `ComplaintRemoteDataSource`: the police one phrases failures for an officer,
/// these phrase them as the website phrases them to a citizen, and neither
/// should have to know about the other's audience.
class CitizenComplaintRemoteDataSource {
  const CitizenComplaintRemoteDataSource(this._dio);

  final Dio _dio;

  /// `submitComplaint()` — citizen_dashboard.html:838-851.
  Future<ComplaintReceipt> file(ComplaintSubmission submission) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.fileComplaint,
        data: submission.toJson(),
      );
      final receipt = ComplaintReceipt.fromJson(
        citizenJsonObject(response.data, 'api/complaint'),
      );
      if (receipt.trackingId.isEmpty) {
        throw const FormatException('api/complaint: no tracking_id');
      }
      return receipt;
    } catch (e) {
      throw citizenFailure(
        e,
        fallback: 'Submission failed.',
        network: _networkError,
        context: 'api/complaint',
      );
    }
  }

  /// `trackComplaint()` — citizen_dashboard.html:876-883.
  ///
  /// Parsed with the police feature's own `ComplaintResponse` — it is the same
  /// row from the same table, and the entity already understands every column
  /// this endpoint returns.
  Future<Complaint> track(String trackingId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.complaint(trackingId),
      );
      return ComplaintResponse.fromJson(
        citizenJsonObject(response.data, 'api/complaint/<id>'),
      );
    } catch (e) {
      throw citizenFailure(
        e,
        fallback: 'Complaint not found.',
        network: _networkError,
        context: 'api/complaint/<id>',
      );
    }
  }
}

/// Know Your Rights — `askRightsQuestion()`, citizen_dashboard.html:958-1016.
class RightsChatRemoteDataSource {
  const RightsChatRemoteDataSource(this._dio);

  final Dio _dio;

  /// What the website puts in the bubble when it cannot get an answer.
  static const couldNotConnect =
      'Could not connect. Check your server is running and try again.';

  /// `formatAnswer(undefined)` — a JSON body with no `answer` in it.
  static const noAnswer = 'No answer received.';

  /// Returns the answer text.
  ///
  /// **Whatever the status code.** The website never checks `res.ok`: a 400
  /// `{answer: "Please ask a question about your rights."}` is shown in the
  /// bubble like any other answer, because to the citizen it is one. Only a
  /// body that is not JSON — no connection, or the 500 page limitation L2
  /// describes — becomes [couldNotConnect].
  Future<String> ask(String question) async {
    Object? body;
    try {
      final response = await _dio.post<dynamic>(
        ApiEndpoints.rightsChat,
        data: {'question': question},
      );
      body = response.data;
    } on DioException catch (e) {
      body = e.response?.data;
    } catch (_) {
      body = null;
    }

    if (body is Map) {
      final answer = body['answer'];
      if (answer is String && answer.isNotEmpty) return answer;
      return noAnswer;
    }
    throw const NetworkFailure(
      message: couldNotConnect,
      debugDetail: 'api/rights-chat: no JSON body',
    );
  }
}

/// My Case Status — `checkCaseStatus()`, citizen_dashboard.html:1073-1110.
class CaseStatusRemoteDataSource {
  const CaseStatusRemoteDataSource(this._dio);

  final Dio _dio;

  Future<CaseClientStatus> lookup(String firNo) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.caseClientStatus(firNo),
      );
      return CaseClientStatus.fromJson(
        citizenJsonObject(response.data, 'client-status'),
      );
    } catch (e) {
      throw citizenFailure(
        e,
        fallback: "Your lawyer hasn't shared this case's status yet.",
        network: _networkError,
        context: 'client-status',
      );
    }
  }
}

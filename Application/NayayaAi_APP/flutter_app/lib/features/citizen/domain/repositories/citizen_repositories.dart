import '../../../complaints/domain/entities/complaint.dart';
import '../../data/models/case_client_status.dart';
import '../../data/models/citizen_complaint_models.dart';

/// Contracts the citizen screens program against. Every method throws a
/// `Failure` whose message is already the website's wording for that page.

abstract interface class CitizenComplaintRepository {
  /// `POST /api/complaint`. Returns the receipt; only its tracking ID is shown.
  Future<ComplaintReceipt> file(ComplaintSubmission submission);

  /// `GET /api/complaint/<tracking_id>`.
  Future<Complaint> track(String trackingId);
}

abstract interface class RightsChatRepository {
  /// `POST /api/rights-chat`. Returns the answer text; throws a
  /// `NetworkFailure` carrying the website's "Could not connect…" otherwise.
  Future<String> ask(String question);
}

abstract interface class CaseStatusRepository {
  /// `GET /api/case/<fir_no>/client-status`.
  Future<CaseClientStatus> lookup(String firNo);
}

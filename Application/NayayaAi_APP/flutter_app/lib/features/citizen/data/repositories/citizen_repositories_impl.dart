import '../../../complaints/domain/entities/complaint.dart';
import '../../domain/repositories/citizen_repositories.dart';
import '../datasources/citizen_remote_data_sources.dart';
import '../models/case_client_status.dart';
import '../models/citizen_complaint_models.dart';

class CitizenComplaintRepositoryImpl implements CitizenComplaintRepository {
  const CitizenComplaintRepositoryImpl({
    required CitizenComplaintRemoteDataSource remote,
  }) : _remote = remote;

  final CitizenComplaintRemoteDataSource _remote;

  @override
  Future<ComplaintReceipt> file(ComplaintSubmission submission) =>
      _remote.file(submission);

  /// Upper-cased because the input is (`oninput` upper-cases it on the
  /// website) and the server upper-cases again before the lookup.
  @override
  Future<Complaint> track(String trackingId) =>
      _remote.track(trackingId.trim().toUpperCase());
}

class RightsChatRepositoryImpl implements RightsChatRepository {
  const RightsChatRepositoryImpl({required RightsChatRemoteDataSource remote})
      : _remote = remote;

  final RightsChatRemoteDataSource _remote;

  @override
  Future<String> ask(String question) => _remote.ask(question);
}

class CaseStatusRepositoryImpl implements CaseStatusRepository {
  const CaseStatusRepositoryImpl({required CaseStatusRemoteDataSource remote})
      : _remote = remote;

  final CaseStatusRemoteDataSource _remote;

  @override
  Future<CaseClientStatus> lookup(String firNo) => _remote.lookup(firNo.trim());
}

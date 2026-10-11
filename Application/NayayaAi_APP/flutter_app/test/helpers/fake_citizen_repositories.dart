import 'dart:async';

import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/citizen/data/models/case_client_status.dart';
import 'package:nayaya_app/features/citizen/data/models/citizen_complaint_models.dart';
import 'package:nayaya_app/features/citizen/domain/repositories/citizen_repositories.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint.dart';

/// Stands in for `/api/complaint` and `/api/complaint/<id>`.
class FakeCitizenComplaintRepository implements CitizenComplaintRepository {
  FakeCitizenComplaintRepository({
    this.receipt = const ComplaintReceipt(trackingId: 'CMP-1A2B3C4D'),
    Map<String, Complaint>? complaints,
    this.fileFailure,
  }) : complaints = complaints ?? {};

  ComplaintReceipt receipt;
  Map<String, Complaint> complaints;
  Failure? fileFailure;

  /// Holds [file] open until completed — for asserting the busy state.
  Completer<void>? gate;

  final List<ComplaintSubmission> filed = [];
  final List<String> tracked = [];

  @override
  Future<ComplaintReceipt> file(ComplaintSubmission submission) async {
    filed.add(submission);
    await gate?.future;
    final failure = fileFailure;
    if (failure != null) throw failure;
    return receipt;
  }

  @override
  Future<Complaint> track(String trackingId) async {
    tracked.add(trackingId);
    final found = complaints[trackingId.toUpperCase()];
    if (found == null) {
      throw const ValidationFailure(
        'Complaint not found. Check your tracking ID.',
      );
    }
    return found;
  }
}

/// Stands in for `/api/rights-chat`.
class FakeRightsChatRepository implements RightsChatRepository {
  FakeRightsChatRepository({this.answer = 'You have the **right** to bail.'});

  String answer;
  Failure? failure;
  final List<String> asked = [];

  @override
  Future<String> ask(String question) async {
    asked.add(question);
    final f = failure;
    if (f != null) throw f;
    return answer;
  }
}

/// Stands in for `/api/case/<fir>/client-status`.
class FakeCaseStatusRepository implements CaseStatusRepository {
  FakeCaseStatusRepository({Map<String, CaseClientStatus>? statuses})
      : statuses = statuses ?? {};

  Map<String, CaseClientStatus> statuses;
  final List<String> looked = [];

  @override
  Future<CaseClientStatus> lookup(String firNo) async {
    looked.add(firNo);
    final found = statuses[firNo];
    if (found == null) {
      throw const ValidationFailure('Status not available for this FIR');
    }
    return found;
  }
}

/// A complaint as `GET /api/complaint/<id>` returns one.
Complaint trackedComplaint({
  String trackingId = 'CMP-1A2B3C4D',
  String status = 'Pending',
  String firNo = '',
  String officerNotes = '',
  String incidentDate = '2026-08-01',
  String location = 'Andheri',
}) {
  return Complaint(
    trackingId: trackingId,
    fullName: 'Asha Rao',
    phone: '',
    incidentDescription: 'My phone was stolen at the station.',
    incidentDate: incidentDate,
    location: location,
    statusRaw: status,
    categoryRaw: 'Theft / Robbery',
    firNo: firNo,
    officerNotes: officerNotes,
    createdAt: '2026-08-09 02:31:00',
    updatedAt: '2026-08-09 02:31:00',
  );
}

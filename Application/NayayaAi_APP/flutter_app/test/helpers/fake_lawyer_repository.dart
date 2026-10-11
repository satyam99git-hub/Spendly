import 'dart:async';

import 'package:nayaya_app/core/error/failure.dart';
import 'package:nayaya_app/features/lawyer/data/datasources/lawyer_remote_data_source.dart';
import 'package:nayaya_app/features/lawyer/data/models/lawyer_models.dart';
import 'package:nayaya_app/features/lawyer/domain/repositories/lawyer_repository.dart';

/// A `firs` row as `/api/fir-records` returns it, with the lawyer columns.
Map<String, dynamic> firRow({
  String firNo = 'FIR001',
  String? status = 'Investigation',
  String complainant = 'Asha Rao',
  String sections = 'BNS 303',
  String? nextHearing,
  bool visible = false,
  String? clientNote,
  String assignedTo = 'LAWYER_ID',
}) =>
    {
      'fir_no': firNo,
      'status': status,
      'complainant_name': complainant,
      'act_sections': sections,
      'next_hearing_date': nextHearing,
      'dist': 'Pune',
      'ps': 'Shivajinagar PS',
      'fir_date': '2026-09-01',
      'occurrence_date': '2026-08-30',
      'details_of_accused': 'Unknown male, about 30',
      'statement': 'Phone snatched near the bus stop.',
      'visible_to_client': visible,
      'client_note': clientNote,
      'assigned_lawyer_id': assignedTo,
    };

/// Stands in for every lawyer endpoint, remembering what it was asked.
class FakeLawyerRepository implements LawyerRepository {
  FakeLawyerRepository({
    List<LawyerCase>? cases,
    List<CaseDeadline>? upcoming,
    List<CaseDraft>? allDrafts,
    LawyerProfile? profile,
  })  : caseList = cases ?? [LawyerCase.fromJson(firRow())],
        upcoming = upcoming ?? [],
        allDraftList = allDrafts ?? [],
        profileValue = profile ??
            const LawyerProfile(
              fullname: 'Meera Iyer',
              email: 'meera@example.com',
              uniqueId: 'LAW001',
            );

  List<LawyerCase> caseList;
  Object? casesFailure;
  List<CaseDeadline> upcoming;
  List<CaseDraft> allDraftList;
  LawyerProfile? profileValue;

  final Map<String, List<CaseHearing>> hearingsByFir = {};
  final Map<String, List<CaseDeadline>> deadlinesByFir = {};
  final Map<String, List<CaseDraft>> draftsByFir = {};
  final Map<String, List<CaseDocument>> documentsByFir = {};

  /// Thrown by [claim] when set.
  Failure? claimFailure;
  Failure? statusFailure;
  Failure? visibilityFailure;

  /// Returned by the AI calls; a thrown value stands for the 500 of LL-2.
  String? precedentAnswer = '## Key facts\n\nA **summary**.';
  Object? precedentFailure;
  String draftText = 'IN THE COURT OF SESSIONS';

  /// Holds [findPrecedents] open until completed.
  Completer<void>? aiGate;

  final List<String> claimed = [];
  final List<(String, String)> statusChanges = [];
  final List<(String, bool, String)> visibilityChanges = [];
  final List<(String, String, String)> hearingsAdded = [];
  final List<(String, String, String, String)> deadlinesAdded = [];
  final List<(String, Object?, bool)> deadlineToggles = [];
  final List<(String, Object?)> deadlinesDeleted = [];
  final List<(String, String, String)> draftsSaved = [];
  final List<(String, Object?)> draftsDeleted = [];
  final List<(bool, String)> draftPrompts = [];
  final List<String> precedentQueries = [];
  final List<LawyerProfileUpdate> profileSaves = [];
  int caseLoads = 0;

  @override
  Future<List<LawyerCase>> cases() async {
    caseLoads++;
    final f = casesFailure;
    if (f != null) throw f;
    return caseList;
  }

  @override
  Future<void> claim(String firNo) async {
    claimed.add(firNo.trim());
    final f = claimFailure;
    if (f != null) throw f;
  }

  @override
  Future<LawyerCase> caseDetail(String firNo) async {
    for (final c in caseList) {
      if (c.firNo == firNo) return c;
    }
    throw const LawyerSilentFailure('not found');
  }

  @override
  Future<void> updateStatus(String firNo, String status) async {
    statusChanges.add((firNo, status));
    final f = statusFailure;
    if (f != null) throw f;
  }

  @override
  Future<void> setClientVisibility(
    String firNo, {
    required bool visible,
    required String note,
  }) async {
    visibilityChanges.add((firNo, visible, note));
    final f = visibilityFailure;
    if (f != null) throw f;
  }

  @override
  Future<List<CaseDocument>> documents(String firNo) async =>
      documentsByFir[firNo] ?? const [];

  @override
  Future<List<CaseHearing>> hearings(String firNo) async =>
      hearingsByFir[firNo] ?? const [];

  @override
  Future<void> addHearing(String firNo, String date, String note) async {
    hearingsAdded.add((firNo, date, note));
    (hearingsByFir[firNo] ??= []).add(
      CaseHearing(hearingDate: date, note: note),
    );
  }

  @override
  Future<List<CaseDeadline>> deadlines(String firNo) async =>
      deadlinesByFir[firNo] ?? const [];

  @override
  Future<void> addDeadline(
    String firNo, {
    required String deadlineType,
    required String dueDate,
    required String note,
  }) async {
    deadlinesAdded.add((firNo, deadlineType, dueDate, note));
    final list = deadlinesByFir[firNo] ??= [];
    list.add(
      CaseDeadline(
        id: list.length + 1,
        firNo: firNo,
        deadlineType: deadlineType,
        dueDate: dueDate,
        note: note,
        completed: false,
      ),
    );
  }

  @override
  Future<void> setDeadlineCompleted(
    String firNo,
    Object? deadlineId, {
    required bool completed,
  }) async {
    deadlineToggles.add((firNo, deadlineId, completed));
  }

  @override
  Future<void> deleteDeadline(String firNo, Object? deadlineId) async {
    deadlinesDeleted.add((firNo, deadlineId));
    deadlinesByFir[firNo]?.removeWhere((d) => d.id == deadlineId);
  }

  @override
  Future<List<CaseDraft>> drafts(String firNo) async =>
      draftsByFir[firNo] ?? const [];

  @override
  Future<void> saveDraft(String firNo, String kind, String content) async {
    draftsSaved.add((firNo, kind, content));
    final list = draftsByFir[firNo] ??= [];
    list.insert(
      0,
      CaseDraft(
        id: list.length + 1,
        firNo: firNo,
        kind: kind,
        content: content,
        createdAt: '2026-09-28T10:00:00',
      ),
    );
  }

  @override
  Future<void> deleteDraft(String firNo, Object? draftId) async {
    draftsDeleted.add((firNo, draftId));
    draftsByFir[firNo]?.removeWhere((d) => d.id == draftId);
  }

  @override
  Future<String> generateDraft({
    required bool bail,
    required String prompt,
  }) async {
    draftPrompts.add((bail, prompt));
    return draftText;
  }

  @override
  Future<String?> findPrecedents(String query) async {
    precedentQueries.add(query);
    await aiGate?.future;
    final f = precedentFailure;
    if (f != null) throw f;
    return precedentAnswer;
  }

  @override
  Future<List<CaseDraft>> allDrafts() async => allDraftList;

  @override
  Future<List<CaseDeadline>> upcomingDeadlines() async => upcoming;

  @override
  Future<LawyerProfile?> profile() async => profileValue;

  @override
  Future<void> saveProfile(LawyerProfileUpdate update) async {
    profileSaves.add(update);
  }

  @override
  Future<String> uploadPhoto({
    required String path,
    required String filename,
  }) async =>
      'https://example.supabase.co/avatars/LAWYER_ID.jpg';
}

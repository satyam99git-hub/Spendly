import 'package:nayaya_app/features/complaints/domain/entities/complaint.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_category.dart';
import 'package:nayaya_app/features/complaints/domain/entities/complaint_status.dart';

/// A citizen's complaint for tests, in the shape `POST /api/complaint` writes
/// one: a name, a description, and whatever else the citizen chose to give.
///
/// Defaults deliberately, so a test that cares about one field says so by
/// passing it and everything else stays out of the way.
///
/// [createdAt] is in SQLite's `CURRENT_TIMESTAMP` spelling — `YYYY-MM-DD
/// HH:MM:SS`, UTC, no zone marker — because that is what the complaints table
/// actually holds, and half of what is worth testing here is whether the app
/// reads it as UTC rather than as local time.
Complaint aComplaint({
  String trackingId = 'CMP-1A2B3C4D',
  String fullName = 'R. Iyer',
  String phone = '9876543210',
  String incidentDescription =
      'Two men took my phone near the bus stand at about nine at night.',
  String incidentDate = '2026-08-07',
  String location = 'Sector 14 bus stand',
  ComplaintStatus? status = ComplaintStatus.pending,
  String? statusRaw,
  // Agrees with the default narrative, which the server's keyword table reads
  // as a theft. Pass `category: null, categoryRaw: ''` for a row filed before
  // the categoriser existed.
  ComplaintCategory? category = ComplaintCategory.theft,
  String? categoryRaw,
  bool? isCognizable,
  String firNo = '',
  String officerNotes = '',
  String createdAt = '2026-08-09 06:30:00',
  String? updatedAt,
}) {
  return Complaint(
    trackingId: trackingId,
    fullName: fullName,
    phone: phone,
    incidentDescription: incidentDescription,
    incidentDate: incidentDate,
    location: location,
    // `statusRaw` wins when given, so a test can put a value in the column that
    // no [ComplaintStatus] matches — which is a state the real table can be in,
    // since only the PATCH handler validates and nothing constrains the column.
    statusRaw: statusRaw ?? status?.wireValue ?? '',
    // Same arrangement as `statusRaw`: the raw value wins, so a test can put a
    // category in the column that this app has never heard of.
    categoryRaw: categoryRaw ?? category?.wireValue ?? '',
    isCognizableRaw: isCognizable,
    firNo: firNo,
    officerNotes: officerNotes,
    createdAt: createdAt,
    // Equal to `createdAt` unless a test says otherwise: the insert writes both
    // from the same `CURRENT_TIMESTAMP`, so that is what an untouched complaint
    // looks like, and `Complaint.wasUpdated` reads exactly this difference.
    updatedAt: updatedAt ?? createdAt,
  );
}

/// The JSON `GET /api/complaints/all` answers with, for a model test.
///
/// Values are `null` rather than absent where the table's columns are nullable
/// and unset, because that is what `jsonify` sends for them — and a client that
/// only handles missing keys would still throw on a real inbox.
Map<String, dynamic> aComplaintRow({
  String trackingId = 'CMP-1A2B3C4D',
  String? firNo,
  String? officerNotes,
  Object? phone = '9876543210',
  String status = 'Pending',
  // Derived server-side from the description by `complaint_categorizer.py`.
  // Defaults agree with the narrative below, which the keyword table reads as
  // a theft. `Object?` rather than `bool?` because SQLite has no boolean and
  // the column arrives as 0/1 — a test needs to be able to send that.
  Object? category = 'Theft / Robbery',
  Object? isCognizable = 1,
}) {
  return {
    'tracking_id': trackingId,
    'full_name': 'R. Iyer',
    'phone': phone,
    'incident_description': 'Phone taken near the bus stand.',
    'incident_date': '2026-08-07',
    'location': 'Sector 14 bus stand',
    'status': status,
    'category': category,
    'is_cognizable': isCognizable,
    'fir_no': firNo,
    'officer_notes': officerNotes,
    'created_at': '2026-08-09 06:30:00',
    'updated_at': '2026-08-09 06:30:00',
  };
}

/// Wire models for the three complaints endpoints.
///
/// Hand-written, like the FIR and auth models: two shapes in and one out, and
/// build_runner would cost more than it saves.
library;

import '../../domain/entities/complaint.dart';
import '../../domain/entities/complaint_status.dart';

/// One row of `citizen_complaints`, as `GET /api/complaints/all` and
/// `GET /api/complaint/<id>` return it.
///
/// **The two are not the same shape**, and this reads both. The list handler
/// selects eleven columns; the single-complaint handler selects ten and leaves
/// out `phone`. Missing keys therefore have to be ordinary, not exceptional —
/// every field falls back to empty rather than throwing, which is also what
/// keeps an older or newer server from taking the whole inbox down over one
/// renamed column.
class ComplaintResponse {
  const ComplaintResponse._();

  static Complaint fromJson(Map<String, dynamic> json) {
    String text(String key) => _text(json, key);

    return Complaint(
      // Upper-cased here rather than at every comparison site. The server
      // generates IDs in upper case and upper-cases them again on lookup, so a
      // row that somehow holds a lower-case one is still the same complaint —
      // and the detail screen matches on this string.
      trackingId: text('tracking_id').toUpperCase(),
      fullName: text('full_name'),
      phone: text('phone'),
      incidentDescription: text('incident_description'),
      incidentDate: text('incident_date'),
      location: text('location'),
      statusRaw: text('status'),
      categoryRaw: text('category'),
      isCognizableRaw: _boolOrNull(json['is_cognizable']),
      firNo: text('fir_no'),
      officerNotes: text('officer_notes'),
      createdAt: text('created_at'),
      updatedAt: text('updated_at'),
    );
  }
}

/// The `PATCH /api/complaints/<tracking_id>` body.
///
/// All three keys, always. The handler writes every one of them into the row
/// unconditionally — `SET status = ?, fir_no = ?, officer_notes = ?` — reading
/// each with `data.get(...)`, so a key left out of the JSON is stored as NULL
/// rather than left alone. Sending a partial body is how an officer closing a
/// complaint silently erases the notes they wrote on it an hour earlier.
///
/// This class exists to make that impossible to get wrong: there is no
/// constructor that omits a field.
class ComplaintUpdate {
  const ComplaintUpdate({
    required this.status,
    required this.firNo,
    required this.officerNotes,
  });

  /// Validated server-side against the four values in [ComplaintStatus]. Any
  /// other string is HTTP 400 `{"error": "Invalid status"}`.
  final ComplaintStatus status;

  final String firNo;
  final String officerNotes;

  Map<String, dynamic> toJson() => {
        'status': status.wireValue,
        'fir_no': firNo.trim(),
        'officer_notes': officerNotes.trim(),
      };
}

/// Reads one column as text, whatever it arrives as.
///
/// SQLite columns are nullable and the PATCH handler writes whatever JSON hands
/// it, so `fir_no` and `officer_notes` are genuinely null on most rows and
/// `phone` can arrive as a number if anything ever posts one. `toString()`
/// reads all of them; a cast would throw on the first NULL.
String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString().trim();
}


/// Reads `is_cognizable`, which SQLite has no boolean for.
///
/// The column is an INTEGER holding 0 or 1, and Python's `sqlite3` hands it to
/// `jsonify` as an int — but the same row can come back as a real JSON boolean
/// from a handler that built the dict itself, and as a string from a row edited
/// by hand in a SQLite browser. All three mean the same thing.
///
/// Null is preserved rather than defaulted to false. A row filed before the
/// categoriser existed carries no value at all, and "the server never said" is
/// not the same finding as "the server said this is not cognizable" — one of
/// those is a triage decision and the other is silence.
bool? _boolOrNull(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value.toString().trim().toLowerCase();
  if (text.isEmpty) return null;
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

import '../../../../core/utils/form_dates.dart';
import '../../../../core/utils/server_time.dart';
import 'complaint_category.dart';
import 'complaint_status.dart';

/// One complaint a citizen filed, as the `citizen_complaints` table holds it.
///
/// Every field is a non-null [String] for the same reason [FirDraft] and
/// [FirRecord] are: the columns are nullable TEXT in SQLite and the handler
/// inserts `''` for anything the citizen left out, so `null` and `''` would be
/// two spellings of "not answered" travelling through the app together. The one
/// exception is [status], which is nullable *on purpose* — see below.
class Complaint {
  const Complaint({
    required this.trackingId,
    this.fullName = '',
    this.phone = '',
    this.incidentDescription = '',
    this.incidentDate = '',
    this.location = '',
    this.statusRaw = '',
    this.categoryRaw = '',
    this.isCognizableRaw,
    this.firNo = '',
    this.officerNotes = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  // ---- identity -------------------------------------------------------------

  /// `CMP-1A2B3C4D`. The only handle anything has on this complaint: it is what
  /// the citizen was given, what both read routes are keyed on, and what the
  /// PATCH addresses. The server upper-cases it on every lookup.
  final String trackingId;

  // ---- what the citizen filed -----------------------------------------------

  final String fullName;

  /// Usually the fastest way to progress a complaint, and the reason the detail
  /// screen resolves out of `/api/complaints/all` — see `ApiEndpoints.complaint`,
  /// whose SELECT omits this column.
  final String phone;

  /// The narrative. Required by the server at filing time, so in practice never
  /// empty.
  final String incidentDescription;

  /// When the incident happened, as the citizen typed it.
  ///
  /// **Free text, not a date.** The website posts an `<input type="date">`, so
  /// most rows hold `yyyy-MM-dd` — but the column takes whatever arrives and the
  /// API accepts a bare string, so "last Tuesday" and "" are both real values
  /// already in the table. Displayed through [FormDates.displayDate], which
  /// passes anything it cannot parse straight through, and deliberately *not*
  /// what the date filter works on; see [ComplaintFilter].
  final String incidentDate;

  final String location;

  // ---- what the server made of it -------------------------------------------

  /// The `category` column verbatim — `Theft / Robbery`, `Other / Needs Review`.
  ///
  /// Derived server-side from [incidentDescription] by keyword match at filing
  /// time; the citizen was never asked. Kept raw beside [category] for the same
  /// reason [statusRaw] is: the column has no constraint, older rows predate the
  /// categoriser and hold nothing at all, and printing an unrecognised word is
  /// more use to an officer than folding it into a bucket the server did not
  /// choose.
  final String categoryRaw;

  /// The `is_cognizable` column, or null when the row does not carry one.
  ///
  /// Read in preference to [ComplaintCategory.isCognizable] — see
  /// [isCognizable]. SQLite has no boolean, so this arrives as 0/1 and the
  /// model converts; the field is nullable because "the row never said" and
  /// "the row said no" are different facts and only one of them is a finding.
  final bool? isCognizableRaw;

  // ---- what the station has done about it -----------------------------------

  /// The status column verbatim.
  ///
  /// Kept raw next to [status] rather than parsed into it, because the column
  /// has no CHECK constraint and a row can hold a word this app does not know.
  /// Showing that word is honest; folding it into "Pending" would tell an officer
  /// the complaint is untouched when the desk may have marked it something else.
  final String statusRaw;

  /// The FIR registered for this complaint, when one was. Written by the app's
  /// own conversion flow and by the website's console.
  final String firNo;

  /// Free text an officer wrote. Appended to rather than replaced by "escalate",
  /// so the trail of what was decided and when survives.
  final String officerNotes;

  // ---- server metadata ------------------------------------------------------

  /// SQLite's `CURRENT_TIMESTAMP` — `2026-08-09 02:31:00`, UTC. Parsed by
  /// [ServerTime], never by hand.
  final String createdAt;

  /// Bumped by the PATCH handler on every update, in the same spelling.
  final String updatedAt;

  // ---- derived --------------------------------------------------------------

  /// The status as one of the four the server accepts, or null when the column
  /// holds something else. See [ComplaintStatus.fromWire].
  ComplaintStatus? get status => ComplaintStatus.fromWire(statusRaw);

  /// What to print for the status: the known label, or the stored word when the
  /// app does not recognise it, or a stand-in when the column is empty.
  String get statusLabel {
    final known = status;
    if (known != null) return known.label;
    final raw = statusRaw.trim();
    return raw.isEmpty ? 'No status' : raw;
  }

  /// The category as one the app knows, or null when the column holds something
  /// else or nothing. See [ComplaintCategory.fromWire].
  ComplaintCategory? get category => ComplaintCategory.fromWire(categoryRaw);

  /// What to print for the category: the known label, the stored word when the
  /// app does not recognise it, or a stand-in when the column is empty.
  ///
  /// "Not categorised" rather than "Needs review": a row filed before the
  /// categoriser existed was never looked at by it, and saying it needs review
  /// would report a triage decision that was never made.
  String get categoryLabel {
    final known = category;
    if (known != null) return known.label;
    final raw = categoryRaw.trim();
    return raw.isEmpty ? 'Not categorised' : raw;
  }

  /// Whether an FIR can normally be registered on this complaint.
  ///
  /// The row's own column first, the category's default behind it, and `false`
  /// when neither says. The row wins because both come from the same keyword
  /// table in `complaint_categorizer.py` and only the row was written by the
  /// version of it that ran.
  ///
  /// **Advisory, and nothing in this app may enforce it.** It is what a keyword
  /// matcher concluded from the words a distressed person happened to use, and
  /// an officer who reads the narrative and disagrees registers the FIR anyway.
  /// The website shows it as a tooltip on a pill for exactly that reason; this
  /// app shows it the same way.
  bool get isCognizable => isCognizableRaw ?? category?.isCognizable ?? false;

  /// True when the row carries a category the app could read.
  bool get hasCategory => categoryRaw.trim().isNotEmpty;

  /// True when the station still owes this complaint an answer. An unrecognised
  /// status counts as open: something was written there that nobody has told the
  /// app how to close, and hiding it from the inbox is how a complaint gets lost.
  bool get isOpen => status?.isOpen ?? true;

  bool get hasFir => firNo.trim().isNotEmpty;
  bool get hasNotes => officerNotes.trim().isNotEmpty;
  bool get hasPhone => phone.trim().isNotEmpty;

  /// When the complaint reached the station, as a UTC instant, or null when the
  /// column was empty or unreadable. Backs both the ordering and the date filter.
  DateTime? get receivedAt => ServerTime.parse(createdAt);

  /// `9 Aug 2026` for a list row.
  String get receivedOnDisplay => ServerTime.displayDay(createdAt);

  /// `9 Aug 2026, 02:31 UTC` for the detail screen.
  String get receivedAtDisplay => ServerTime.display(createdAt);

  /// Same, for the last time anybody touched it. Empty when it has never been
  /// updated in a way the server recorded.
  String get updatedAtDisplay => ServerTime.display(updatedAt);

  /// True when the complaint has been acted on since it arrived.
  ///
  /// The two columns are written by the same `CURRENT_TIMESTAMP` on insert, so
  /// they are equal until the first PATCH. Compared as instants rather than as
  /// strings so a difference in spelling cannot read as a difference in time.
  bool get wasUpdated {
    final created = receivedAt;
    final updated = ServerTime.parse(updatedAt);
    if (created == null || updated == null) return false;
    return updated.isAfter(created);
  }

  /// The incident date as written, e.g. `12 Aug 2026`, or the citizen's own words
  /// when it is not a date at all.
  String get incidentDateDisplay => FormDates.displayDate(incidentDate);

  /// A one-line summary for the list row: who filed it and where it happened.
  String get summaryLine {
    final parts = [
      if (fullName.trim().isNotEmpty) fullName.trim(),
      if (location.trim().isNotEmpty) location.trim(),
    ];
    return parts.isEmpty ? 'No name recorded' : parts.join(' · ');
  }

  // ---- search ---------------------------------------------------------------

  /// Whether this complaint answers [lowercaseQuery], which the caller has
  /// already trimmed and lowercased.
  ///
  /// **The narrative is searched here, unlike in [FirRecord.matches].** The two
  /// screens are answering different questions. An officer opening FIR history
  /// is looking up a record they already have a number or a name for; an officer
  /// working the complaints inbox is looking for the ones that are *about*
  /// something — the three thefts from the same market, the calls about one
  /// address — and the only place that lives is the description. The tile prints
  /// the first lines of it, so a hit always has something visible explaining why
  /// the row is on screen.
  bool matches(String lowercaseQuery) {
    if (lowercaseQuery.isEmpty) return true;
    for (final field in [
      trackingId,
      fullName,
      phone,
      location,
      firNo,
      incidentDescription,
      officerNotes,
      categoryRaw,
    ]) {
      if (field.toLowerCase().contains(lowercaseQuery)) return true;
    }
    return false;
  }

  // ---- copy -----------------------------------------------------------------

  /// Null means "leave as it was". Clearing a field is `copyWith(x: '')` — an
  /// empty string is a real value here, not an absence.
  Complaint copyWith({
    String? trackingId,
    String? fullName,
    String? phone,
    String? incidentDescription,
    String? incidentDate,
    String? location,
    String? statusRaw,
    String? categoryRaw,
    bool? isCognizableRaw,
    String? firNo,
    String? officerNotes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Complaint(
      trackingId: trackingId ?? this.trackingId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      incidentDescription: incidentDescription ?? this.incidentDescription,
      incidentDate: incidentDate ?? this.incidentDate,
      location: location ?? this.location,
      statusRaw: statusRaw ?? this.statusRaw,
      categoryRaw: categoryRaw ?? this.categoryRaw,
      isCognizableRaw: isCognizableRaw ?? this.isCognizableRaw,
      firNo: firNo ?? this.firNo,
      officerNotes: officerNotes ?? this.officerNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Complaint($trackingId, $statusLabel)';
}

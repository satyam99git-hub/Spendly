import '../../domain/entities/lawyer_content.dart';

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString().trim();
}

// ---- cases ------------------------------------------------------------------

/// One row of Supabase `firs` as the lawyer page reads it — a card on My Cases
/// (lawyer_dashboard.html:438-454) and the Case Workspace (lines 876-897).
///
/// [raw] is kept because the AI prompts print the row's values the way a
/// JavaScript template literal does, `null` and `undefined` included, and a
/// trimmed string cannot say which of those it was.
class LawyerCase {
  const LawyerCase({required this.raw});

  factory LawyerCase.fromJson(Map<String, dynamic> json) =>
      LawyerCase(raw: Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> raw;

  String get firNo => _text(raw, 'fir_no');
  String get status => _text(raw, 'status');
  String get complainantName => _text(raw, 'complainant_name');
  String get actSections => _text(raw, 'act_sections');
  String get nextHearingDate => _text(raw, 'next_hearing_date');
  String get assignedLawyerId => raw['assigned_lawyer_id']?.toString() ?? '';

  /// `!!data.visible_to_client` (line 890).
  bool get visibleToClient => jsTruthy(raw['visible_to_client']);

  /// `data.client_note || ''` (line 889).
  String get clientNote => jsOr(raw['client_note'], '');

  /// `x || '—'`, as every Overview field is filled (lines 884-897).
  String field(String key) => jsOr(raw[key], '—');

  /// The pill's text: `status or 'Active'` (lines 445-446, 886).
  String get statusLabel => jsOr(raw['status'], 'Active');

  /// The pill's CSS class suffix and the card's `data-status`:
  /// `(status or 'active')|lower|replace(' ', '-')`.
  String get statusKey => statusKeyOf(raw['status']);

  /// `{{ case.<key> }}` on the card: Jinja prints a null as `None` and a
  /// missing key as nothing.
  String jinja(String key) {
    if (!raw.containsKey(key)) return '';
    final value = raw[key];
    return value == null ? 'None' : value.toString();
  }

  /// `{{ case.next_hearing_date or "—" }}` (line 452).
  String get nextHearingLabel => jsOr(raw['next_hearing_date'], '—');

  /// Everything the card shows, lower-cased — what the search box matches
  /// with `card.innerText.toLowerCase().includes(q)` (lines 1415-1420).
  String get searchText => [
        'FIR: ${jinja('fir_no')}',
        statusLabel,
        'Client: ${jinja('complainant_name')}',
        'Sections: ${jinja('act_sections')}',
        'Next Hearing: $nextHearingLabel',
      ].join('\n').toLowerCase();
}

String statusKeyOf(Object? status) =>
    jsOr(status, 'active').toLowerCase().replaceAll(RegExp(r'\s+'), '-');

/// The four numbers on Home and My Cases, and the Home "Upcoming Hearings"
/// strip — `computeStatsAndHearings()` (lines 1423-1471), computed as it is,
/// from the cases alone.
class LawyerCaseStats {
  const LawyerCaseStats({
    required this.total,
    required this.investigation,
    required this.courtProceedings,
    required this.upcomingHearings,
  });

  /// Only `investigation` and `court-proceedings` are counted; Trial and
  /// Closed have no card (line 1425).
  factory LawyerCaseStats.of(List<LawyerCase> cases, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final weekAhead = at.add(const Duration(days: 7));
    var investigation = 0;
    var court = 0;
    final upcoming = <UpcomingHearing>[];

    for (final c in cases) {
      if (c.statusKey == 'investigation') investigation++;
      if (c.statusKey == 'court-proceedings') court++;

      final hearing = c.nextHearingDate;
      if (hearing.isEmpty) continue;
      final when = parseJsDate(hearing);
      if (when == null) continue;
      if (!when.isBefore(at) && !when.isAfter(weekAhead)) {
        upcoming.add(UpcomingHearing(c.firNo, hearing, when));
      }
    }
    upcoming.sort((a, b) => a.when.compareTo(b.when));

    return LawyerCaseStats(
      total: cases.length,
      investigation: investigation,
      courtProceedings: court,
      upcomingHearings: upcoming,
    );
  }

  final int total;
  final int investigation;
  final int courtProceedings;

  /// "Hearings This Week" is this list's length.
  final List<UpcomingHearing> upcomingHearings;
}

class UpcomingHearing {
  const UpcomingHearing(this.firNo, this.date, this.when);

  final String firNo;

  /// Shown as stored, as `${h.date}` shows it.
  final String date;
  final DateTime when;
}

/// `new Date(str)` for the strings Supabase returns.
///
/// A bare `YYYY-MM-DD` is read by JavaScript as **UTC** midnight, not local —
/// which is why a hearing dated today has usually already "passed" on the
/// website's Home and is left out of the week (D4 §4.1). Anything else parses
/// as ISO 8601 does in both languages.
DateTime? parseJsDate(String value) {
  final text = value.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return DateTime.tryParse('${text}T00:00:00Z');
  }
  return DateTime.tryParse(text);
}

/// `new Date().toISOString().split('T')[0]` — today's date **in UTC**, which is
/// what the deadline lists compare `due_date` against (lines 1090, 1184).
String jsTodayUtc({DateTime? now}) {
  final utc = (now ?? DateTime.now()).toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}';
}

// ---- hearings, deadlines, drafts, documents ---------------------------------

/// A `case_hearings` row (lines 1043-1048 show date and note).
class CaseHearing {
  const CaseHearing({required this.hearingDate, required this.note});

  factory CaseHearing.fromJson(Map<String, dynamic> json) => CaseHearing(
        hearingDate: json['hearing_date']?.toString() ?? '',
        note: jsOr(json['note'], ''),
      );

  final String hearingDate;
  final String note;
}

/// A `case_deadlines` row.
class CaseDeadline {
  const CaseDeadline({
    required this.id,
    required this.firNo,
    required this.deadlineType,
    required this.dueDate,
    required this.note,
    required this.completed,
  });

  factory CaseDeadline.fromJson(Map<String, dynamic> json) => CaseDeadline(
        id: json['id'],
        firNo: json['fir_no']?.toString() ?? '',
        deadlineType: json['deadline_type']?.toString() ?? '',
        dueDate: json['due_date']?.toString() ?? '',
        note: jsOr(json['note'], ''),
        completed: jsTruthy(json['completed']),
      );

  /// Passed back into the URL as it came (`${d.id}`).
  final Object? id;
  final String firNo;
  final String deadlineType;
  final String dueDate;
  final String note;
  final bool completed;

  /// `d.due_date < today`, a string comparison on the UTC date (line 1093).
  bool isPastDue(String todayUtc) => dueDate.compareTo(todayUtc) < 0;
}

/// A `case_drafts` row.
class CaseDraft {
  const CaseDraft({
    required this.id,
    required this.firNo,
    required this.kind,
    required this.content,
    required this.createdAt,
  });

  factory CaseDraft.fromJson(Map<String, dynamic> json) => CaseDraft(
        id: json['id'],
        firNo: json['fir_no']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );

  final Object? id;
  final String firNo;
  final String kind;
  final String content;

  /// Shown raw, as the website shows it.
  final String createdAt;

  /// `class="capitalize"` — the first letter of each word upper-cased.
  String get kindLabel => kind
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// One file from `GET /api/evidence?fir_no=` (lines 1018-1024).
class CaseDocument {
  const CaseDocument({
    required this.filename,
    required this.fileType,
    required this.fileUrl,
  });

  factory CaseDocument.fromJson(Map<String, dynamic> json) => CaseDocument(
        filename: json['filename']?.toString() ?? '',
        fileType: json['file_type']?.toString() ?? '',
        fileUrl: json['file_url']?.toString() ?? '',
      );

  final String filename;

  /// The server's category — image, video, audio, pdf or other.
  final String fileType;

  /// Server-relative, e.g. `/evidence-file/FIR001/a.jpg`.
  final String fileUrl;
}

// ---- profile ----------------------------------------------------------------

/// `GET /api/lawyer/profile` (app.py:2535-2553).
class LawyerProfile {
  const LawyerProfile({
    this.fullname = '',
    this.email = '',
    this.uniqueId = '',
    this.phone = '',
    this.officeAddress = '',
    this.bio = '',
    this.yearsExperience = '',
    this.barEnrollmentNo = '',
    this.practiceArea = '',
    this.photoUrl = '',
  });

  factory LawyerProfile.fromJson(Map<String, dynamic> json) {
    String text(String key) => jsOr(json[key], '');
    return LawyerProfile(
      fullname: text('fullname'),
      email: text('email'),
      uniqueId: text('unique_id'),
      phone: text('phone'),
      officeAddress: text('office_address'),
      bio: text('bio'),
      yearsExperience: text('years_experience'),
      barEnrollmentNo: text('bar_enrollment_no'),
      practiceArea: text('practice_area'),
      photoUrl: text('photo_url'),
    );
  }

  final String fullname;
  final String email;
  final String uniqueId;
  final String phone;
  final String officeAddress;
  final String bio;
  final String yearsExperience;
  final String barEnrollmentNo;
  final String practiceArea;
  final String photoUrl;
}

/// The body `saveProfile()` sends — all six fields, always (lines 1699-1706).
class LawyerProfileUpdate {
  const LawyerProfileUpdate({
    required this.phone,
    required this.officeAddress,
    required this.barEnrollmentNo,
    required this.yearsExperience,
    required this.practiceArea,
    required this.bio,
  });

  final String phone;
  final String officeAddress;
  final String barEnrollmentNo;
  final String yearsExperience;
  final String practiceArea;
  final String bio;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'office_address': officeAddress,
        'bar_enrollment_no': barEnrollmentNo,
        'years_experience': yearsExperience,
        'practice_area': practiceArea,
        'bio': bio,
      };

  /// The page's own checks, in its order, with its words (lines 1685-1697).
  /// Null when the profile may be sent.
  String? validate() {
    if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Phone number must be exactly 10 digits.';
    }
    if (yearsExperience.isNotEmpty &&
        (!RegExp(r'^\d+$').hasMatch(yearsExperience) ||
            int.parse(yearsExperience) > 60)) {
      return 'Years of experience must be a number up to 60.';
    }
    return null;
  }
}

/// The shapes the Judge Portal reads, each parsed the way
/// `judge_dashboard.html` (JD) reads the same JSON.
library;

/// What `${escapeHtml(x)}` prints: nothing for null or undefined, the value as
/// text otherwise.
String jsText(Object? value) => value == null ? '' : value.toString();

/// `x || fallback`, for the strings and numbers these rows hold.
String jsOrText(Object? value, String fallback) {
  if (value == null || value == false || value == 0 || value == '') {
    return fallback;
  }
  return value.toString();
}

/// `new Date(s)` for the date strings this server stores: `YYYY-MM-DD HH:MM`
/// as the page sends it, or the ISO form a timestamp column returns. Null for
/// anything JavaScript would call an Invalid Date, which every comparison on
/// the page then treats as false.
DateTime? jsDate(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  return DateTime.tryParse(v);
}

// ---- the docket --------------------------------------------------------------

/// One row of Supabase `case_docket` (SS:164-173), as `GET /judge/docket`
/// returns it.
class DocketEntry {
  const DocketEntry({required this.raw});

  factory DocketEntry.fromJson(Map<String, dynamic> json) =>
      DocketEntry(raw: Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> raw;

  /// The route takes `<int:entry_id>`, so the id is an integer.
  int? get id {
    final v = raw['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}');
  }

  String get caseId => jsText(raw['case_id']);

  /// Shown exactly as stored, as the page does (JD:616, 648, 813).
  String get hearingDate => jsText(raw['hearing_date']);
  String get caseType => jsText(raw['case_type']);
  String get urgency => jsText(raw['urgency']);
  String get status => jsText(raw['status']);
  String get remarks => jsText(raw['remarks']);

  DateTime? get hearingAt => jsDate(hearingDate);

  bool get isUrgent => raw['urgency'] == 'urgent';
}

/// The four Home numbers (`updateStats`, JD:623-635).
class DocketStats {
  const DocketStats({
    required this.total,
    required this.urgent,
    required this.scheduled,
    required this.thisWeek,
  });

  factory DocketStats.of(List<DocketEntry> entries, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final weekAhead = t.add(const Duration(days: 7));
    return DocketStats(
      total: entries.length,
      urgent: entries.where((e) => e.raw['urgency'] == 'urgent').length,
      scheduled: entries.where((e) => e.raw['status'] == 'scheduled').length,
      thisWeek: entries.where((e) {
        final d = e.hearingAt;
        return d != null && !d.isBefore(t) && !d.isAfter(weekAhead);
      }).length,
    );
  }

  final int total;
  final int urgent;
  final int scheduled;
  final int thisWeek;
}

/// Home's "Upcoming Hearings" (`renderUpcomingHearings`, JD:596-621):
/// scheduled entries from now on, soonest first, at most five.
List<DocketEntry> upcomingHearings(List<DocketEntry> entries, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final upcoming = [
    for (final e in entries)
      if (e.raw['status'] == 'scheduled' &&
          e.hearingAt != null &&
          !e.hearingAt!.isBefore(t))
        e,
  ]..sort((a, b) => a.hearingAt!.compareTo(b.hearingAt!));
  return upcoming.take(5).toList();
}

/// One card of the Case Workspace (`loadWorkspace`, JD:770-801): every entry
/// for one `case_id`, in the server's order.
class WorkspaceCase {
  const WorkspaceCase(this.caseId, this.entries);

  final String caseId;
  final List<DocketEntry> entries;

  /// `items[items.length - 1]` — the card's type and status come from here.
  DocketEntry get latest => entries.last;

  /// `items[0]?.case_type || "General"` — the detail header uses the first.
  String get detailType => jsOrText(entries.first.raw['case_type'], 'General');

  /// "N hearing" / "N hearings".
  String get hearingCount =>
      '${entries.length} hearing${entries.length != 1 ? 's' : ''}';

  /// The timeline, oldest first (JD:810). Entries whose date cannot be read
  /// keep their place relative to each other.
  List<DocketEntry> get timeline {
    final indexed = [for (var i = 0; i < entries.length; i++) (i, entries[i])];
    indexed.sort((a, b) {
      final da = a.$2.hearingAt;
      final db = b.$2.hearingAt;
      if (da == null || db == null) return a.$1.compareTo(b.$1);
      final c = da.compareTo(db);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Groups as the page does: one card per `case_id`, in first-seen order.
  static List<WorkspaceCase> group(List<DocketEntry> entries) {
    final map = <String, List<DocketEntry>>{};
    for (final e in entries) {
      (map[e.caseId] ??= []).add(e);
    }
    return [for (final kv in map.entries) WorkspaceCase(kv.key, kv.value)];
  }
}

/// What the hearing modal sends (JD:740-747). The same body goes to both
/// `POST /judge/docket` and `PUT /judge/docket/<id>`; the server ignores
/// `status` on create and `case_id` on edit (analysis GJ-3).
class DocketPayload {
  const DocketPayload({
    required this.caseId,
    required this.hearingDate,
    required this.caseType,
    required this.urgency,
    required this.status,
    required this.remarks,
  });

  final String caseId;

  /// `YYYY-MM-DD HH:MM` — the `datetime-local` value with `T` replaced by a
  /// space (JD:723).
  final String hearingDate;
  final String caseType;
  final String urgency;
  final String status;
  final String remarks;

  Map<String, dynamic> toJson() => {
        'case_id': caseId,
        'hearing_date': hearingDate,
        'case_type': caseType,
        'urgency': urgency,
        'status': status,
        'remarks': remarks,
      };
}

/// `YYYY-MM-DDTHH:MM`, the value a `datetime-local` input holds.
String localInputValue(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
      'T${two(d.hour)}:${two(d.minute)}';
}

/// What the edit modal's date box shows for a stored value:
/// `entry.hearing_date.replace(" ", "T")` (JD:667), which the browser then
/// normalises, or empties when it is not a local date-time (an offset such as
/// `+00:00` is not accepted by `datetime-local`).
///
/// Kept to the minute, the precision of the app's picker; a stored value with
/// non-zero seconds is the one case where the page would keep them.
String editInputValue(String stored) {
  final m = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(:\d{2}(\.\d+)?)?$')
      .firstMatch(stored.replaceFirst(' ', 'T'));
  if (m == null || DateTime.tryParse('${m[1]}T${m[2]}') == null) return '';
  return '${m[1]}T${m[2]}';
}

// ---- FIR records (read only) -------------------------------------------------

/// One `firs` row as the judge page reads it — the autocomplete (JD:519-552)
/// and the workspace's FIR details (JD:826-830).
class JudgeFir {
  const JudgeFir({required this.raw});

  factory JudgeFir.fromJson(Map<String, dynamic> json) =>
      JudgeFir(raw: Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> raw;

  String get firNo => jsText(raw['fir_no']);

  /// `(f.fir_no || '').toLowerCase().includes(val)` on three fields.
  bool matches(String lowerQuery) => [
        raw['fir_no'],
        raw['complainant_name'],
        raw['dist'],
      ].any((v) => jsOrText(v, '').toLowerCase().contains(lowerQuery));

  /// The suggestion's second line: `${complainant_name || ''} — ${dist || ''}`.
  String get suggestionSubtitle =>
      '${jsOrText(raw['complainant_name'], '')} — ${jsOrText(raw['dist'], '')}';

  /// The green preview line (JD:552).
  String get previewLine =>
      '✓ ${jsOrText(raw['complainant_name'], 'Unknown')} · '
      '${jsOrText(raw['dist'], '')} · '
      '${jsOrText(raw['act_sections'], 'No sections')}';

  /// `fir.<key> || '-'` (JD:826-830).
  String field(String key) => jsOrText(raw[key], '-');
}

/// The suggestions for what is typed in the Case ID box (`searchFirDropdown`,
/// JD:509-539). Empty input means no dropdown, so null.
List<JudgeFir>? firSuggestions(List<JudgeFir> all, String typed, {int? limit}) {
  final val = typed.trim().toLowerCase();
  if (val.isEmpty) return null;
  return all.where((f) => f.matches(val)).take(limit ?? 8).toList();
}

// ---- bookmarks ---------------------------------------------------------------

/// One bookmark as the page stores it in `localStorage`
/// (`{act, section, title}`, JD:1014).
class JudgeBookmark {
  const JudgeBookmark({
    required this.act,
    required this.section,
    required this.title,
  });

  factory JudgeBookmark.fromJson(Map<String, dynamic> json) => JudgeBookmark(
        act: jsText(json['act']),
        section: jsText(json['section']),
        title: jsText(json['title']),
      );

  final String act;
  final String section;
  final String title;

  Map<String, dynamic> toJson() =>
      {'act': act, 'section': section, 'title': title};

  bool same(String act, String section) =>
      this.act == act && this.section == section;
}

// ---- precedent research ------------------------------------------------------

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

/// `POST /judge/precedents`'s answer (app.py:2066-2078), kept as the maps the
/// page reads so every field prints the way `escapeHtml` would.
class PrecedentResearch {
  const PrecedentResearch({required this.raw});

  factory PrecedentResearch.fromJson(Map<String, dynamic> json) =>
      PrecedentResearch(raw: Map<String, dynamic>.unmodifiable(json));

  final Map<String, dynamic> raw;

  /// `data.current_law` — null when no topic was identified.
  Map<String, dynamic>? get currentLaw {
    final v = raw['current_law'];
    return v is Map && v.isNotEmpty ? Map<String, dynamic>.from(v) : null;
  }

  List<Map<String, dynamic>> get directlyRelevant =>
      _maps(raw['directly_relevant']);
  List<Map<String, dynamic>> get relatedAuthorities =>
      _maps(raw['related_authorities']);
  List<Map<String, dynamic>> get principles => _maps(raw['principles']);
  List<Map<String, dynamic>> get statutorySections =>
      _maps(raw['statutory_sections']);
  List<Map<String, dynamic>> get sources => _maps(raw['sources']);

  /// `data.synthesis` — null when Groq did not answer (app.py:2042-2045).
  Map<String, dynamic>? get synthesis {
    final v = raw['synthesis'];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  String get noResultNotice => jsOrText(raw['no_result_notice'], '');
  String get aiNotice => jsText(raw['ai_notice']);

  /// Whether `renderResearchResult` would produce anything; when it would not
  /// the page prints "No results." (JD:1157).
  bool get isEmpty =>
      currentLaw == null &&
      directlyRelevant.isEmpty &&
      noResultNotice.isEmpty &&
      relatedAuthorities.isEmpty &&
      principles.isEmpty &&
      statutorySections.isEmpty &&
      synthesis == null &&
      sources.isEmpty;
}

/// A nested field of a research map, e.g. `cl.current.section`.
String nested(Map<String, dynamic> m, String a, String b) =>
    jsText(_map(m[a])[b]);

/// Fixed text and prompts of the website's Lawyer Portal, transcribed from
/// `website/templates/lawyer_dashboard.html` (LD) and `website/app.py`.
///
/// Kept verbatim, on the precedent of `citizen_content.dart`: the website is the
/// source of truth for this role, and nothing here may be reworded without
/// changing it there first.
abstract final class LawyerContent {
  const LawyerContent._();

  /// The select's options (LD:575-579) — the same four the server accepts
  /// (`VALID_CASE_STATUSES`, app.py:2428).
  static const caseStatuses = [
    'Investigation',
    'Court Proceedings',
    'Trial',
    'Closed',
  ];

  /// The deadline type select, in its order (LD:696-703). The first is the
  /// default a fresh select shows.
  static const deadlineTypes = [
    'Chargesheet Filing',
    'Bail Application',
    'Appeal Limitation',
    'Revision Petition',
    'Discharge Application',
    'Custom',
  ];

  /// The Legal Assistant's four chips: (label, question) (LD:477-492).
  static const assistantSuggestions = [
    ('How to file a Vakalatnama', 'How do I file a Vakalatnama?'),
    (
      'When to raise an objection',
      'When should I raise an objection during cross-examination?',
    ),
    (
      'Bail application format',
      'What is the format and procedure for a bail application?',
    ),
    ('Filing a caveat', 'What is a caveat and how do I file one?'),
  ];

  static const assistantIntro =
      'Ask about practice, procedure, and drafting — when to raise an '
      'objection, how to file a Vakalatnama, bail application format, and more.';

  static const assistantPlaceholder =
      'e.g. When should I raise an objection during cross-examination? How do '
      'I file a Vakalatnama?';

  static const heroSubtitle = 'Manage your cases, get practice guidance, and '
      'draft documents — all from one place.';

  static const clientNoteHelp = 'Write a note and send it — the client will '
      'see your latest message and case status on their portal.';

  static const clientNotePlaceholder =
      'e.g. Chargesheet has been filed, next hearing is on 15th September…';

  // ---- prompts ---------------------------------------------------------------
  //
  // Built from the FIR row exactly as the page's template literals build them,
  // including JavaScript's stringification of a missing value — see
  // [jsString].

  /// `cwGenerateSummary()` (LD:1218-1223), sent with `type: 'laws'`.
  static String summaryQuery(Map<String, dynamic> c) =>
      'Summarize this case for the assigned lawyer: FIR ${jsString(c, 'fir_no')}, '
      'sections: ${jsString(c, 'act_sections')}, '
      'accused: ${jsString(c, 'details_of_accused')}, '
      'narrative: ${jsSlice500(c['statement'])}. '
      'Give: key facts, applicable sections explained briefly, and immediate '
      'next steps for the defense/prosecution. '
      'Only cite specific case names/citations if you are confident they are '
      'real — otherwise describe the '
      'general legal principle without attributing it to a specific case. If '
      'key details (dates, complainant name, '
      "etc.) are missing from what I've given you, say so explicitly rather "
      'than inventing placeholder values.';

  /// `cwGenerateDraft('bail')` (LD:1259).
  static String bailPrompt(Map<String, dynamic> c) =>
      'Accused: ${jsString(c, 'details_of_accused')}\n'
      'Court: SESSIONS COURT\n'
      'FIR: ${jsString(c, 'fir_no')}\n'
      'Section Charged: ${jsString(c, 'act_sections')}\n'
      'Grounds: First-time offender, investigation complete';

  /// `cwGenerateDraft('document')` (LD:1260).
  static String documentPrompt(Map<String, dynamic> c) =>
      'Draft a legal document based on FIR ${jsString(c, 'fir_no')}. '
      'Sections: ${jsString(c, 'act_sections')}. '
      'Facts: ${jsSlice500(c['statement'])}';
}

/// `${c.key}` in a JavaScript template literal: a missing key prints
/// `undefined`, a null prints `null`, a boolean or number prints as itself.
String jsString(Map<String, dynamic> row, String key) {
  if (!row.containsKey(key)) return 'undefined';
  final value = row[key];
  if (value == null) return 'null';
  return value.toString();
}

/// `(c.statement || '').slice(0, 500)`. Dart and JavaScript both count UTF-16
/// code units, so the cut falls in the same place.
String jsSlice500(Object? value) {
  final text = jsTruthy(value) ? value.toString() : '';
  return text.length <= 500 ? text : text.substring(0, 500);
}

/// JavaScript truthiness of a decoded JSON value.
bool jsTruthy(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0 && !value.isNaN;
  if (value is String) return value.isNotEmpty;
  return true;
}

/// `value || fallback` for a value that is shown as text.
String jsOr(Object? value, String fallback) =>
    jsTruthy(value) ? value.toString() : fallback;

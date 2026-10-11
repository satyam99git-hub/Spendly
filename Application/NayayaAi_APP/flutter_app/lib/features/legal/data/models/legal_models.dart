import '../../domain/entities/legal_section.dart';
import '../../domain/entities/outcome_finding.dart';

/// `GET /api/sections/<act>` — the paginated envelope.
///
/// The act is on the envelope and not on the rows, so it is pushed down into
/// each [LegalSection] here. Every other reader of a section gets one that
/// knows which act it belongs to, and a row that did not would be unopenable:
/// `/api/section-detail/<act>/<no>` needs both halves.
class LegalSectionPageResponse {
  const LegalSectionPageResponse._();

  static LegalSectionPage fromJson(
    Map<String, dynamic> json, {
    required String fallbackAct,
  }) {
    // The server echoes the act it searched. Trusted over the caller's copy on
    // the theory that the answer describes itself, with the request's act
    // behind it for a handler that ever stops echoing.
    final act = _text(json, 'act').isEmpty ? fallbackAct : _text(json, 'act');
    final rows = json['results'];

    return LegalSectionPage(
      act: act,
      sections: rows is List
          ? rows
              .whereType<Map>()
              .map(
                (row) => LegalSectionResponse.fromJson(
                  row.cast<String, dynamic>(),
                  fallbackAct: act,
                ),
              )
              .toList()
          : const [],
      page: _int(json, 'page', 1),
      pages: _int(json, 'pages', 1),
      total: _int(json, 'total', 0),
    );
  }
}

/// One row, from any of the three endpoints that return one.
class LegalSectionResponse {
  const LegalSectionResponse._();

  static LegalSection fromJson(
    Map<String, dynamic> json, {
    required String fallbackAct,
  }) {
    final act = _text(json, 'act');
    return LegalSection(
      // Present on a cross-act search hit, absent on a row from one act's page
      // and on a section detail — both of which were asked for by act, so the
      // caller knows it.
      act: act.isEmpty ? fallbackAct : act,
      section: _text(json, 'section'),
      title: _text(json, 'title'),
      description: _text(json, 'description'),
    );
  }
}

/// One entry of `results` from `POST /api/predict-outcome`.
class OutcomeFindingResponse {
  const OutcomeFindingResponse._();

  static OutcomeFinding fromJson(Map<String, dynamic> json) {
    return OutcomeFinding(
      // The dataset defaults this to IPC server-side, but a row with the column
      // blank has been seen; naming the act is better than showing a bare
      // number that could be from any of eight.
      act: _text(json, 'act').isEmpty ? 'IPC' : _text(json, 'act'),
      section: _text(json, 'section'),
      title: _text(json, 'title'),
      description: _text(json, 'description'),
      punishment: _text(json, 'punishment'),
      bnsEquivalent: _text(json, 'bns_equivalent'),
      sentencingRange: _text(json, 'sentencing_range'),
      cognizable: _text(json, 'cognizable'),
      bailable: _text(json, 'bailable'),
      outcomeNote: _text(json, 'outcome_note'),
      score: _double(json, 'score'),
    );
  }
}

/// Reads one field as text, whatever it arrives as.
///
/// `section` is an INTEGER column and arrives as a number; `score` is a float;
/// everything else is TEXT that can be NULL. A cast would throw on the first of
/// those, which is the field every screen here is keyed on.
String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value == null ? '' : value.toString().trim();
}

int _int(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double _double(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

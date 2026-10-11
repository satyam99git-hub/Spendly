/// One act-and-section pair charged on an FIR, e.g. IPC Section 379.
///
/// FORM IF-1 has a single free-text "Act(s) and Section(s)" line and the server
/// stores exactly that — one string, comma-separated. Modelling the pairs
/// instead of the string is what lets the form offer the eight known act codes
/// as a picker rather than asking an officer to type `IPC Section 379, CRPC
/// Section 41` correctly on a phone keyboard, where a stray comma or a missing
/// "Section" produces a record nobody can search.
///
/// [wire] is the one place that decides the stored spelling. It matches the
/// website's own `${act} Section ${sec}` join, so FIRs filed from the app and
/// from a desk read identically in the database.
class ActSection {
  const ActSection({required this.act, required this.section});

  /// An act code from `GET /api/acts` — `IPC`, `CRPC`, `NIA`, `IEA`, `HMA`,
  /// `CPC`, `IDA`, `MVA`. Uppercase, as the server's section tables are named.
  final String act;

  /// The section number as written on the charge — `379`, `376(2)`, `66C`.
  /// Deliberately a String: section numbers carry sub-clauses and letters, and
  /// an int would silently drop them.
  final String section;

  /// How this pair is stored and printed.
  String get wire => '$act Section $section';

  /// Joins a list the way the server expects the `act_sections` column.
  static String wireList(List<ActSection> sections) =>
      sections.map((s) => s.wire).join(', ');

  Map<String, dynamic> toJson() => {'act': act, 'section': section};

  factory ActSection.fromJson(Map<String, dynamic> json) => ActSection(
        act: (json['act'] as String?)?.trim() ?? '',
        section: (json['section'] as String?)?.trim() ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActSection && other.act == act && other.section == section;

  @override
  int get hashCode => Object.hash(act, section);

  @override
  String toString() => wire;
}

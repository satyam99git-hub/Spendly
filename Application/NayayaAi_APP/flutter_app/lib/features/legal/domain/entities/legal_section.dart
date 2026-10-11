/// One section of one act, as `IndiaLaw.db` holds it.
///
/// The same shape comes back from three endpoints with three different amounts
/// filled in, and the app has one class for all three rather than three:
///
///   - `GET /api/sections/<act>` — section, title, description; the act is on
///     the envelope rather than the row, and is filled in by the parser.
///   - `GET /api/section-detail/<act>/<no>` — the same three, one row.
///   - `GET /api/search-sections?q=` — act, section, title. **No description.**
///
/// A search hit is therefore a [LegalSection] with an empty [description], and
/// [isSummary] says so. Modelling it as a fourth class would mean the list that
/// shows search results and the list that shows an act's sections could not be
/// the same widget, which is the only thing either of them is for.
class LegalSection {
  const LegalSection({
    required this.act,
    required this.section,
    this.title = '',
    this.description = '',
  });

  /// `IPC`, `CRPC`, `NIA`, `IEA`, `HMA`, `CPC`, `IDA`, `MVA` — one of the eight
  /// `GET /api/acts` names, which are also the table names in `IndiaLaw.db`.
  final String act;

  /// The section number as text.
  ///
  /// **Text, though the column is an INTEGER.** It is a label, not a quantity:
  /// nothing adds two section numbers, sorting them numerically is the server's
  /// job, and keeping it a string means a table that one day holds `304A` needs
  /// no change here.
  final String section;

  final String title;

  /// The section's text. Empty on a cross-act search hit, which does not carry
  /// one — see [isSummary].
  final String description;

  /// `IPC 379`. How a section is written everywhere in this app that is not a
  /// full row, and the same spelling `ActSection.wire` produces for an FIR's
  /// `act_sections` column, so a section read here can be filed there.
  String get label => '$act $section';

  /// `IPC Section 379`. The longer form, for a heading.
  String get longLabel => '$act Section $section';

  /// True when this came from a search and carries no text of its own, so the
  /// viewer knows to fetch the full row before showing it as one.
  bool get isSummary => description.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegalSection &&
          other.act == act &&
          other.section == section &&
          other.title == title &&
          other.description == description;

  @override
  int get hashCode => Object.hash(act, section, title, description);

  @override
  String toString() => 'LegalSection($label)';
}

/// One page of an act's sections, with what the server said about the rest.
///
/// The page numbers matter more than they look: IPC alone is 575 sections over
/// 288 pages at the server's default of 20, so the library is a list that is
/// always partly loaded and the footer has to be able to say so.
class LegalSectionPage {
  const LegalSectionPage({
    required this.act,
    this.sections = const [],
    this.page = 1,
    this.pages = 1,
    this.total = 0,
  });

  final String act;
  final List<LegalSection> sections;

  /// 1-based, as the server counts.
  final int page;

  /// How many pages the current query has. Note this is a count of *pages*, not
  /// an index, so the last page is [pages].
  final int pages;

  /// Matching sections across every page.
  final int total;

  bool get hasMore => page < pages;
  bool get isEmpty => sections.isEmpty;

  @override
  String toString() => 'LegalSectionPage($act, $page/$pages, $total total)';
}

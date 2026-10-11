/// What kind of offence a complaint describes, and whether an FIR can be filed
/// on it.
///
/// ---------------------------------------------------------------------------
/// THE CITIZEN NEVER CHOSE THIS
///
/// `complaint_categorizer.py` derives it from the narrative by keyword match at
/// filing time, and stores it on the row. The complainant is not asked and does
/// not see a category list — which is the point: a citizen who has just been
/// robbed should not have to know whether that is "Theft / Robbery" or
/// "Financial Fraud / Cheating" before the station will read their complaint.
///
/// So the value is a *suggestion made by a keyword table*, and this app must
/// present it as one. It is triage, not a legal finding. See [isCognizable].
/// ---------------------------------------------------------------------------
///
/// The wire values are the exact strings the column holds, spacing and slashes
/// included. Do not tidy them; the website's console compares them literally
/// when it groups its board into columns.
enum ComplaintCategory {
  murder(
    'Murder / Homicide',
    'Murder / homicide',
    isCognizable: true,
  ),
  sexualOffence(
    'Sexual Offence',
    'Sexual offence',
    isCognizable: true,
  ),
  kidnapping(
    'Kidnapping / Missing Person',
    'Kidnapping / missing person',
    isCognizable: true,
  ),
  assault(
    'Assault / Violence',
    'Assault / violence',
    isCognizable: true,
  ),
  theft(
    'Theft / Robbery',
    'Theft / robbery',
    isCognizable: true,
  ),
  cybercrime(
    'Cybercrime / Fraud',
    'Cybercrime / fraud',
    isCognizable: true,
  ),
  financialFraud(
    'Financial Fraud / Cheating',
    'Financial fraud / cheating',
    isCognizable: true,
  ),

  /// The narrative matched a term on the categoriser's non-cognizable list —
  /// a tenancy row, a loan not repaid, a family property division.
  nonCognizable(
    'Other (Non-Cognizable)',
    'Non-cognizable',
    isCognizable: false,
  ),

  /// Nothing matched. The overwhelmingly common outcome for a narrative written
  /// in anything but the categoriser's vocabulary, which includes every
  /// complaint not written in English.
  needsReview(
    'Other / Needs Review',
    'Needs review',
    isCognizable: false,
  ),

  /// The categoriser was handed an empty description.
  unclassified(
    'Other / Unclassified',
    'Unclassified',
    isCognizable: false,
  );

  const ComplaintCategory(
    this.wireValue,
    this.label, {
    required this.isCognizable,
  });

  /// What the `category` column holds.
  final String wireValue;

  /// On screen. Sentence case, because it appears in running text as often as
  /// on a chip.
  final String label;

  /// Whether an FIR can normally be registered on an offence of this kind.
  ///
  /// Carried on the enum *and* read off the row — see `Complaint.isCognizable`,
  /// which prefers the server's own `is_cognizable` column. The two agree
  /// today because both come from the same table in
  /// `complaint_categorizer.py`; if the server's table changes, the row is
  /// right and this is stale, so the row wins.
  ///
  /// **Not a legal finding.** It is what a keyword matcher concluded from the
  /// words the complainant happened to use, and an officer overrules it by
  /// filing the FIR anyway. Nothing in this app may prevent that.
  final bool isCognizable;

  /// Whether this is one of the three "we could not tell" outcomes.
  ///
  /// The website's board collapses all three into a single "Other" column,
  /// because to an officer triaging they mean the same thing: read it yourself.
  bool get isUnclassified =>
      this == nonCognizable || this == needsReview || this == unclassified;

  /// Reads the column.
  ///
  /// Null for a value the app does not know, and for a row filed before the
  /// categoriser existed — the column is nullable in SQLite and older rows have
  /// no value at all. The entity keeps the raw text and shows that; see
  /// `Complaint.categoryLabel`. Falling back to [needsReview] would be a lie
  /// with the same shape as a real answer.
  static ComplaintCategory? fromWire(String? value) {
    final v = value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return null;

    for (final category in ComplaintCategory.values) {
      if (category.wireValue.toLowerCase() == v) return category;
    }
    return null;
  }
}

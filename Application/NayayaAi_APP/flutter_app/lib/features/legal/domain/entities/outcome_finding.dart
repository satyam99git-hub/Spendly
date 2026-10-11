/// One section the outcome search matched, with everything the dataset knows
/// about how a case under it tends to go.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS IS AND IS NOT
///
/// `POST /api/predict-outcome` is called a prediction and is not one. It is a
/// keyword search over `case.csv` — a table of sections with their punishments
/// and their cognizable/bailable flags — scored by how many of the situation's
/// words a row matches. There is no model, no case history, and no estimate of
/// what a court will do.
///
/// So every screen showing these has to say so. An officer who reads "3 years"
/// off a handset and repeats it to a complainant as what the accused will get
/// has been misled by the app, not by the dataset. See [score], which is the
/// honest measure of how much to trust the row: a match count, nothing more.
/// ---------------------------------------------------------------------------
class OutcomeFinding {
  const OutcomeFinding({
    required this.act,
    required this.section,
    this.title = '',
    this.description = '',
    this.punishment = '',
    this.bnsEquivalent = '',
    this.sentencingRange = '',
    this.cognizable = '',
    this.bailable = '',
    this.outcomeNote = '',
    this.score = 0,
  });

  final String act;
  final String section;
  final String title;
  final String description;

  /// `Imprisonment up to 3 years or fine or both`, as the dataset words it.
  final String punishment;

  /// The corresponding section of the Bharatiya Nyaya Sanhita, which replaced
  /// the IPC. Shown because a charge sheet written now cites the BNS while the
  /// station's own records and this dataset still speak IPC.
  final String bnsEquivalent;

  final String sentencingRange;

  /// `Yes` / `No` **as free text**, not as a boolean.
  ///
  /// The column is whatever `case.csv` has in it, and rows have been seen with
  /// an empty string and with a qualifier. [isCognizable] reads it, and returns
  /// null rather than guessing when it is neither.
  final String cognizable;

  /// Same, for bail.
  final String bailable;

  /// A sentence of practical advice from the dataset, e.g. "Police can arrest
  /// without warrant. File FIR at local police station immediately."
  final String outcomeNote;

  /// The search's own score for this row — how many of the situation's words it
  /// matched, weighted. Comparable within one result set and meaningless
  /// between two.
  final double score;

  String get label => '$act $section';
  String get longLabel => '$act Section $section';

  /// True, false, or null when the column says something that is neither.
  bool? get isCognizable => _yesNo(cognizable);
  bool? get isBailable => _yesNo(bailable);

  static bool? _yesNo(String value) {
    final v = value.trim().toLowerCase();
    if (v.startsWith('yes')) return true;
    if (v.startsWith('no')) return false;
    return null;
  }

  @override
  String toString() => 'OutcomeFinding($label, score $score)';
}

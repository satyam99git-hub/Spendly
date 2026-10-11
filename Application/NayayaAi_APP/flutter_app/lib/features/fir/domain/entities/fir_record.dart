import '../../../../core/utils/fir_number.dart';
import '../../../../core/utils/fir_pdf.dart';
import '../../../../core/utils/form_dates.dart';
import '../../../../core/utils/server_time.dart';

/// An FIR as police records hold it.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS A SEPARATE TYPE FROM [FirDraft]
///
/// The two are not the same document at different times. [FirDraft] is what this
/// app *collects* — twenty-five entries an officer types, six of them required —
/// and it carries the wizard's own concerns: what is still blank, what has been
/// autosaved, which step raised an error.
///
/// This is what the database *returns*, and the app is not the only thing that
/// writes to it. A record carries two entries the draft never holds (`year` and
/// `occurrence_day`, both derived at submission) plus `fir_id`, `pdf_url`,
/// `created_at` and `status`, which only the server can supply. A viewer that
/// reused the draft would open a stored record and silently drop part of
/// a statutory document. Reading a record is a different job from writing one:
/// showing less than was filed is a defect in a way that asking for less is not.
///
/// So every column the handler writes is here, empty string when absent, and the
/// viewer skips the blanks — an FIR from either client leaves plenty of them.
/// ---------------------------------------------------------------------------
///
/// Immutable, and every entry is a non-null [String] for the same reason as
/// [FirDraft]: the server stores every column as text and writes `""` for
/// anything absent, so a nullable field would mean two spellings of "not
/// answered" for one value.
class FirRecord {
  const FirRecord({
    required this.firNo,
    this.firId = '',
    this.district = '',
    this.policeStation = '',
    this.year = '',
    this.firDate = '',
    this.actSections = '',
    this.occurrenceDay = '',
    this.occurrenceDate = '',
    this.occurrenceTime = '',
    this.infoReceivedDate = '',
    this.infoReceivedTime = '',
    this.gdrEntryNo = '',
    this.typeOfInformation = '',
    this.placeOfOccurrence = '',
    this.complainantName = '',
    this.fatherHusbandName = '',
    this.dob = '',
    this.nationality = '',
    this.passportNo = '',
    this.dateOfIssue = '',
    this.placeOfIssue = '',
    this.occupation = '',
    this.address = '',
    this.detailsOfAccused = '',
    this.reasonsForDelay = '',
    this.propertyParticulars = '',
    this.statement = '',
    this.pdfFile = '',
    this.pdfUrl = '',
    this.createdAt = '',
    this.status = '',
  });

  // ---- identity -------------------------------------------------------------

  /// The station's FIR number, and the only handle anything else has on this
  /// record: evidence is filed against it, the PDF is named after it, and both
  /// read routes are keyed on it.
  final String firNo;

  /// The server's own identifier — a UTC timestamp with the dot stripped. Not
  /// shown; kept because it is the only thing that separates two records if an
  /// FIR number is ever reused across stations.
  final String firId;

  // ---- IF-1 entries 1-5 -----------------------------------------------------

  /// Wire key `dist`. Called "district" by the server; its list is actually
  /// states and union territories. See [FirDraft].
  final String district;

  /// Wire key `ps`.
  final String policeStation;

  final String year;
  final String firDate;

  /// One string, comma-separated, e.g. `IPC 379, IPC 411`. The server stores it
  /// that way and the app has never had a reason to store it any other way — see
  /// [sectionList] for reading it back apart.
  final String actSections;

  // ---- IF-1 entries 3-7: occurrence -----------------------------------------

  final String occurrenceDay;
  final String occurrenceDate;
  final String occurrenceTime;
  final String infoReceivedDate;
  final String infoReceivedTime;
  final String gdrEntryNo;
  final String typeOfInformation;
  final String placeOfOccurrence;

  // ---- IF-1 entry 7: the complainant ----------------------------------------

  final String complainantName;
  final String fatherHusbandName;
  final String dob;
  final String nationality;
  final String passportNo;
  final String dateOfIssue;
  final String placeOfIssue;
  final String occupation;
  final String address;

  // ---- IF-1 entries 8-12 ----------------------------------------------------

  final String detailsOfAccused;
  final String reasonsForDelay;
  final String propertyParticulars;

  /// The narrative. The one entry the whole record is built around.
  final String statement;

  // ---- server metadata ------------------------------------------------------

  /// Filename of the PDF the server generated at filing time, e.g.
  /// `FIR_FIR001.pdf`, as written by servers that still keep PDFs on their own
  /// disk. Empty for anything filed since storage moved to Supabase — see
  /// [pdfUrl], and read [pdfLabel] rather than either.
  final String pdfFile;

  /// Where the PDF lives now: the Supabase object URL stored as `pdf_url`.
  ///
  /// Never fetched directly. The download goes through
  /// `GET /fir/download/<fir_no>`, which redirects here — the same route the
  /// website's console uses, so where the bucket is stays the server's business.
  final String pdfUrl;

  /// Raw, in whichever of the server's two spellings the handler that answered
  /// happens to use. Parsed by [ServerTime], never by hand.
  final String createdAt;

  /// `Saved to Police Records` — the only value the handler writes. Kept because
  /// the column exists and the website's console shows it; the app does not
  /// branch on it, and must not start to without checking what else can write
  /// here first.
  final String status;

  // ---- derived --------------------------------------------------------------

  /// How this feature writes a number — see [FirNumber.label], which the
  /// evidence locker labels its FIR groups with too.
  ///
  /// Kept as a static here because the viewer needs it before the record has
  /// loaded: it has the number from its route and nothing else.
  static String label(String firNo) => FirNumber.label(firNo);

  /// This record's number, labelled. See [label].
  String get displayNumber => label(firNo);

  /// Whether the record claims a PDF, under either of the server's two columns.
  ///
  /// A claim, not a promise. Only `GET /fir/download/<fir_no>` can say whether
  /// the object is still there, which is why the download button is offered
  /// even when this is false.
  bool get hasPdf => pdfLabel.isNotEmpty;

  /// The PDF's filename, whichever column carried it. See [FirPdf.label].
  String get pdfLabel => FirPdf.label(pdfUrl: pdfUrl, pdfFile: pdfFile);

  /// When the record was created, as a UTC instant, or null when the column was
  /// empty or unparseable. Backs the newest-first ordering of the history list.
  DateTime? get filedAt => ServerTime.parse(createdAt);

  /// `9 Aug 2026` for a list row.
  String get filedOnDisplay => ServerTime.displayDay(createdAt);

  /// `9 Aug 2026, 02:31 UTC` for the viewer.
  String get filedAtDisplay => ServerTime.display(createdAt);

  /// The registration date as written on the form, e.g. `12 Aug 2026`. Distinct
  /// from [filedOnDisplay]: [firDate] is what the officer entered, [createdAt] is
  /// when the server stored it, and on a back-dated filing the two differ. Both
  /// are shown in the viewer for exactly that reason.
  String get firDateDisplay => FormDates.displayDate(firDate);

  /// The charged sections, split for display as chips.
  ///
  /// Split on commas only. The app writes `ActSection.wireList`, which joins with
  /// `, `, and the website's own form posts a comma-separated string too — but a
  /// record typed at a desk can hold anything, so an entry that does not split
  /// simply comes back as one chip rather than as an error.
  List<String> get sectionList => actSections
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// A one-line summary for the list row: who reported it and where.
  String get summaryLine {
    final parts = [
      if (complainantName.trim().isNotEmpty) complainantName.trim(),
      if (policeStation.trim().isNotEmpty) policeStation.trim(),
    ];
    return parts.isEmpty ? 'No complainant recorded' : parts.join(' · ');
  }

  // ---- search ---------------------------------------------------------------

  /// Whether this record answers [query], which the caller has already trimmed
  /// and lowercased.
  ///
  /// **The narrative is deliberately not searched.** A hit inside a five-hundred
  /// word statement puts a row on screen with nothing visible to explain why it
  /// is there, and "theft" matches half a station's records. The fields below are
  /// the ones an officer looking for a specific FIR actually has in hand: the
  /// number they were given, the name they were told, the station, or the
  /// section they are pulling records under.
  bool matches(String lowercaseQuery) {
    if (lowercaseQuery.isEmpty) return true;
    for (final field in [
      firNo,
      complainantName,
      district,
      policeStation,
      actSections,
      placeOfOccurrence,
    ]) {
      if (field.toLowerCase().contains(lowercaseQuery)) return true;
    }
    return false;
  }

  @override
  String toString() => 'FirRecord($firNo)';
}

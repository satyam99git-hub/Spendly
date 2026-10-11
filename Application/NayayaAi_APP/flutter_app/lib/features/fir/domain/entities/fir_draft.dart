import '../../../../core/utils/form_dates.dart';
import 'act_section.dart';

/// An FIR being written: FORM IF-1 in full.
///
/// ---------------------------------------------------------------------------
/// TWENTY-SEVEN ENTRIES, FOUR STEPS, ONE REVIEW
///
/// This is the statutory form as printed, and the app collects all of it. An FIR
/// is read in court; a record that silently left eighteen columns blank because
/// a phone form found them inconvenient is a record whose gaps have to be
/// explained later by whoever filed it.
///
/// Twenty-five entries are typed. Two are derived and never asked for, because
/// they cannot be allowed to disagree with the entries they come from:
///
///   - [year] follows [firDate] — a separately typed year diverges the first
///     time a December filing is registered in January;
///   - [occurrenceDay] follows [occurrenceDate] — IF-1 asks for the day and the
///     date separately, and a mismatch between them in a filed FIR is exactly
///     the kind of defect raised in court.
///
/// The four steps group them the way the paper form does, and [FirFormStep] is
/// where that grouping lives. Only seven entries are required; the rest are
/// genuinely optional, because an FIR must not become unfileable at a counter
/// over a passport number nobody has. See [missing].
/// ---------------------------------------------------------------------------
///
/// Immutable, and every text entry is a non-null [String] that is empty when
/// unanswered. There is no `String?` here on purpose: the server stores every
/// column as text and writes `""` for anything absent, so a nullable field would
/// mean carrying two spellings of "not answered" through the form, the autosave
/// and the submission for no gain.
class FirDraft {
  const FirDraft({
    this.firNo = '',
    this.district = '',
    this.policeStation = '',
    this.firDate = '',
    this.sections = const [],
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
  });

  // ---- step 1: registration (IF-1 entries 1-3) ------------------------------

  /// The station's own FIR number. The server rejects a duplicate with HTTP 400
  /// and uses this value as the generated PDF's filename, so it is required here
  /// even though the handler would accept an empty one.
  final String firNo;

  /// Called "district" by the server; its list is actually states and union
  /// territories. The app keeps the server's name for the wire key and says
  /// "District / State" on screen, rather than pretending either is wrong.
  final String district;
  final String policeStation;

  /// `yyyy-MM-dd`. The date the FIR is registered, which is not necessarily the
  /// date of occurrence.
  final String firDate;

  /// Charged sections. Required by the app even though the server treats an
  /// empty value as a request to infer them — see `FirSubmission.toJson`.
  final List<ActSection> sections;

  // ---- step 2: occurrence (IF-1 entries 4-7) --------------------------------

  /// `yyyy-MM-dd`, optional. An offence reported days later, or discovered after
  /// the fact, often has no agreed date at the counter, and a form that demands
  /// one invites a guess to be recorded as fact in a statutory document.
  final String occurrenceDate;

  /// `HH:mm`, 24-hour.
  final String occurrenceTime;

  /// When the station was told, which is distinct from when it happened and from
  /// when the FIR was written. The gap between the three is what
  /// [reasonsForDelay] exists to explain.
  final String infoReceivedDate;
  final String infoReceivedTime;

  /// The general diary entry this FIR was raised against, with its time.
  final String gdrEntryNo;

  /// Entry 5 on the paper form: written / oral / telephonic and so on. Free text
  /// rather than a picker — the printed form has no fixed list and stations use
  /// their own wording.
  final String typeOfInformation;

  /// Optional, free text. One box rather than IF-1's three parts (direction and
  /// distance, address, station it falls under): on a phone those are three
  /// near-identical boxes that officers fill by putting the whole address in the
  /// second one anyway.
  final String placeOfOccurrence;

  // ---- step 3: the complainant (IF-1 entry 7) -------------------------------

  final String complainantName;
  final String fatherHusbandName;

  /// `yyyy-MM-dd`.
  final String dob;

  final String nationality;

  /// The passport block — entry 7(f) on the form, and blank on almost every real
  /// FIR. Kept because it is the part of IF-1 that matters when the complainant
  /// is a foreign national, which is precisely when nobody wants to discover the
  /// app cannot record it.
  final String passportNo;
  final String dateOfIssue;
  final String placeOfIssue;

  final String occupation;
  final String address;

  // ---- step 4: the complaint (IF-1 entries 8-12) ----------------------------

  final String detailsOfAccused;

  /// Why the report was not made sooner. Read closely in court when the gap
  /// between occurrence and registration is long.
  final String reasonsForDelay;

  /// Property stolen or involved, with values.
  final String propertyParticulars;

  /// The narrative. The one entry the whole record is built around.
  final String statement;

  // ---- derived --------------------------------------------------------------

  /// Entry 2 on the form. Derived from [firDate] rather than asked. See the
  /// class doc.
  String get year {
    final filed = FormDates.parseWireDate(firDate);
    return filed == null ? '' : filed.year.toString();
  }

  /// Entry 4 on the form, computed from [occurrenceDate]. See the class doc.
  String get occurrenceDay => FormDates.weekdayName(occurrenceDate);

  /// The `act_sections` column's value.
  String get actSectionsWire => ActSection.wireList(sections);

  /// True when nothing has been entered — a fresh draft, or one whose fields
  /// were all cleared. What "discard" and "restore a saved draft" test against.
  bool get isEmpty =>
      sections.isEmpty && _texts.every((value) => value.trim().isEmpty);

  /// True when a person has put something in this draft.
  ///
  /// Distinct from ![isEmpty], and the difference is [firDate]: a brand-new
  /// draft is seeded with today's date, so it is never *empty* even before the
  /// officer has typed a character. What a caller about to replace the draft
  /// needs to know is whether replacing it would destroy work — which is this,
  /// not that. Used by the complaints inbox before it seeds the form from a
  /// complaint; see `ComplaintFirLinkController.start`.
  /// [firDate] is [_texts]' first element and is skipped by position, not by
  /// value — `identical` on two empty strings is true in Dart, so filtering by
  /// value would drop every blank entry along with it.
  bool get hasEnteredSomething =>
      sections.isNotEmpty ||
      _texts.skip(1).any((value) => value.trim().isNotEmpty);

  // ---- completeness ---------------------------------------------------------

  /// The required entries that are still blank, by their on-screen label.
  ///
  /// Seven of the twenty-five, and every one of them is required by the *app*
  /// rather than by the server — `/generate_fir` accepts a payload of empty
  /// strings and files it. The app refuses to send one because an FIR missing
  /// its complainant or its narrative is not a lighter record, it is an unusable
  /// one, and the officer is the only person in a position to notice before it
  /// is stored.
  ///
  /// The other eighteen are optional on purpose. An informant who walks in at
  /// midnight unsure which day the theft happened, with no passport and no idea
  /// who the accused is, is still entitled to have the complaint registered: an
  /// offence does not stop being cognisable because a column is blank. A wizard
  /// that demanded all 27 would be a wizard officers learn to fill with
  /// placeholder text.
  List<String> get missing => [
        for (final step in FirFormStep.entrySteps) ...missingIn(step),
      ];

  /// The required entries still blank on one step. What the wizard checks before
  /// letting Next through, so a problem is raised on the page that can fix it
  /// rather than four pages later.
  List<String> missingIn(FirFormStep step) {
    switch (step) {
      case FirFormStep.registration:
        return [
          if (firNo.trim().isEmpty) 'FIR number',
          if (district.trim().isEmpty) 'District / State',
          if (policeStation.trim().isEmpty) 'Police station',
          if (firDate.trim().isEmpty) 'FIR date',
          // Acts and sections are NOT required, and that is the server's rule
          // rather than a relaxation of it. `/generate_fir` reads an empty
          // `act_sections` as "you decide", runs the narrative through
          // `analyze_complaint_for_sections` and files the record under what it
          // suggests — which is how the website's console has always worked,
          // its own field being optional with the same note under it.
          //
          // Requiring them here made the app the stricter of two clients onto
          // one collection: an officer who could file at the desk could not
          // file the same complaint on the handset until they had looked the
          // sections up themselves. What the server fills in comes back on the
          // receipt, so nothing is filed unseen.
        ];
      case FirFormStep.occurrence:
        // Nothing on this step is required. Every entry here is one an officer
        // may genuinely not have while the complainant is still standing there.
        return const [];
      case FirFormStep.complainant:
        return [
          if (complainantName.trim().isEmpty) 'Complainant name',
        ];
      case FirFormStep.complaint:
        return [
          if (statement.trim().isEmpty) 'What happened',
        ];
      case FirFormStep.review:
        return const [];
    }
  }

  /// Ready to submit.
  bool get isSubmittable => missing.isEmpty;

  // ---- autosave -------------------------------------------------------------

  /// Local persistence shape.
  ///
  /// The *server's* shape lives in `data/models/fir_models.dart`, with the rest
  /// of the wire mapping. This one stays on the entity because it is not a
  /// mapping at all — it is the draft round-tripping itself through storage, and
  /// the two are deliberately different: the submission uses the server's own
  /// column names (`dist`, `ps`, `gdr_entry_no`) and derives two entries this
  /// form never stores.
  Map<String, dynamic> toJson() => {
        'fir_no': firNo,
        'district': district,
        'police_station': policeStation,
        'fir_date': firDate,
        'sections': sections.map((s) => s.toJson()).toList(),
        'occurrence_date': occurrenceDate,
        'occurrence_time': occurrenceTime,
        'info_received_date': infoReceivedDate,
        'info_received_time': infoReceivedTime,
        'gdr_entry_no': gdrEntryNo,
        'type_of_information': typeOfInformation,
        'place_of_occurrence': placeOfOccurrence,
        'complainant_name': complainantName,
        'father_husband_name': fatherHusbandName,
        'dob': dob,
        'nationality': nationality,
        'passport_no': passportNo,
        'date_of_issue': dateOfIssue,
        'place_of_issue': placeOfIssue,
        'occupation': occupation,
        'address': address,
        'details_of_accused': detailsOfAccused,
        'reasons_for_delay': reasonsForDelay,
        'property_particulars': propertyParticulars,
        'statement': statement,
      };

  /// Rebuilds a draft from [toJson]. Every field falls back to empty, so a
  /// payload written by an older build — one key short, or one this format has
  /// since added — restores what it can instead of throwing and taking the whole
  /// draft with it.
  factory FirDraft.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] as String?) ?? '';

    final rawSections = json['sections'];
    return FirDraft(
      firNo: text('fir_no'),
      district: text('district'),
      policeStation: text('police_station'),
      firDate: text('fir_date'),
      sections: rawSections is List
          ? rawSections
              .whereType<Map>()
              .map((e) => ActSection.fromJson(Map<String, dynamic>.from(e)))
              .where((s) => s.act.isNotEmpty && s.section.isNotEmpty)
              .toList()
          : const [],
      occurrenceDate: text('occurrence_date'),
      occurrenceTime: text('occurrence_time'),
      infoReceivedDate: text('info_received_date'),
      infoReceivedTime: text('info_received_time'),
      gdrEntryNo: text('gdr_entry_no'),
      typeOfInformation: text('type_of_information'),
      // `place_address` is what an older build's autosave called this. Read as a
      // fallback so a draft written before this format still opens with its
      // address intact rather than silently losing it.
      placeOfOccurrence: text('place_of_occurrence').isNotEmpty
          ? text('place_of_occurrence')
          : text('place_address'),
      complainantName: text('complainant_name'),
      fatherHusbandName: text('father_husband_name'),
      dob: text('dob'),
      nationality: text('nationality'),
      passportNo: text('passport_no'),
      dateOfIssue: text('date_of_issue'),
      placeOfIssue: text('place_of_issue'),
      occupation: text('occupation'),
      address: text('address'),
      detailsOfAccused: text('details_of_accused'),
      reasonsForDelay: text('reasons_for_delay'),
      propertyParticulars: text('property_particulars'),
      statement: text('statement'),
    );
  }

  // ---- copy -----------------------------------------------------------------

  /// Null means "leave as it was". Clearing a field is `copyWith(x: '')` — an
  /// empty string is a real value here, not an absence.
  FirDraft copyWith({
    String? firNo,
    String? district,
    String? policeStation,
    String? firDate,
    List<ActSection>? sections,
    String? occurrenceDate,
    String? occurrenceTime,
    String? infoReceivedDate,
    String? infoReceivedTime,
    String? gdrEntryNo,
    String? typeOfInformation,
    String? placeOfOccurrence,
    String? complainantName,
    String? fatherHusbandName,
    String? dob,
    String? nationality,
    String? passportNo,
    String? dateOfIssue,
    String? placeOfIssue,
    String? occupation,
    String? address,
    String? detailsOfAccused,
    String? reasonsForDelay,
    String? propertyParticulars,
    String? statement,
  }) {
    return FirDraft(
      firNo: firNo ?? this.firNo,
      district: district ?? this.district,
      policeStation: policeStation ?? this.policeStation,
      firDate: firDate ?? this.firDate,
      sections: sections ?? this.sections,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      occurrenceTime: occurrenceTime ?? this.occurrenceTime,
      infoReceivedDate: infoReceivedDate ?? this.infoReceivedDate,
      infoReceivedTime: infoReceivedTime ?? this.infoReceivedTime,
      gdrEntryNo: gdrEntryNo ?? this.gdrEntryNo,
      typeOfInformation: typeOfInformation ?? this.typeOfInformation,
      placeOfOccurrence: placeOfOccurrence ?? this.placeOfOccurrence,
      complainantName: complainantName ?? this.complainantName,
      fatherHusbandName: fatherHusbandName ?? this.fatherHusbandName,
      dob: dob ?? this.dob,
      nationality: nationality ?? this.nationality,
      passportNo: passportNo ?? this.passportNo,
      dateOfIssue: dateOfIssue ?? this.dateOfIssue,
      placeOfIssue: placeOfIssue ?? this.placeOfIssue,
      occupation: occupation ?? this.occupation,
      address: address ?? this.address,
      detailsOfAccused: detailsOfAccused ?? this.detailsOfAccused,
      reasonsForDelay: reasonsForDelay ?? this.reasonsForDelay,
      propertyParticulars: propertyParticulars ?? this.propertyParticulars,
      statement: statement ?? this.statement,
    );
  }

  /// Every text entry, in no particular order. Backs [isEmpty],
  /// [hasEnteredSomething] and equality so none of them has to be updated by
  /// hand when a field is added.
  ///
  /// [firDate] is first and is compared by identity in [hasEnteredSomething], so
  /// its position here is load-bearing — do not sort this list.
  List<String> get _texts => [
        firDate,
        firNo, district, policeStation, //
        occurrenceDate, occurrenceTime,
        infoReceivedDate, infoReceivedTime,
        gdrEntryNo, typeOfInformation, placeOfOccurrence,
        complainantName, fatherHusbandName, dob, nationality,
        passportNo, dateOfIssue, placeOfIssue, occupation, address,
        detailsOfAccused, reasonsForDelay, propertyParticulars, statement,
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FirDraft) return false;

    final mine = _texts;
    final theirs = other._texts;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != theirs[i]) return false;
    }

    if (sections.length != other.sections.length) return false;
    for (var i = 0; i < sections.length; i++) {
      if (sections[i] != other.sections[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(_texts), Object.hashAll(sections));

  @override
  String toString() => 'FirDraft(${firNo.isEmpty ? 'unnumbered' : firNo})';
}

/// Where the officer is in the form.
///
/// The four entry steps follow the printed form's own grouping, so an officer
/// who knows IF-1 finds each entry where they expect it. [review] is not a step
/// of the form — it is the last look before a statutory record is created, and
/// it is the only place [FirFormStep.review] can be submitted from.
enum FirFormStep {
  registration('Registration', 'Entries 1–3'),
  occurrence('Occurrence', 'Entries 4–7'),
  complainant('Complainant', 'Entry 7'),
  complaint('The complaint', 'Entries 8–12'),
  review('Review', 'Check before filing');

  const FirFormStep(this.title, this.subtitle);

  /// On the step header.
  final String title;

  /// Which entries of the paper form this step covers, so an officer working
  /// from IF-1 can follow along.
  final String subtitle;

  /// The four that collect entries. [review] is excluded — it has no fields of
  /// its own, so anything iterating "the steps that can be incomplete" wants
  /// this rather than [values].
  static const entrySteps = [registration, occurrence, complainant, complaint];

  /// 1-based, for "Step 2 of 4". [review] answers 0 — it is not one of the four
  /// and must not be counted as one.
  int get number => isReview ? 0 : index + 1;

  bool get isReview => this == FirFormStep.review;
  bool get isFirst => this == FirFormStep.registration;

  FirFormStep? get next =>
      index + 1 < values.length ? values[index + 1] : null;

  FirFormStep? get previous => index > 0 ? values[index - 1] : null;
}

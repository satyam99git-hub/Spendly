/// The two reference lookups the website's console keeps in its sidebar.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS A CONSTANT AND NOT AN ENDPOINT
///
/// Both are hardcoded JavaScript objects in `templates/index.html` —
/// `LEGAL_GLOSSARY` and `LAW_AMENDMENTS`. There is no route that serves them and
/// no table behind them, so a client that wanted them had to carry its own copy.
/// This is that copy, transcribed verbatim.
///
/// Which means it can drift. If the website's tables are edited, these do not
/// follow, and nothing will fail — the app will simply be one revision behind on
/// a definition. The fix is an endpoint; until there is one, the honest thing is
/// to say so here rather than to imply these came from the server.
/// ---------------------------------------------------------------------------
library;

/// One term and what it means.
class LegalTerm {
  const LegalTerm(this.term, this.definition);

  final String term;
  final String definition;

  /// Whether this answers [lowercaseQuery], already trimmed and lowered.
  ///
  /// The term and the definition are both searched. The website matches only
  /// the term, which means an officer who knows the idea but not the word --
  /// "arrest without warrant" -- finds nothing. Searching the definition too
  /// costs nothing over 23 rows and answers the question they actually asked.
  bool matches(String lowercaseQuery) =>
      lowercaseQuery.isEmpty ||
      term.toLowerCase().contains(lowercaseQuery) ||
      definition.toLowerCase().contains(lowercaseQuery);
}

/// One section of the old codes and what replaced it.
///
/// The IPC, CrPC and Evidence Act were replaced in 2023 by the Bharatiya Nyaya
/// Sanhita, the Nagarik Suraksha Sanhita and the Sakshya Adhiniyam. Station
/// records, the FIR form and `IndiaLaw.db` all still speak the old numbers; a
/// charge sheet written now cites the new ones. This is the bridge, and it is
/// the reason the lookup is on the police console at all.
class LawAmendment {
  const LawAmendment(this.oldSection, this.newSection, this.note);

  /// As the website keys it: lower case, `ipc 302`, `crpc 154`.
  final String oldSection;

  /// `BNS Section 103`.
  final String newSection;

  /// What the section is about, in a word or two.
  final String note;

  /// `IPC 302`. The stored key is lower-cased for matching; this is for reading.
  String get oldLabel {
    final parts = oldSection.split(' ');
    if (parts.isEmpty) return oldSection;
    return '${parts.first.toUpperCase()} ${parts.skip(1).join(' ').toUpperCase()}'
        .trim();
  }

  /// Whether this answers [lowercaseQuery], already trimmed and lowered.
  ///
  /// The number alone is enough: an officer types "302", not "ipc 302". The new
  /// section and the note are searched too, so "murder" and "BNS 103" both find
  /// it from the other direction.
  bool matches(String lowercaseQuery) {
    if (lowercaseQuery.isEmpty) return true;
    final needle = lowercaseQuery.replaceAll(RegExp(r'\s+'), ' ');
    return oldSection.contains(needle) ||
        newSection.toLowerCase().contains(needle) ||
        note.toLowerCase().contains(needle);
  }
}

/// Transcribed from `LEGAL_GLOSSARY`.
const legalGlossary = <LegalTerm>[
  LegalTerm(
    'bail',
    'Temporary release of an accused person awaiting trial, usually on condition of a surety or bond.',
  ),
  LegalTerm(
    'cognizable',
    'An offence for which police can arrest without a warrant and start investigation without court permission.',
  ),
  LegalTerm(
    'non-cognizable',
    'An offence for which police cannot arrest without a warrant or investigate without court permission.',
  ),
  LegalTerm(
    'mens rea',
    'The mental element of a crime — the intention or knowledge of wrongdoing.',
  ),
  LegalTerm(
    'actus reus',
    'The physical act of committing a crime, as opposed to the mental intent.',
  ),
  LegalTerm(
    'fir',
    'First Information Report — the document police prepare when they first receive information about a cognizable offence.',
  ),
  LegalTerm(
    'chargesheet',
    'The final report filed by police after investigation, listing the accused and evidence against them.',
  ),
  LegalTerm(
    'anticipatory bail',
    'Bail sought in advance of arrest, when a person believes they may be arrested for a non-bailable offence.',
  ),
  LegalTerm(
    'vakalatnama',
    'A document authorizing an advocate to represent a party in court.',
  ),
  LegalTerm(
    'caveat',
    'A notice filed in court requesting to be heard before any order is passed against the filer.',
  ),
  LegalTerm(
    'acquittal',
    'A judgment that the accused is not guilty of the offence charged.',
  ),
  LegalTerm(
    'remand',
    'A court order sending an accused person into police or judicial custody during investigation.',
  ),
  LegalTerm('plaintiff', 'The party who initiates a civil lawsuit.'),
  LegalTerm(
    'defendant',
    'The party being sued or accused in a civil or criminal case.',
  ),
  LegalTerm(
    'affidavit',
    'A written statement confirmed by oath, used as evidence in court.',
  ),
  LegalTerm(
    'injunction',
    'A court order requiring a party to do or stop doing a specific act.',
  ),
  LegalTerm(
    'decree',
    'The formal expression of a court\'s final decision in a civil suit.',
  ),
  LegalTerm(
    'summons',
    'A legal document ordering a person to appear in court.',
  ),
  LegalTerm(
    'warrant',
    'A legal document authorizing police to arrest a person or search a place.',
  ),
  LegalTerm(
    'bailable offence',
    'An offence where bail is a matter of right and police/court must grant it if requested.',
  ),
  LegalTerm(
    'non-bailable offence',
    'A serious offence where bail is at the discretion of the court, not a right.',
  ),
  LegalTerm(
    'compoundable offence',
    'An offence where the complainant can withdraw the case by settling with the accused.',
  ),
  LegalTerm(
    'non-compoundable offence',
    'A serious offence that cannot be withdrawn by mutual settlement.',
  ),
];

/// Transcribed from `LAW_AMENDMENTS`.
const lawAmendments = <LawAmendment>[
  LawAmendment('ipc 302', 'BNS Section 103', 'Murder'),
  LawAmendment('ipc 375', 'BNS Section 63', 'Rape'),
  LawAmendment('ipc 376', 'BNS Section 64', 'Punishment for rape'),
  LawAmendment('ipc 420', 'BNS Section 318', 'Cheating'),
  LawAmendment('ipc 406', 'BNS Section 316', 'Criminal breach of trust'),
  LawAmendment('ipc 34', 'BNS Section 3(5)', 'Common intention'),
  LawAmendment('ipc 120b', 'BNS Section 61', 'Criminal conspiracy'),
  LawAmendment('crpc 154', 'BNSS Section 173', 'FIR registration'),
  LawAmendment('crpc 41', 'BNSS Section 35', 'Arrest without warrant'),
  LawAmendment('crpc 437', 'BNSS Section 480', 'Bail in non-bailable offences'),
  LawAmendment('crpc 438', 'BNSS Section 482', 'Anticipatory bail'),
  LawAmendment(
    'crpc 161',
    'BNSS Section 180',
    'Police examination of witnesses',
  ),
  LawAmendment(
    'crpc 164',
    'BNSS Section 183',
    'Recording of confessions/statements',
  ),
];

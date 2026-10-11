/// Route paths and names, in one place so no screen hard-codes a string.
///
/// These are the *app's* routes and owe nothing to the website's URLs. The
/// server's login response carries its own `redirect` ("/citizen-dashboard"),
/// which is a page on the Flask site; the app ignores it and derives its landing
/// screen from the role instead.
abstract final class AppRoutes {
  const AppRoutes._();

  /// Cold-start screen. Holds the brand mark while the session resolves.
  static const splash = '/';
  static const splashName = 'splash';

  static const login = '/login';
  static const loginName = 'login';

  static const signup = '/signup';
  static const signupName = 'signup';

  /// Role-aware landing. One path for all roles — the screen itself branches on
  /// the signed-in role, so a role change does not orphan a deep link.
  static const home = '/home';
  static const homeName = 'home';

  // ---- police-only surfaces -------------------------------------------------

  /// Every prefix the police guard covers, so the router's check is one loop
  /// rather than a list of conditions a new route can be forgotten from. Adding
  /// a police feature means adding its prefix here and nothing else.
  static const policePrefixes = [
    firPrefix,
    evidencePrefix,
    complaintsPrefix,
    lawPrefix,
    missingPersonsPrefix,
  ];

  static const firPrefix = '/fir';

  /// FORM IF-1: 27 entries across four steps and a review page. See
  /// `FirFormStep` for the grouping and
  /// `docs/features/02-fir-registration.md` for why it is a wizard.
  static const firNew = '$firPrefix/new';
  static const firNewName = 'firNew';

  /// Shown once the server has the record. Unreachable without one — the router
  /// redirects here to [home] when no FIR has just been filed, because the
  /// screen's entire content is a receipt it would not have.
  static const firSuccess = '$firPrefix/success';
  static const firSuccessName = 'firSuccess';

  /// Everything the station has on record, newest first.
  ///
  /// A pushed route rather than a third tab. Filing an FIR and filing evidence
  /// are things an officer switches between several times an hour, which is what
  /// makes them tabs; reading past records is something they go and do, come
  /// back from, and do not want the console rearranged for.
  static const firHistory = '$firPrefix/history';
  static const firHistoryName = 'firHistory';

  /// One record, addressed by the only identity the server gives it. A path
  /// parameter rather than an argument, so the viewer can rebuild itself from
  /// the URL after a process death — the same reason the evidence detail screen
  /// is addressed the way it is.
  static const firRecord = '$firPrefix/record/:firNo';
  static const firRecordName = 'firRecord';

  static const evidencePrefix = '/evidence';

  /// Filing one file against one FIR.
  ///
  /// The locker's list and its PIN gate have no routes: they are the Evidence
  /// tab's two states, inside `/home`. A pushed PIN route could be popped or
  /// deep-linked around; a state cannot.
  static const evidenceAdd = '$evidencePrefix/add';
  static const evidenceAddName = 'evidenceAdd';

  /// One file, addressed by the only identity the server gives it — its FIR
  /// number and its filename. Both are path parameters so the screen can rebuild
  /// itself from the URL after a process death, which taking a photo makes
  /// likely.
  static const evidenceDetail = '$evidencePrefix/item/:firNo/:filename';
  static const evidenceDetailName = 'evidenceDetail';

  static const complaintsPrefix = '/complaints';

  /// One citizen complaint, addressed by its tracking ID — the only identity the
  /// server gives it, and the one the citizen was handed.
  ///
  /// The inbox itself has no route: it is the Complaints tab's content, inside
  /// `/home`, the same arrangement the evidence locker's list has. A tab is where
  /// an officer switches to; a complaint is somewhere they go, act, and come back
  /// from — which is what makes this a pushed route and that one not.
  static const complaintDetail = '$complaintsPrefix/:trackingId';
  static const complaintDetailName = 'complaintDetail';

  // ---- the law library and the two legal-AI surfaces ------------------------

  static const lawPrefix = '/law';

  /// Every section of all eight acts. The act picker and both searches live on
  /// this one screen — see `LawLibraryScreen` for why there are two searches.
  static const lawLibrary = lawPrefix;
  static const lawLibraryName = 'lawLibrary';

  /// One section, addressed by the pair the server needs to look it up.
  ///
  /// Two path parameters rather than arguments, for the same reason the
  /// evidence detail screen has two: the screen can rebuild itself from the URL
  /// after a process death, and a section is a thing an officer is sent a link
  /// to as often as they navigate to it.
  static const lawSection = '$lawPrefix/section/:act/:section';
  static const lawSectionName = 'lawSection';

  /// A legal question in plain words, answered from the section tables.
  static const lawAsk = '$lawPrefix/ask';
  static const lawAskName = 'lawAsk';

  /// A described situation, matched against the sentencing dataset. Not a
  /// prediction, whatever the endpoint is called — see `OutcomeFinding`.
  static const lawOutcome = '$lawPrefix/outcome';
  static const lawOutcomeName = 'lawOutcome';

  /// What a term means, and what the 2023 codes renumbered a section to. The
  /// one law surface with no server behind it — see `legal_reference.dart`.
  static const lawReference = '$lawPrefix/reference';
  static const lawReferenceName = 'lawReference';

  // ---- missing persons ------------------------------------------------------

  static const missingPersonsPrefix = '/missing-persons';

  /// Active cases, newest first, with the confirmed face matches above them.
  static const missingPersons = missingPersonsPrefix;
  static const missingPersonsName = 'missingPersons';

  /// Registering one. Police only, and the server enforces that — unlike the
  /// FIR and evidence routes, `/upload_missing_person` really does check the
  /// session.
  static const missingPersonNew = '$missingPersonsPrefix/new';
  static const missingPersonNewName = 'missingPersonNew';

  /// One case and its sightings, addressed by the ID the server minted.
  static const missingPerson = '$missingPersonsPrefix/:personId';
  static const missingPersonName = 'missingPerson';

  // ---- citizen-only surfaces ------------------------------------------------
  //
  // The Citizen Portal itself has no route of its own: like the website's
  // single `/citizen-dashboard` page, it is `/home` for a citizen, and its seven
  // sections switch in place (see `CitizenShell`). Only what is pushed on top
  // of it lives under this prefix.

  /// Every prefix the citizen guard covers — the mirror of [policePrefixes].
  static const citizenPrefixes = [citizenPrefix];

  static const citizenPrefix = '/citizen';

  /// One missing person, as a citizen sees them. Separate from
  /// [missingPerson], which is police-only and shows sightings a citizen may
  /// not see.
  static const citizenMissingPerson =
      '$citizenPrefix/missing-persons/:personId';
  static const citizenMissingPersonName = 'citizenMissingPerson';
}

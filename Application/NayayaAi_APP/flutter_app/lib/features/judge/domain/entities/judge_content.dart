/// The Judge Portal's fixed words and option lists, copied from
/// `templates/judge_dashboard.html` (JD) with the line each comes from, so a
/// change on the website can be found and mirrored here.
abstract final class JudgeContent {
  const JudgeContent._();

  // ---- shell (JD:56-96) ------------------------------------------------------

  static const portalLabel = 'Judge Portal';

  /// `session.get('name', 'Judge')` (JD:94, 110). Sign-in stores the account
  /// name under `session['fullname']` (app.py:2883) and nothing ever sets
  /// `session['name']`, so every judge sees the default. Reproduced as is
  /// (analysis OQ-J2).
  static const displayName = 'Judge';

  /// `session.get('name', 'J')[0]` (JD:92).
  static const avatarInitial = 'J';

  // ---- Home (JD:102-192) -----------------------------------------------------

  static const heroBadge = 'Powered by NyayaAI · Judge Portal';
  static const heroSubtitle =
      'Manage your docket, review cases, and issue orders — all from one place.';
  static const viewDocket = 'View Docket';
  static const upcomingHeading = 'Upcoming Hearings';
  static const upcomingEmpty = 'No upcoming hearings';

  // ---- Case Docket (JD:196-248, 582-767) -------------------------------------

  static const docketHeading = 'Case Docket';
  static const newHearing = '+ New Hearing';
  static const docketEmpty = 'No hearings found';
  static const deleteConfirm = 'Delete this hearing entry?';

  /// `#statusFilter` (JD:209-216): label, then the wire value.
  static const statusFilters = [
    ('All Status', ''),
    ('Scheduled', 'scheduled'),
    ('Adjourned', 'adjourned'),
    ('Completed', 'completed'),
    ('Cancelled', 'cancelled'),
  ];

  /// `#urgencyFilter` (JD:217-222).
  static const urgencyFilters = [
    ('All Urgency', ''),
    ('Urgent', 'urgent'),
    ('Normal', 'normal'),
  ];

  /// `#statusInput` (JD:410-416).
  static const statusOptions = [
    ('Scheduled', 'scheduled'),
    ('Adjourned', 'adjourned'),
    ('Completed', 'completed'),
    ('Cancelled', 'cancelled'),
  ];

  /// `#urgencyInput` (JD:402-406).
  static const urgencyOptions = [
    ('Normal', 'normal'),
    ('Urgent', 'urgent'),
  ];

  // ---- the hearing modal (JD:365-441, 509-564, 713-763) ----------------------

  static const modalNew = 'New Hearing';
  static const modalEdit = 'Edit Hearing';
  static const caseIdLabel = 'Case ID (FIR Number)';
  static const caseIdHint = 'Search FIR number, complainant, or district…';
  static const hearingDateLabel = 'Hearing Date & Time';
  static const caseTypeLabel = 'Case Type';
  static const caseTypeHint = 'e.g. Criminal, Civil';
  static const noFirMatch = 'No matching FIR found';
  static const noFirPreview =
      '⚠ No matching FIR record found — hearing will still save, but Case '
      "Workspace won't show FIR details.";

  static const caseIdRequired = 'Case ID is required.';
  static const hearingDateRequired = 'Hearing date & time is required.';
  static const hearingDatePast = 'Hearing date cannot be in the past.';
  static String duplicate(String caseId) =>
      'Case $caseId is already in your docket.';
  static const saveFailed = 'Could not save hearing.';

  /// How many suggestions the dropdown lists (`.slice(0, 8)`, JD:523).
  static const firSuggestionLimit = 8;

  // ---- Case Workspace (JD:252-290, 770-841) ----------------------------------

  static const workspaceHeading = 'Case Workspace';
  static const workspaceEmpty = 'No cases in your docket yet.';
  static const firDetailsHeading = 'FIR Details';
  static const timelineHeading = 'Hearing Timeline';
  static const noLinkedFir = 'No linked FIR record found for this Case ID.';
  static const noRemarks = 'No remarks';

  // ---- Law Library (JD:294-359, 843-1188) ------------------------------------

  static const libraryHeading = 'Law Library';
  static const tabBrowse = 'Browse Acts';
  static const tabResearch = 'Precedent Research';
  static const tabBookmarks = 'Bookmarks';
  static const sectionSearchHint =
      'Search sections by number, title, or keyword — select an act to narrow, '
      'or search all acts…';
  static const selectAnAct = 'Select an act to browse its sections';
  static const noSections = 'No sections found';
  static const noDescription = 'No description available.';
  static const noBookmarks = 'No bookmarked sections yet';
  static const openBareAct = 'Open Bare Act (PDF) ↗';
  static String openCurrentLaw(String code) => 'Open Current Law ($code) ↗';

  /// `limit: 15` (JD:935).
  static const sectionsPerPage = 15;

  /// The search box's debounce (JD:921-924).
  static const searchDebounce = Duration(milliseconds: 350);

  static const researchLabel =
      'Ask about precedents, sections, or legal principles';
  static const researchHint =
      'e.g. Supreme Court precedents on anticipatory bail in economic offences';
  static const research = 'Research';
  static const researching = 'Researching…';
  static const researchWaiting = 'Searching case law and statutes…';
  static const researchFailed = 'Something went wrong. Please try again.';
  static const noResults = 'No results.';

  /// `ACT_LABELS` (JD:844-853).
  static const actLabels = {
    'IPC': 'Indian Penal Code',
    'CRPC': 'Code of Criminal Procedure',
    'NIA': 'Negotiable Instruments Act',
    'IEA': 'Indian Evidence Act',
    'HMA': 'Hindu Marriage Act',
    'CPC': 'Code of Civil Procedure',
    'IDA': 'Industrial Disputes Act',
    'MVA': 'Motor Vehicles Act',
  };

  /// The repealed acts and what replaced them (`ACT_META`, JD:866-875). Every
  /// other act — including any the server adds — is "Current law".
  static const repealedBy = {'IPC': 'BNS', 'CRPC': 'BNSS', 'IEA': 'BSA'};
}

/// Server paths, relative to `AppConfig.baseUrl`.
///
/// Collected here so a route rename on the server is a one-line change rather
/// than a grep through data sources. Only the endpoints a shipped feature
/// actually calls belong in this file.
abstract final class ApiEndpoints {
  const ApiEndpoints._();

  // ---- authentication -------------------------------------------------------

  /// `POST` — body `{email, password}`.
  /// 200 `{message, role, unique_id, redirect}` + `Set-Cookie: session=...`
  /// 400 `{error: "Email and password are required"}`
  /// 401 `{error: "Invalid credentials"}`
  static const login = '/login';

  /// `POST` — body `{fullname, email, password, role, unique_id?}`.
  /// 201 `{message, unique_id, role}`
  /// 400 `{error: ...}` — see AuthRepository for the full set.
  ///
  /// Does NOT establish a session: the server registers the account and
  /// returns, leaving the caller signed out. The app signs in afterwards.
  static const signup = '/signup';

  /// `GET` — clears the server session and 302s to `/`. The redirect is HTML,
  /// so the client follows nothing and only cares that it returned 2xx/3xx.
  static const logout = '/logout';

  /// `GET` — always 200, never throws.
  /// `{logged_in: bool, role: String?, user_id: String?}`
  ///
  /// The only endpoint that can answer "is the stored cookie still valid?", so
  /// it is what session restore is built on. Note it does NOT return the
  /// display name or unique ID — those are cached locally at sign-in.
  ///
  /// Lives on the missing-persons blueprint server-side, but it reads the same
  /// Flask session every route uses, so it is a general session probe.
  static const me = '/api/me';

  // ---- FIR registration (FORM IF-1) -----------------------------------------

  /// `POST` — body is the 27-field FORM IF-1 payload (see `FirSubmission`).
  /// 200 the stored document + `{formatted_fir, message, pdf_file}`
  /// 400 `{error: "FIR number <no> already exists"}` — the only rejection
  ///     the handler makes; every other field is accepted as sent.
  /// 500 `{error: "Failed to save FIR to database", details}`
  ///
  /// NOTE: the handler has no session check at all. The app gates the screen on
  /// the signed-in role, which is cosmetic — see docs/features/01-authentication
  /// "Known issues in the server".
  ///
  /// If `act_sections` arrives empty the server fills it from an analysis of the
  /// narrative and files the record under what it finds. The app relies on that
  /// — the form's sections field is optional, as the website's is — and reads
  /// the filed sections back off the receipt rather than assuming what was sent.
  /// See `FirDraft.missingIn` and `FirReceipt.actSections`.
  static const generateFir = '/generate_fir';

  /// `POST` — body `{statement}`.
  /// 200 `{suggestions: [{act, section, title, reason, confidence}], source,
  ///      note, message?}`
  /// 401 `{error: "Please log in."}`
  /// 403 `{error: "Police login required."}`
  ///
  /// Suggests acts and sections for a complaint narrative, with a one-line
  /// reason each, so the officer sees them **before** filing rather than reading
  /// them off the receipt afterwards.
  ///
  /// It proposes and never writes. `/generate_fir` still files whatever the
  /// officer ended up with, and still runs its own keyword matcher when the
  /// field arrives empty — this endpoint changes neither, so ignoring it
  /// entirely leaves the form behaving exactly as it did.
  ///
  /// `source` says which engine answered: `groq` when the model read the
  /// narrative (every section it named was checked against the server's section
  /// tables and dropped if it does not exist), `keyword` when the model was
  /// unreachable and the old matcher answered instead, `none` when nothing
  /// matched. The screen reports it, because the two are not equally good.
  ///
  /// A narrative under 20 characters comes back 200 with an empty list and a
  /// `message` — an officer who has typed two words has not finished, and that
  /// is not an error worth a red banner.
  ///
  /// **Unlike `/generate_fir`, the police gate here is real** — 401 and 403 are
  /// reachable states this app has to be able to show, not ones the UI guard
  /// makes impossible.
  static const suggestSections = '/api/suggest-sections';

  /// `GET` — a sorted JSON array of strings. Named "districts" by the server;
  /// the values are actually states and union territories.
  static const districts = '/api/districts';

  /// `GET` — a JSON array of station names for one district. Never 404s: an
  /// unknown district gets `["<district> PS"]` synthesised back.
  static String policeStations(String district) =>
      '/api/police-stations/${Uri.encodeComponent(district)}';

  /// `GET` — the eight act codes the section tables are keyed by
  /// (`IPC`, `CRPC`, `NIA`, `IEA`, `HMA`, `CPC`, `IDA`, `MVA`).
  static const acts = '/api/acts';

  // ---- FIR history and viewer (police only) ---------------------------------

  /// `GET` — a JSON array of every stored FIR, `_id` stripped, each document
  /// carrying all 27 IF-1 columns plus `fir_id`, `pdf_file`, `created_at` and
  /// `status`.
  /// 500 `{error: "Failed to retrieve FIR records", details}`
  ///
  /// Takes no query, no page and no sort: the whole collection comes back on
  /// every call, oldest insertion first. Searching and ordering are therefore
  /// the app's to do — see `FirRepositoryImpl.history`.
  ///
  /// NOTE `created_at` arrives here as an RFC 1123 HTTP date
  /// (`Sat, 09 Aug 2026 02:31:00 GMT`), because `jsonify` serialises a
  /// `datetime` that way — *not* in the `str(datetime)` shape `/generate_fir`
  /// replies with. Both are parsed by `ServerTime`.
  static const firRecords = '/api/fir-records';

  /// `GET` — one stored FIR, same shape as an element of [firRecords].
  /// 404 `{error: "FIR record <no> not found"}`
  static String firRecord(String firNo) =>
      '/api/fir-records/${Uri.encodeComponent(firNo)}';

  /// `GET` — the PDF the server generated when the FIR was filed, as an
  /// attachment named `<fir_no>.pdf`.
  /// 404 `{error: "PDF for FIR <no> not found"}`
  ///
  /// Served off `generated_firs/` with **no session check**, like the evidence
  /// files. The 404 is a normal outcome rather than an edge case: the folder
  /// lives on whichever machine ran the server at filing time, so records
  /// restored from a database backup, or filed against a different deployment,
  /// have a `pdf_file` column and no file behind it.
  ///
  /// The handler looks the file up as `FIR_<secure_filename(fir_no)>.pdf` while
  /// the generator wrote `FIR_<fir_no>.pdf` unsanitised — so any FIR number that
  /// `secure_filename` would rewrite cannot be downloaded at all. In practice
  /// such records do not exist, because generating one fails first: a number
  /// containing `/` makes the PDF write throw and the whole filing 500s. Both
  /// are server bugs; see docs/features/04-fir-history.md.
  static String firDownload(String firNo) =>
      '/fir/download/${Uri.encodeComponent(firNo)}';

  // ---- evidence locker (police only) ----------------------------------------

  /// `GET` — every stored file, grouped: `{"<fir_no>": ["a.jpg", "b.pdf"], …}`.
  ///
  /// The only endpoint that answers "what is in the locker" without being told a
  /// FIR number first, which is what the list screen needs. It carries filenames
  /// and nothing else — no size, no type, no timestamp — so the list derives the
  /// category from the extension and fetches the rest per FIR when one is
  /// opened.
  static const allEvidence = '/get-all-evidence';

  /// `GET ?fir_no=<no>` — the same files for one FIR, with metadata:
  /// `[{fir_no, filename, file_type, file_url, uploaded_at}]`.
  ///
  /// `file_type` is a *category* the server derives from the extension
  /// (`image` / `video` / `audio` / `pdf` / `other`), not a MIME type — despite
  /// the column of the same name in Mongo holding a MIME type. Answers `[]`, not
  /// 404, for an unknown FIR.
  static String evidenceForFir(String firNo) =>
      '/api/evidence?fir_no=${Uri.encodeQueryComponent(firNo)}';

  /// `POST` — multipart `{fir_no, file}`.
  /// 200 `{message, file, fir_no}`
  /// 400 `{error: "Missing FIR or file"}`
  /// 400 `{error: "FIR number does not exist. Please enter a valid FIR."}`
  ///
  /// The FIR check is the only server-side validation in the locker, and it is
  /// the reason evidence cannot be attached while an FIR is being written: the
  /// record has to exist first.
  ///
  /// Silently de-duplicates on `(fir_no, filename)` — a second upload of the
  /// same name overwrites the file on disk and inserts no second row.
  static const uploadEvidence = '/upload-evidence';

  /// The stored file itself. Served straight off disk by `send_from_directory`
  /// with **no session check**, which is what lets `Image.network` render a
  /// preview without the cookie jar Dio holds.
  static String evidenceFile(String firNo, String filename) =>
      '/evidence-file/${Uri.encodeComponent(firNo)}/'
      '${Uri.encodeComponent(filename)}';

  /// `POST` — body `{pin}`.
  /// 200 `{success: true}`
  /// 401 `{success: false, message: "Wrong Password ❌"}`
  ///
  /// The locker's PIN gate, and the same check the website's console makes
  /// before it will render the locker. The app used to compare a PIN of its own
  /// in Dart, which meant the two clients opened the same locker with two
  /// different strings — an officer who had been given the station PIN by a
  /// colleague using the website could not get in on the handset.
  ///
  /// Not a security control on either side. `/upload-evidence`, `/api/evidence`,
  /// `/get-all-evidence` and `/evidence-file/...` have no session check at all,
  /// so anyone who can reach the server can read the locker without ever seeing
  /// this. What the gate stops is a phone left unlocked on a desk. The real fix
  /// is server-side; see docs/features/03-evidence-locker.md.
  static const verifyLockerAccess = '/verify-locker-access';

  /// `POST` — body `{fir_no, filename, action}`. Always 200 `{logged: true}`.
  ///
  /// A stub server-side: the handler acknowledges and discards. The app calls it
  /// anyway, fire-and-forget, because access logging is the half of the locker
  /// that makes it a locker rather than a folder — and when the handler is given
  /// a body to write, every client is already sending one.
  static const logEvidenceAccess = '/api/evidence/log-access';

  // ---- the law library (police only) ----------------------------------------

  /// `GET ?search=&page=&limit=` — one act's sections, paginated.
  /// 200 `{act, page, limit, pages, total, results: [{section, title,
  ///      description}]}`
  /// 400 `{error: "Invalid act"}` for anything not in [acts].
  /// 500 `{error: <sqlite message>}`
  ///
  /// `section` comes back as a **number**, not a string — the column is an
  /// INTEGER in `IndiaLaw.db` — so it is read through the models' `_text`
  /// rather than cast. Sections like `304A` do not exist in this table for the
  /// same reason.
  ///
  /// `search` matches the section number, the title and the description, all
  /// lower-cased server-side. Unlike [searchSections] it is scoped to one act,
  /// which is what the library's own search box wants.
  static String sections(
    String act, {
    String search = '',
    int page = 1,
    int limit = 20,
  }) {
    final query = {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': '$page',
      'limit': '$limit',
    };
    final encoded = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '/api/sections/${Uri.encodeComponent(act)}?$encoded';
  }

  /// `GET` — one section in full.
  /// 200 `{section, title, description}`
  /// 400 `{error: "Invalid act"}`
  /// 404 `{error: "Section not found"}`
  ///
  /// What the website's comparison tool is built on: it calls this twice and
  /// puts the two answers side by side. The app does the same.
  static String sectionDetail(String act, String section) =>
      '/api/section-detail/${Uri.encodeComponent(act)}/'
      '${Uri.encodeComponent(section)}';

  /// `GET ?q=` — sections matching [query] across **every** act.
  /// 200 a JSON array of `{act, section, title}` — no description, so opening
  ///     a result means a second call to [sectionDetail].
  ///
  /// Note the shape differs from [sections] in three ways: a bare array rather
  /// than a paginated envelope, an `act` on every row, and no `description`.
  /// They are two different endpoints that happen to search the same tables.
  static String searchSections(String query) =>
      '/api/search-sections?q=${Uri.encodeQueryComponent(query)}';

  /// `POST` — body `{question}`.
  /// 200 `{answer: <plain text>}`
  /// 400 `{answer: "❌ Please ask a legal question."}` for a blank question.
  ///
  /// **The answer is prose, not data.** The handler builds a block of text with
  /// emoji headings and box-drawing rules, meant to be dropped into a `<pre>`.
  /// The app shows it as-is rather than parsing it: the shape is not a contract,
  /// and a client that split it on `━` would break the first time somebody
  /// edited the template.
  ///
  /// Backed by a RAG index over the same section tables, so it answers about
  /// Indian law and nothing else. A question it cannot match comes back as
  /// `{answer: "❌ No matching legal section found."}` with HTTP 200 — a normal
  /// answer, not an error.
  static const askLaw = '/api/ask-law';

  /// `POST` — body `{situation}`.
  /// 200 `{prediction: <html>, results: [...]}`
  /// 400 `{prediction: "❌ Please describe the situation."}`
  ///
  /// `prediction` is Tailwind-classed HTML for the website's page. **The app
  /// reads `results`**, the same search before it was rendered: each entry
  /// carries `act`, `section`, `title`, `description`, `punishment`,
  /// `bns_equivalent`, `sentencing_range`, `cognizable`, `bailable`,
  /// `outcome_note` and `score`.
  ///
  /// `results` was added to the handler for this app. Scraping the markup would
  /// have made every styling change on the website a crash on the handset.
  static const predictOutcome = '/api/predict-outcome';

  // ---- missing persons ------------------------------------------------------
  //
  // The only endpoints in this file with a session check that actually works.
  // `/upload_missing_person`, `/get_sightings/<id>`, `/get_confirmed_matches`
  // and `/update_missing_person_status/<id>` all call `_is_police()` and answer
  // 403 to anyone else — unlike `/generate_fir` and the evidence locker, whose
  // police gate is cosmetic. So a 403 here is a real refusal the app has to be
  // able to show, not a state the UI guard makes unreachable.
  //
  // These live on the missing-persons blueprint, in SQLite rather than Mongo,
  // beside the same `citizen_complaints` table the complaints feature reads.

  /// `GET` — every case still open, newest first.
  /// 200 `{success: true, missing_persons: [{person_id, name, age, gender,
  ///      description, photo_url, last_seen_location, last_seen_date,
  ///      created_at, status}]}`
  ///
  /// **Only `status = 'Missing'`.** A case marked Found or Closed disappears
  /// from this list and there is no endpoint that returns it, so the app cannot
  /// show a history of resolved cases however much it might want to.
  ///
  /// `age` is an INTEGER column and arrives as a number; `photo_url` is a path
  /// under the server's own static root, already `/`-prefixed.
  ///
  /// No session check on this one — a citizen has to be able to see who is
  /// missing.
  static const missingPersons = '/get_missing_persons';

  /// `POST` — multipart `{name, photo, age?, gender?, description?,
  /// last_seen_location?, last_seen_date?}`.
  /// 200 `{success: true, message, person_id}`
  /// 400 `{success: false, error: "Full name is required."}`
  /// 400 `{success: false, error: "No photo file received."}`
  /// 400 `{success: false, error: "Only JPG, PNG, GIF, WEBP images accepted."}`
  /// 400 `{success: false, error: "No face detected in the photo. …"}`
  /// 403 `{success: false, error: "Police login required."}`
  ///
  /// The face check is the one to design around: the server runs the photograph
  /// through `extract_face` and **deletes it and refuses** when it finds none.
  /// A group photo, a poor scan or a profile shot is a 400, not a stored record,
  /// so the app has to put the server's sentence in front of the officer rather
  /// than a generic failure.
  static const uploadMissingPerson = '/upload_missing_person';

  /// `POST` — multipart `{photo, location, sighting_date?}`.
  /// 200 `{success: true, sighting_id, face_match_score, is_match, details,
  ///      message}`
  /// 400 — a missing photo, a missing location, or no face in the photo.
  /// 401 `{success: false, error: "Please log in to report a sighting."}`
  /// 404 `{success: false, error: "Record not found or already resolved."}`
  ///
  /// **Any signed-in role, not just police.** The comment in the handler is
  /// explicit about it: citizens report sightings. The face comparison runs
  /// server-side against the registered photograph at a tolerance of 0.55, and
  /// `is_match` is that comparison's verdict — recorded either way, so a
  /// near-miss is still on the record for an officer to look at.
  static String reportSighting(String personId) =>
      '/report_sighting/${Uri.encodeComponent(personId)}';

  /// `GET` — every sighting reported against one case, newest first.
  /// 200 `{success: true, sightings: [{sighting_id, photo_url, location,
  ///      sighting_date, face_match_score, is_confirmed, uploaded_at}]}`
  /// 403 `{success: false, error: "Police login required."}`
  static String sightings(String personId) =>
      '/get_sightings/${Uri.encodeComponent(personId)}';

  /// `GET` — the sightings the face comparison confirmed, grouped by person.
  /// 200 `{success: true, confirmed_matches: [{person_id, name,
  ///      missing_person_photo, confidence, location, sighting_date,
  ///      uploaded_at, sighting_photo, sightings: [{photo, location, date,
  ///      score}]}]}`
  /// 403 `{success: false, error: "Police login required."}`
  ///
  /// `confidence` and each `score` are **percentages already** — the handler
  /// multiplies by 100 and rounds — unlike `face_match_score` on [sightings],
  /// which is the raw 0–1 figure. Two spellings of one number, and the reason
  /// the models convert rather than pass either straight through.
  static const confirmedMatches = '/get_confirmed_matches';

  /// `POST` — body `{status}`, one of `Missing`, `Found`, `Closed`.
  /// 200 `{success: true, message}`
  /// 400 `{success: false, error: "Invalid status value."}`
  /// 403 `{success: false, error: "Police login required."}`
  ///
  /// Moving a case off `Missing` removes it from [missingPersons] and from
  /// [confirmedMatches], and nothing brings it back into either — see the note
  /// on [missingPersons].
  static String updateMissingPersonStatus(String personId) =>
      '/update_missing_person_status/${Uri.encodeComponent(personId)}';

  // ---- citizen complaints (police only) -------------------------------------

  /// `GET` — every complaint a citizen has filed, as a JSON array:
  /// `[{tracking_id, full_name, phone, incident_description, incident_date,
  ///    location, status, fir_no, officer_notes, created_at, updated_at}]`
  /// 500 `{error: <sqlite message>}`
  ///
  /// Takes no query, no page and no status filter — the whole table comes back
  /// on every call, `ORDER BY created_at DESC`. Filtering by status, by date and
  /// by text is therefore the app's to do, exactly as it is for FIR history; see
  /// `ComplaintFilter`.
  ///
  /// This is the **only** complaints endpoint that returns `phone`, which is why
  /// `complaintProvider` resolves a single complaint out of this list rather than
  /// from [complaint] below. An officer's first action on a complaint is usually
  /// to ring the person who filed it.
  ///
  /// Unlike the FIRs, these live in SQLite, not Mongo — `citizen_complaints`,
  /// created at start-up by `init_complaints_table()`. So `created_at` and
  /// `updated_at` arrive as SQLite's `CURRENT_TIMESTAMP`,
  /// `2026-08-09 02:31:00` in UTC, which [ServerTime] already reads.
  static const allComplaints = '/api/complaints/all';

  /// `GET` — one complaint by its tracking ID (`CMP-1A2B3C4D`). The handler
  /// upper-cases the ID before looking it up, so the app sends it that way too.
  /// 404 `{error: "Complaint not found. Check your tracking ID."}`
  ///
  /// **Returns nine columns, not ten: `phone` is missing.** The handler's SELECT
  /// simply does not list it. Used only as the fallback when a complaint is not
  /// in the list already in memory — a deep link, or a return from process death.
  static String complaint(String trackingId) =>
      '/api/complaint/${Uri.encodeComponent(trackingId.toUpperCase())}';

  /// `PATCH` — body `{status, fir_no, officer_notes}`.
  /// 200 `{message: "Updated successfully", tracking_id}`
  /// 400 `{error: "Invalid status"}` — `status` must be exactly one of
  ///     `Pending`, `Under Review`, `FIR Filed`, `Closed`. See
  ///     [ComplaintStatus], which is that list.
  /// 404 `{error: "Complaint not found"}`
  ///
  /// **Not a partial update, despite the verb.** The handler writes all three
  /// columns unconditionally from `data.get(...)`, so a body carrying only
  /// `status` sets `fir_no` and `officer_notes` to NULL — it erases the officer's
  /// notes and the FIR link as a side effect of closing a complaint. Every call
  /// therefore sends the full triple, which is why the repository reads the
  /// complaint back before writing; see `ComplaintRepositoryImpl.update`.
  ///
  /// No session check, like `/generate_fir` and the whole evidence locker: the
  /// police gate on these screens protects the officer from a dead end, not the
  /// record from a citizen. See docs/features/01-authentication.md.
  static String updateComplaint(String trackingId) =>
      '/api/complaints/${Uri.encodeComponent(trackingId.toUpperCase())}';

  // ---- the Citizen portal ---------------------------------------------------
  //
  // The same endpoints `templates/citizen_dashboard.html` calls, with the same
  // bodies. None of them checks the session — the website's citizen page is
  // gated, the API behind it is not — so they answer the app exactly as they
  // answer the browser. See .claude/spec/citizen_parity_spec.md §4.

  /// `POST` — body `{full_name, phone, incident_date, location,
  /// incident_description}`.
  /// 201 `{tracking_id, status: "Pending", category, can_file_fir}`
  /// 400 `{error: "Name and incident description are required"}`
  /// 500 `{error: <exception text>}`
  ///
  /// The complaint is stored with no link to the citizen's account; the
  /// tracking ID is the only handle on it afterwards (limitation L1).
  static const fileComplaint = '/api/complaint';

  /// The citizen's tracking lookup is [complaint] above — the same
  /// `GET /api/complaint/<tracking_id>` the police fallback uses.

  /// `POST` — body `{question}`.
  /// 200 `{answer}`; 400 `{answer: "Please ask a question about your rights."}`
  ///
  /// The website shows `answer` whatever the status, and so does the app. A
  /// question that matches no law section currently makes the handler 500 with
  /// an HTML page (limitation L2) — the website then says "Could not connect…",
  /// and so does the app.
  static const rightsChat = '/api/rights-chat';

  /// `GET` — what a lawyer has chosen to share about one FIR.
  /// 200 `{fir_no, status, next_hearing_date, client_note,
  ///      client_note_updated_at}`
  /// 404 `{error: "Status not available for this FIR"}` — for an unknown FIR
  ///     and for one the lawyer has not shared, alike.
  static String caseClientStatus(String firNo) =>
      '/api/case/${Uri.encodeComponent(firNo)}/client-status';

  // ---- lawyer portal --------------------------------------------------------
  //
  // Every route below answers 401 `{error: "Unauthorized"}` without a lawyer
  // session. The `/api/case/<fir_no>/...` ones also answer 403
  // `{error: "Forbidden"}` unless this lawyer is the FIR's `assigned_lawyer_id`
  // (`lawyer_owns_case`, app.py:304-309). They use Flask's default converter,
  // so an FIR number containing `/` cannot reach them (limitation LL-4).
  //
  // There is no endpoint that lists a lawyer's cases: the website renders them
  // into `/lawyer_dashboard` server-side (app.py:1079-1088). The app rebuilds
  // the same list from [firRecords] and [me] — see `LawyerRemoteDataSource`.

  /// `POST` — no body. Sets this lawyer as the FIR's `assigned_lawyer_id`.
  /// 200 `{message: "Case added to your dashboard", fir_no}`
  /// 404 `{error: "FIR not found"}`
  static String assignLawyer(String firNo) =>
      '/api/fir-records/${Uri.encodeComponent(firNo)}/assign-lawyer';

  static String _case(String firNo) =>
      '/api/case/${Uri.encodeComponent(firNo)}';

  /// `GET` — `[{id?, fir_no, hearing_date, note, …}]`, oldest first.
  /// `POST` `{hearing_date, note}` → 201 `{message: "Hearing added"}`; also
  /// moves the FIR's `next_hearing_date` to the earliest hearing from today on.
  static String caseHearings(String firNo) => '${_case(firNo)}/hearings';

  /// `GET` — `[{id, fir_no, kind, content, created_at}]`, newest first.
  /// `POST` `{kind, content}` → 201 `{message: "Draft saved", id}`.
  static String caseDrafts(String firNo) => '${_case(firNo)}/drafts';

  /// `DELETE` → 200 `{message: "Draft deleted"}`, matched or not.
  static String caseDraft(String firNo, Object draftId) =>
      '${caseDrafts(firNo)}/$draftId';

  /// `PATCH` `{status}` — one of `Investigation`, `Court Proceedings`, `Trial`,
  /// `Closed`. 200 `{message: "Status updated", status}`;
  /// 400 `{error: "Invalid status"}`.
  static String caseStatus(String firNo) => '${_case(firNo)}/status';

  /// `GET` — `[{id, fir_no, deadline_type, due_date, note, completed}]`, soonest
  /// first. `POST` `{deadline_type, due_date, note}` → 201
  /// `{message: "Deadline added", id}`.
  static String caseDeadlines(String firNo) => '${_case(firNo)}/deadlines';

  /// `PATCH` `{completed}` / `DELETE`. 200 either way.
  static String caseDeadline(String firNo, Object deadlineId) =>
      '${caseDeadlines(firNo)}/$deadlineId';

  /// `PATCH` `{visible, note}` — the writer behind [caseClientStatus].
  /// 200 `{message: "Updated", visible}`.
  static String caseClientVisibility(String firNo) =>
      '${_case(firNo)}/client-visibility';

  /// `GET` — every saved draft across this lawyer's cases, newest first.
  static const lawyerDrafts = '/api/lawyer/drafts';

  /// `GET` — incomplete deadlines due within 14 days (overdue included) across
  /// this lawyer's cases, soonest first.
  static const lawyerDeadlines = '/api/lawyer/deadlines';

  /// `GET` — `{fullname, email, unique_id, phone, office_address, bio,
  /// years_experience, bar_enrollment_no, practice_area, photo_url}`.
  /// `PATCH` — any of the six editable fields → 200 `{message}`.
  static const lawyerProfile = '/api/lawyer/profile';

  /// `POST` multipart `photo` → 200 `{message, photo_url}` (Supabase public URL).
  static const lawyerProfilePhoto = '/api/lawyer/profile/photo';

  /// `POST` `{prompt}` → 200 `{text}` (Groq, else a RAG template).
  static const lawyerDraftDocument = '/api/lawyer/draft-document';

  /// `POST` `{prompt}` → 200 `{text}` (Groq, else a RAG template).
  static const lawyerBailDraft = '/api/lawyer/bail-draft';

  /// `POST` `{query, type}` → 200 `{answer}`.
  ///
  /// Only when Groq *fails*: the handler's one `return` sits inside
  /// `if not answer:` (app.py:1294-1303), so a successful Groq answer ends the
  /// view with `None` and Flask sends a 500 page (limitation LL-2).
  static const lawyerFindPrecedents = '/api/lawyer/find-precedents';

  // ---- judge portal (main/judge_routes.py, app.py) --------------------------
  //
  // Every `/judge/docket` route checks only `session['role'] == 'judge'` and
  // answers 403 `{error: "unauthorized"}` otherwise — signed out included.

  /// `GET` `?status=&urgency=` — this judge's `case_docket` rows, by
  /// `hearing_date` ascending.
  /// `POST` `{case_id, hearing_date: "YYYY-MM-DD HH:MM", case_type, urgency,
  /// status, remarks}` → 201 the new row (`status` is always stored as
  /// `scheduled`); 400 `{error, message}` for a missing case ID, an unreadable
  /// or past date; 409 `{error, message}` for a duplicate case or a hearing
  /// within 30 minutes of another.
  static const judgeDocket = '/judge/docket';

  /// [judgeDocket] with the page's filters; empty values are left out, as
  /// `URLSearchParams` leaves them out (judge_dashboard.html:585-589).
  static String judgeDocketFiltered({String status = '', String urgency = ''}) {
    final query = {
      if (status.isNotEmpty) 'status': status,
      if (urgency.isNotEmpty) 'urgency': urgency,
    };
    if (query.isEmpty) return judgeDocket;
    final encoded = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$judgeDocket?$encoded';
  }

  /// `PUT` (any of `hearing_date, case_type, urgency, status, remarks`;
  /// `case_id` is ignored) → 200 the updated row. `DELETE` → 200
  /// `{deleted: id}`. 404 `{error: "not_found"}` when the entry is not this
  /// judge's.
  static String judgeDocketEntry(int id) => '$judgeDocket/$id';

  /// `POST` `{query}` → 200 `{current_law, directly_relevant, related_authorities,
  /// principles, statutory_sections, synthesis, sources, no_result_notice,
  /// ai_notice}`; 400 `{error}` for a blank query; 401 `{error: "Unauthorized"}`
  /// for anyone but a judge.
  static const judgePrecedents = '/judge/precedents';

  /// `GET` — a redirect to the act on indiacode.gov.in, or an HTML page saying
  /// it could not be reached. No session check. Opened outside the app, as the
  /// page opens it in a new tab.
  static String openBareAct(String actCode) =>
      '/open-bare-act/${Uri.encodeComponent(actCode)}';
}

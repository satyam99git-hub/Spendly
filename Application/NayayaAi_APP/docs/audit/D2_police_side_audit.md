# D2 — Police-Side Functional Audit

**Scope:** every screen reachable by a `police` or `admin` account in `flutter_app/lib/`, checked against the **current** Flask server (`website/app.py`, `website/missing_person.py`, `website/main/storage_service.py`).
**Audit only.** No code was changed.

**Evidence gathered (2026-09-20):**
- Read each screen, controller, data source and the matching Flask handler.
- `flutter analyze` → **No issues found**.
- `flutter test` (offline suite) → **453 passed, 0 failed**.
- ⚠️ The offline tests run against **fake repositories** (`test/helpers/fake_*_repository.dart`), so they cannot detect drift between the app and the server contract. The live suite (`test_live/`) and manual runs against the server were **not** executed: the Flask server was not running and this phase is audit-only. Every "Working" status below means the code path is correct against the current server source, **not yet exercised live**. Live confirmation belongs to D7.

**Status key:** **Working** = the code path is correct end-to-end against the current server. **Partial** = it works for some inputs or states, and the gap is described. **Broken** = the documented purpose fails for normal input. **Not built** = there is no screen.

---

## Audit table

| Area | Sub-feature | Implementation Status | File(s) | Backend Endpoint | Issues Found |
|---|---|---|---|---|---|
| App start | Splash + session restore | Working | `features/splash/presentation/screens/splash_screen.dart`, `authentication/presentation/controllers/auth_controller.dart` (`_restore`), `routes/app_router.dart` | `GET /api/me` (`missing_person.py:116`) | Unreachable server → signed out, cookie kept (by design). 3 s splash floor, 8 s restore timeout. |
| Auth | Login | Working | `authentication/presentation/screens/login_screen.dart`, `auth_remote_data_source.dart#login`, `auth_repository_impl.dart#login` | `POST /login` (`app.py:2052`) | Minor: HTTP 429 from Flask-Limiter has an HTML body, so the user sees the generic "Something went wrong" instead of a rate-limit message (`ErrorMapper.extractMessage` drops HTML). HTTP 423 lock-out shows the server text correctly. |
| Auth | Signup (shared by all roles) | **Partial** | `authentication/presentation/screens/signup_screen.dart`, `core/utils/validators.dart#signupPassword`, `auth_models.dart#SignupResponse` | `POST /signup` (`app.py:1979`) | **AUTH-1**, **AUTH-2** (below). |
| Auth | Session / token refresh | Partial (by design) | `core/network/dio_client.dart`, `auth_repository_impl.dart#restoreSession` | `GET /api/me` | No refresh endpoint exists on the server. The session lasts 8 h (`app.py:99`, `session.permanent=True` at `:2089`). Expiry is detected only at the next cold start; mid-session there is no global 401 handler, so a gated call just shows its error. The comments in `pubspec.yaml:35-38` and `dio_client.dart` say the cookie has "no Expires"; that is now stale because the cookie is permanent. See **AUTH-3**. |
| Auth | Logout | Working | `dashboard/presentation/widgets/dashboard_cards.dart#confirmSignOut`, `auth_repository_impl.dart#logout` | `GET /logout` (`app.py:2114`) | Server failure still clears the local cookie and cache (correct). |
| Routing | Role guard for police routes | Working (UI-only) | `routes/app_router.dart` (step 5), `routes/app_routes.dart#policePrefixes` | — | A client-side guard only. See D1 S6: most police endpoints have no server check. |
| Dashboard | Console shell (4 tabs) | Working | `dashboard/presentation/screens/police_dashboard_screen.dart` | — | Tabs: FIR / Complaints / Evidence / Law. Locker relocks on tab exit. |
| Dashboard | Stats loading | Working (no server stats) | `police_dashboard_screen.dart#_PendingBadge` | derived from `GET /api/complaints/all` | There is no stats endpoint. The pending badge appears only after the Complaints tab has been fetched (documented, deliberate). |
| FIR | Register FIR (4-step wizard + review) | **Partial** | `fir/presentation/screens/fir_form_screen.dart`, `fir_form_controller.dart`, `fir/domain/entities/fir_draft.dart#missingIn`, `fir/data/models/fir_models.dart#FirSubmission`, `steps/fir_occurrence_step.dart` | `POST /generate_fir` (`app.py:1786`, validation `app.py:219-302`) | **FIR-1** (below): the server's newer validation rejects inputs the app allows, and the app shows only "Validation failed". |
| FIR | Draft autosave / restore | Working | `fir_form_controller.dart`, `core/constants/storage_keys.dart#firDraft` | — (secure storage) | — |
| FIR | Suggest acts & sections (AI) | Working | `fir/presentation/widgets/suggest_sections_sheet.dart`, `section_suggestion_controller.dart`, `fir_remote_data_source.dart#suggestSections` | `POST /api/suggest-sections` (`app.py:1737`; Groq with keyword fallback, `website/sections_ai.py`) | Real police gate (401/403) and a real 30/min rate limit. The client short-circuits under 20 characters. |
| FIR | District / station / act lookups | Working | `fir/presentation/widgets/fir_lookup_field.dart`, `fir_lookup_providers.dart` | `GET /api/districts`, `/api/police-stations/<d>`, `/api/acts` (`app.py:519-533`) | Falls back to typed entry on failure. A typed district outside the list is rejected by the server (FIR-1). |
| FIR | Success / receipt | Working | `fir/presentation/screens/fir_success_screen.dart` | (response of `/generate_fir`) | Route is guarded so it cannot open without a receipt. |
| FIR | History list / search | Working | `fir/presentation/screens/fir_history_screen.dart`, `fir_repository_impl.dart#history` | `GET /api/fir-records` (`app.py:1711`, Supabase `firs`) | Whole table fetched, sorted and filtered client-side. No auth on the endpoint (D1 S6). |
| FIR | Record viewer | Working | `fir/presentation/screens/fir_record_screen.dart` | `GET /api/fir-records/<path:fir_no>` (`app.py:1722`) | — |
| FIR | Download PDF | Working (code); Supabase redirect **UNVERIFIED — requires source confirmation (live run)** | `fir_download_controller.dart`, `fir_remote_data_source.dart#downloadPdf`, `fir_pdf_store.dart` | `GET /fir/download/<fir_no>` → 302 to Supabase `pdf_url` (`app.py:2312-2324`) | `ApiEndpoints.firDownload` doc (`api_endpoints.dart:124-141`) still describes the old `generated_firs/` behaviour. Stale comment, no functional impact. |
| Case Mgmt (Complaints) | List / filter / search | Working | `complaints/presentation/screens/complaints_inbox_screen.dart`, `complaint_filter_controller.dart`, `domain/entities/complaint_filter.dart` | `GET /api/complaints/all` (`app.py:627`) | Endpoint has no auth (D1 S6). Filtering is client-side. |
| Case Mgmt | Complaint detail | Working | `complaints/presentation/screens/complaint_detail_screen.dart`, `complaint_providers.dart` | list cache, falling back to `GET /api/complaint/<id>` (`app.py:691`) | The fallback endpoint omits `phone`; handled in `ComplaintRepositoryImpl.update`. |
| Case Mgmt | Status update / respond | Working | `widgets/complaint_respond_sheet.dart`, `complaint_action_controller.dart#respond`, `complaint_write.dart`, `complaint_repository_impl.dart#update` | `PATCH /api/complaints/<id>` (`app.py:661`) | Sends the full `{status, fir_no, officer_notes}` triple. This is correct because the server nulls any omitted field. See **CMP-2** about citizen visibility of notes. |
| Case Mgmt | Escalate | **Partial** | `widgets/complaint_escalate_sheet.dart`, `complaint_action_controller.dart#escalate`, `domain/entities/escalation_desk.dart` | `PATCH /api/complaints/<id>` (the same endpoint) | **CMP-1**: there is no escalation workflow on the server. Escalation only appends a note line and sets `Under Review`. No desk is notified. |
| Case Mgmt | Link complaint → FIR (seed FIR form) | Working | `complaint_fir_link_controller.dart` (`seedFrom`) | `GET /api/complaint/<id>` (fallback) then `/generate_fir` | Inherits FIR-1. |
| Case Mgmt | Evidence: PIN gate | Working | `evidence/presentation/widgets/evidence_pin_gate.dart`, `evidence_lock_controller.dart` | `POST /verify-locker-access` (`app.py:2131`) | PIN is hard-coded server-side (D1 S2). The gate is cosmetic because the evidence endpoints have no auth. |
| Case Mgmt | Evidence: list | Working | `evidence/presentation/screens/evidence_locker_screen.dart`, `widgets/evidence_list_view.dart` | `GET /get-all-evidence` (`app.py:2241`), `GET /api/evidence?fir_no=` (`app.py:2198`) | — |
| Case Mgmt | Evidence: add (camera / gallery / file) | Working | `evidence/presentation/screens/evidence_add_screen.dart`, `evidence_upload_controller.dart`, `data/datasources/evidence_file_picker.dart` | `POST /upload-evidence` (`app.py:2147`; FIR existence checked in Supabase via `fir_exists`) | Same-name upload silently overwrites the file (server behaviour). |
| Case Mgmt | Evidence: detail / preview | Working | `evidence/presentation/screens/evidence_detail_screen.dart` | `GET /evidence-file/<fir>/<file>` (`app.py:2191`), `POST /api/evidence/log-access` (stub, `app.py:2235`) | Access log is discarded by the server stub. |
| Law | Library browse / act search | Working | `legal/presentation/screens/law_library_screen.dart`, `law_library_controller.dart` | `GET /api/sections/<act>` (`app.py:900`) | — |
| Law | Cross-act search | **Partial** | `law_library_screen.dart`, `legal_remote_data_source.dart#search` | `GET /api/search-sections?q=` (`app.py:1570`) | **LAW-1** (below). |
| Law | Section detail / compare | Working | `law_section_screen.dart`, `widgets/section_compare_sheet.dart` | `GET /api/section-detail/<act>/<no>` (`app.py:955`) | — |
| Law | Ask NyayaAI (RAG) | Working | `legal/presentation/screens/ask_law_screen.dart`, `legal_query_controllers.dart` | `POST /api/ask-law` (`app.py:1651`; `rag_engine.search_law`) | The answer is prose and is rendered as-is (correct). |
| Law | Which sections apply (outcome) | Working | `law_outcome_screen.dart` | `POST /api/predict-outcome` (`app.py:977`; reads `results`) | — |
| Law | Terms & new codes | Working (static data) | `law_reference_screen.dart`, `domain/entities/legal_reference.dart` | none (constants copied from `website/templates/index.html`) | **LAW-2**: hard-coded reference data that can drift from the website. Disclosed in code comments. |
| Missing Persons | Active cases + confirmed matches | Working | `missing_persons/presentation/screens/missing_persons_screen.dart`, `missing_person_providers.dart` | `GET /get_missing_persons` (`missing_person.py:138`), `GET /get_confirmed_matches` (`:388`) | — |
| Missing Persons | Register a case (photo) | Working | `missing_person_form_screen.dart`, `missing_person_form_controller.dart` | `POST /upload_missing_person` (`missing_person.py:176`) | **MP-1**: face-check behaviour depends on the server environment (below). |
| Missing Persons | Case detail + sightings | Working | `missing_person_detail_screen.dart` | `GET /get_sightings/<id>` (`missing_person.py:350`) | — |
| Missing Persons | Report sighting | Working | `widgets/report_sighting_sheet.dart` | `POST /report_sighting/<id>` (`missing_person.py:254`) | MP-1 applies. |
| Missing Persons | Mark found | Working | `missing_person_detail_screen.dart` (`setStatus`) | `POST /update_missing_person_status/<id>` (`missing_person.py:441`) | Resolved cases can no longer be listed (no endpoint returns them). |
| Profile | View | Partial | `dashboard/presentation/widgets/dashboard_cards.dart#IdentityCard` | — (cached `AuthUser`) | There is no profile screen. `features/profile/` is an empty scaffold. The identity card shows name, email, role and ID from the local cache. |
| Profile | Edit | Not built | — | none for police | No backend endpoint exists (only `/api/lawyer/profile` for lawyers). |
| Profile | Logout | Working | see Auth → Logout | `GET /logout` | — |

---

## Issues — reproduction, root cause, proposed minimal fix

### AUTH-1 — Signup with an already-registered email reports "Account created"
- **Reproduction:** Open Sign up → enter an email that already exists in `NyayaAI_DB.users` → valid password → Create.
- **Observed (from code):** The server returns **HTTP 200** `{"message": "If eligible, your account has been created."}` with **no `unique_id`** (`website/app.py:2004-2005`). The app treats any 2xx as success. `SignupResponse.fromJson` yields `uniqueId: ''` and `SignupScreen._showSuccess` shows **"Account created — Your … account is registered. Sign in with your email and password."** (`signup_screen.dart:111-171`). The next sign-in with the new password fails with "Invalid credentials".
- **Root cause:** The server returns an anti-enumeration response, but the client assumes 2xx means created.
- **Proposed minimal fix (client only):** In `SignupScreen._showSuccess`, when `assignedId` is empty, show the server's own neutral `message` ("If eligible, your account has been created. Sign in to continue.") instead of claiming creation. This requires `AuthRepository.signup` to return the message along with the ID. The server behaviour should be kept, because it prevents account enumeration.
- **Relevance to Citizen work:** Citizen registration uses this same screen and endpoint, so it should be fixed before Citizen sign-up is declared done.

### AUTH-2 — Client password rule is weaker than the server's
- **Reproduction:** Sign up with `password12` (10 characters, no uppercase or symbol), or with `Abcdef1!` (8 characters).
- **Observed:** `Validators.signupPassword` requires only 8 characters (`core/utils/validators.dart`). The server requires at least 10 characters plus uppercase, lowercase, a digit and a special character (`app.py:202-217`). The server's 400 message is shown in a `FormBanner`, so the flow is recoverable but costs a round trip per rule.
- **Root cause:** The server rule was tightened and the client validator was not updated. `Validators.newPassword` (12+ with complexity) exists but is unused and does not match the server either.
- **Proposed minimal fix:** Change `signupPassword` to mirror `validate_password` exactly (≥10, `[A-Z]`, `[a-z]`, `[0-9]`, `[^A-Za-z0-9]`). This is a one-function change.

### AUTH-3 — No handling of a session that expires while the app is open
- **Reproduction:** Sign in, keep the app open past 8 h (or clear the server `secret_key` / restart with a new key), then use **Suggest sections** or a missing-persons action.
- **Observed:** 401/403 from those endpoints appears as an inline error. The user is not returned to sign-in until the next cold start.
- **Root cause:** No global response hook calls `AuthController` on a session-expired signal, and the server has no refresh endpoint.
- **Proposed minimal fix (deferred; not a regression):** Add a small interceptor that, on 401 from a *session-gated* endpoint, calls `/api/me` and signs out locally if `logged_in:false`. Log it only; this was not applied in this phase.

### FIR-1 — `/generate_fir` now enforces validation the app does not mirror or display
- **Reproduction examples** (each passes the app's `FirDraft.missingIn` check and is rejected by the server):
  1. FIR number `41/2026` (the format the app's own comments use as the example, `core/utils/fir_number.dart`, `api_endpoints.dart:134-139`) → server: *"FIR number must start with 'FIR'"* (`FIR_NO_RE`, `app.py:219`).
  2. Type of information `Telephonic` (the field is free text with hint *"Written, oral, telephonic…"*, `steps/fir_occurrence_step.dart:172-183`) → server accepts only exactly `Written` or `Oral` (`app.py:294-296`).
  3. Narrative under 25 characters → server: *"Statement must be at least 25 characters."* (`app.py:223, 288-292`).
  4. Complainant name with digits or non-ASCII letters (for example a Devanagari name) → rejected by `NAME_RE` (`app.py:220, 282-286`).
  5. Occurrence date after the FIR date, or info-received date before the occurrence date (`app.py:258-275`).
  6. The live suite's `ZZFLUTTER…` FIR numbers (`test_live/fir_live_test.dart`) do not start with `FIR` → will be rejected. **UNVERIFIED — requires source confirmation (live run).**
- **Observed:** The server replies `400 {"error": "Validation failed", "details": [ …specific reasons… ]}` (`app.py:1793-1795`). `ErrorMapper.extractMessage` reads only the top-level `error` string, so the officer sees **"Validation failed"** with no reason.
- **Root cause:** Server-side validation (`validate_fir_data`) was added after the app's FIR feature. The client documentation still says *"400 FIR number already exists — the only rejection the handler makes"* (`api_endpoints.dart:42-57`), which is stale. The duplicate message is now `"FIR already exists"` (`app.py:1812`).
- **Proposed minimal fix (Police code, justified as a regression against the current server):**
  1. `ErrorMapper.extractMessage`: when the body has `details` as a list of strings, return them joined with a line break. This is shared code and also benefits Citizen features.
  2. Make *Type of information* a two-option picker (`Written` / `Oral`).
  3. Add the server's FIR-number, name, statement-length and date-order rules to `FirDraft.missingIn` so the problem is raised on the correct step.
  4. Update the stale doc comment and the `test_live` FIR-number prefix.

### CMP-1 — "Escalate" has no server-side effect beyond a note
- **Reproduction:** Complaint detail → Escalate → choose "Cyber Cell" → submit.
- **Observed:** `ComplaintActionController.escalate` PATCHes status `Under Review` and appends `"Escalated to Cyber Cell. Reason: …"` to `officer_notes`. Nothing routes the complaint to that desk: there is no desk, assignment or notification concept in `citizen_complaints` (`app.py:543-558`).
- **Root cause:** A backend gap. The UI wording implies routing that does not exist.
- **Proposed minimal fix:** Relabel the action as "Record escalation" (honest wording), or specify an escalation endpoint in D5. No code change in this phase.

### CMP-2 — Officer notes, including escalation reasons and officer names, are shown to the citizen
- **Observed:** The app writes notes as `[timestamp · Officer Name] text` (`complaint_note.dart#append`). The citizen tracking endpoint `GET /api/complaint/<id>` returns `officer_notes` verbatim (`app.py:697-719`). The website's citizen page displays it (`citizen_dashboard.html:896-899`), and the website's own police modal labels the field *"notes visible to the citizen"* (`index.html:1373`).
- **Risk:** Internal escalation reasons and officer names become visible to complainants. This is a product decision, not a crash.
- **Proposed minimal fix:** Decide in D5 whether to split `officer_notes` into `public_note` and `internal_notes`. Until then, the Citizen tracking screen will show the field exactly as the website does, and the police respond and escalate sheets should warn that the text is citizen-visible.

### LAW-1 — Cross-act search mixes unverified LLM output with database rows and can stall
- **Observed:** `/api/search-sections` appends results parsed from a local Ollama `phi3` completion (`app.py:1614-1648`). `ask_ollama` calls `requests.post` **with no timeout** (`app.py:50-62`), so if Ollama is up but slow the request can exceed the app's 30 s receive timeout. The AI rows can name acts outside `LEGAL_ACTS` (for example `BNS`) or sections that do not exist; opening one leads to `400 Invalid act` or `404 Section not found` from `/api/section-detail`.
- **Root cause:** Server design. The client cannot tell an AI row from a database row, because the response has no `source` field.
- **Proposed minimal fix:** The server should tag rows with `source` and add a timeout to `ask_ollama` (D5). The client should hide rows whose act is not in `/api/acts`.

### LAW-2 — Static legal reference data
- `legal_reference.dart` holds the glossary and the IPC→BNS mapping as constants copied from the website's JavaScript. There is no endpoint. This is disclosed in the file, but it will drift. D5 candidate: `GET /api/legal-reference`.

### MP-1 — Face-match results depend on the server environment and may be random
- **Observed:** `website/missing_person.py:11-33` replaces `compare_faces` with a function returning **`random.uniform(0.40, 0.92)`** if `face_recognition_helper` fails to import, and `face_recognition_helper.py` has its own "DEMO mode". `face_recognition`, `dlib` and `face_recognition_models` **are installed** in `website/venv/`. Whether they import at runtime is **UNVERIFIED — requires source confirmation (server start log line `[MissingPersons] face_recognition_helper loaded.`)**.
- **Risk:** If demo mode is active, sighting "matches" are fabricated, which conflicts with the brief's "no fake AI responses" rule for the Citizen sighting feature.
- **Proposed fix:** Confirm the server start log before building Citizen sightings. The server should refuse (503) rather than randomise when the library is missing (D5).

---

## Summary

| Status | Count |
|---|---|
| Working | 31 |
| Working, with live confirmation still UNVERIFIED | 1 (FIR PDF download) |
| Partial | 6 (Signup, Session refresh, Register FIR, Escalate, Cross-act search, Profile view) |
| Broken | 0 |
| Not built | 1 (Profile edit) |

No Police fix has been applied. The fixes proposed above that touch Police code (FIR-1 and AUTH-1/AUTH-2, which are shared with Citizen signup) need approval before Phase 7.

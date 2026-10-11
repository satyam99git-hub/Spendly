# D4 — Master Feature Inventory (Citizen)

> **Update 2026-09-20:** the website-parity directive (no backend or website changes) resolves open questions #1, #2, #3, #5, #6 and #9, and changes the Backend Status of rows 5, 9 and 10. See `D5P_citizen_parity_spec.md` §0. That document's parity matrix (P-1…P-20) is now the tracking artifact for Citizen work.

Every row traces to a Part B route block in **D3**. Backend status is cross-checked against the API layer in **D1 §3** and the Police audit in **D2**.

## Backend Status legend (as applied)

| Code | Meaning in this table |
|---|---|
| **A** | The endpoint exists and can be reused **without any server change**. The brief's definition also says "already used by Police/Flutter"; to avoid overstating that, the **"Flutter calls it today?"** column records it separately. Rows that need **no endpoint at all** (static content) are marked **A (none)**, because nothing has to exist or change server-side. |
| **B** | The endpoint exists but needs a server change: a defect fix, or a missing field, auth rule or ownership rule needed to meet the brief's Definition of Done. |
| **C** | The endpoint does not exist. It must be specified in D5 as new work. |

## Inventory

| # | Feature | Website Route | Components | API/Backend | Data Model | Flutter Screen (proposed) | Backend Status (A/B/C) | Priority |
|---|---|---|---|---|---|---|---|---|
| 1 | Citizen registration (role = citizen, server-generated `CIT###`) | `/signup` | `signup.html` (role buttons, name, email, password, **confirm password**) | `POST /signup` (app.py:1979). Flutter calls it today: **yes** (`AuthRemoteDataSource.signup`) | Mongo `users` → `SignupRequest` / `SignupResponse` | `features/authentication/presentation/screens/signup_screen.dart` (existing; add confirm-password field; fix D2 AUTH-1, AUTH-2) | **A**. Endpoint unchanged. Client fixes only: AUTH-1 (existing-email 200 without `unique_id`) and AUTH-2 (password ≥10 with complexity). | High |
| 2 | Citizen login | `/login` | `login.html` | `POST /login` (app.py:2052). Flutter today: **yes** | Mongo `users` + Flask session → `AuthUser` | `login_screen.dart` (existing, no change) | **A**. Already used for all roles. | High |
| 3 | Session restore + role landing (citizen → citizen home) | `/citizen_dashboard` → `/citizen-dashboard` (auth gate app.py:568-574) | server redirect; `/api/me` probe | `GET /api/me` (missing_person.py:116). Flutter today: **yes** | Session → `SessionResponse` / `AuthUser` | `features/dashboard/presentation/screens/role_home_screen.dart`: replace the citizen "COMING NEXT" list with **`citizen_home_screen.dart`** (new). Add a citizen route prefix to `app_router.dart` (see OQ-8). | **A** | High |
| 4 | Logout | `/logout` | sidebar and top-nav links | `GET /logout` (app.py:2114). Flutter today: **yes** | — | reuse `confirmSignOut()` (`dashboard_cards.dart`) | **A** | High |
| 5 | Forgot password | `/forgot-password` (link at `login.html:442`; **no route, returns 404**) | link only | **none exists** | none (`database/schema/password_reset.sql` is unused) | `forgot_password_screen.dart`: **TBD — see open question #6** | **C**. No handler, token store or email sender exists. | Low |
| 6 | Public landing / intro | `/` | `landing.html` (marketing, links to login/signup) | none. Flutter today: n/a | — | none. The existing `splash_screen.dart` + `login_screen.dart` cover entry. **TBD — see open question #10** | **A (none)** | Low |
| 7 | Citizen home (hero, 3 shortcut cards, 4 quick actions, emergency strip) | `/citizen-dashboard#home` | `citizen_dashboard.html` §home (lines 244-385) | none directly (quick actions go to #10) | — | **`features/dashboard/presentation/screens/citizen_home_screen.dart`** (new; reuses `IdentityCard`, `ActionCard`, `SectionHeading`) | **A (none)** | High |
| 8 | Emergency contacts (9 helplines with `tel:` dialling + 5 safety tips; also the 6-number home strip) | `/citizen-dashboard#emergency` | §emergency (lines 666-756); home strip (lines 356-382) | none. The content is static HTML | static list (no model on the website) | **`features/emergency/presentation/screens/emergency_contacts_screen.dart`** (new). Needs a `tel:` launcher dependency (`url_launcher`, not in `pubspec.yaml`): **see open question #1** | **A (none)**. Nothing on the server. Content source and the **108/102 Ambulance defect** are in open question #1. | Medium |
| 9 | File a complaint (form → tracking ID shown on success) | `/citizen-dashboard#file-complaint` | §file-complaint (lines 388-463), `submitComplaint()` (813-863) | `POST /api/complaint` (app.py:584). Flutter today: **no** | SQLite `citizen_complaints` → new `CitizenComplaintSubmission` / `ComplaintReceipt` (`{tracking_id, status, category, can_file_fir}`) | **`features/complaints/presentation/screens/citizen_complaint_form_screen.dart`** + success view (new) | **B**. Usable as-is for website parity. It cannot meet the DoD ownership rule because the handler has **no session check** and stores **no citizen `user_id`**, so a complaint cannot be tied to the citizen who filed it. See open question #2. The website's own submit is broken (D3: `c_phone` null); Flutter will implement the *intended* rules (name letters/spaces ≤60, phone exactly 10 digits if given, description required). | High |
| 10 | Know Your Rights: AI chat, 6 preset topics, 3 home quick actions | `/citizen-dashboard#know-rights` | §know-rights (lines 570-650), `askRightsQuestion()` (958-1016), `formatAnswer()` (936-953) | `POST /api/rights-chat` (app.py:724; RAG `rag_engine.search_law` + Groq `openai/gpt-oss-120b`, with template fallback). Flutter today: **no** | request `{question}` → response `{answer}` (plain text / light markdown). New `RightsAnswer` model. | **`features/legal/presentation/screens/rights_chat_screen.dart`** (new; beside the existing `ask_law_screen.dart`, reusing `LegalRemoteDataSource` patterns) | **B**. Defect: when RAG finds no section, `groq_prompt` is unbound (assigned inside the loop, app.py:758-772) and the fallback `build_keyword_fallback` is commented out (app.py:822-898), so the request returns **HTTP 500**. Must be fixed server-side before the "error state" can be distinguished from a real outage (D5). | High |
| 11 | Track complaint by tracking ID (details, status pill, 4-step timeline, FIR no., officer notes) | `/citizen-dashboard#track-complaint` | §track-complaint (lines 466-527), `trackComplaint()` (868-930) | `GET /api/complaint/<tracking_id>` (app.py:691). Flutter today: **yes** (`ComplaintRemoteDataSource.byTrackingId`, police fallback) | SQLite `citizen_complaints` → existing `Complaint` entity + `ComplaintStatus` (the same 4 statuses) | **`features/complaints/presentation/screens/citizen_track_complaint_screen.dart`** (new; reuses `ComplaintStatusChip`) | **A** for parity. The endpoint is capability-based: anyone holding the ID can read it, with no ownership check. This matches the website. Officer-notes exposure is in open question #3 (D2 CMP-2). | High |
| 12 | My Case Status (lawyer-shared FIR status, next hearing, lawyer note) | `/citizen-dashboard#case-status` | §case-status (lines 529-567), `checkCaseStatus()` (1073-1110) | `GET /api/case/<fir_no>/client-status` (app.py:2520; public; Supabase `firs`, gated by `visible_to_client`). Flutter today: **no** | new `CaseClientStatus` (`fir_no, status, next_hearing_date, client_note, client_note_updated_at`) | **`features/case_status/presentation/screens/case_status_screen.dart`** (new) | **A** for parity. Public by server design ("matches the citizen 'My Lawyer' lookup pattern"). There is no citizen↔FIR link. Hardening is listed under open question #2. | Medium |
| 13 | Missing persons: browse active cases (citizen view) | `/citizen-dashboard#missing-persons` (fragment `/missing_persons_template`; standalone `/missing_persons`) | `missing_persons_fragment.html` citizen tab (lines 226-250, 598-637) | `GET /get_missing_persons` (missing_person.py:138); `GET /api/me`; photos via `/static/uploads/missing_persons/*`. Flutter today: **yes** (police) | SQLite `missing_persons` → existing `MissingPerson` | **`features/missing_persons/presentation/screens/citizen_missing_persons_screen.dart`** (new; reuses `MissingPersonRepository` and `PersonPhoto`). **Client change:** `/missing-persons` is inside `AppRoutes.policePrefixes`, so a citizen route is needed (open question #8). | **A** | Medium |
| 14 | Missing persons: report a sighting (location, date, photo, then face-match result) | same as #13 (Report Sighting modal, fragment lines 279-339, 761-834) | modal + `mpSubmitSighting()` | `POST /report_sighting/<person_id>` (missing_person.py:254; any logged-in role; records `uploaded_by_citizen = user_id`). Flutter today: **yes** (police, `ReportSightingSheet`) | SQLite `missing_person_sightings` → existing `SightingResult` | reuse **`features/missing_persons/presentation/widgets/report_sighting_sheet.dart`** from the citizen screen (#13) | **A**, **conditional** on confirming the server is **not** in random-score demo mode (D2 MP-1). If it is, reclassify as **B** (server must return 503 instead of fabricating scores). See open question #4. | Medium |

**Row count: 14.** All 12 Citizen route blocks in D3 Part B are covered. So are the ✅ rows of the D3 route inventory that have no block of their own (`/citizen_dashboard`, `/citizen-dashboard`, `/api/me`, `/static/...`):

| D3 route block | D4 row(s) |
|---|---|
| `/` | 6 |
| `/signup` | 1 |
| `/login` | 2 |
| `/logout` | 4 |
| `#home` | 7, and 8 (emergency strip) |
| `#file-complaint` | 9 |
| `#track-complaint` | 11 |
| `#case-status` | 12 |
| `#know-rights` | 10 |
| `#missing-persons` + `/missing_persons` + `/missing_persons_template` + `/static/...` | 13, 14 |
| `#emergency` | 8 |
| `/forgot-password` | 5 |
| `/citizen_dashboard` + `/citizen-dashboard` + `/api/me` | 3 |

**Deliberately not rows.** These have no website source, so adding them would break the rule against inventing features:
- a "My complaints" history list
- citizen profile view/edit
- notifications
- complaint attachments

Each is raised as an open question below where it affects the DoD.

---

## Open questions (must be answered before D5/D6)

1. **Static content (rows 7, 8).**
   - The website hard-codes the helplines, safety tips and preset rights questions in HTML, and there is no endpoint.
   - The brief forbids "hardcoded data". The existing app's precedent is `legal_reference.dart`, which transcribes the website's constants verbatim and discloses that it does.
   - **Decide:** (a) transcribe verbatim with a source comment, or (b) specify `GET /api/emergency-contacts` in D5.
   - Also decide the Ambulance entry: the website shows **108** but dials **`tel:102`** (`citizen_dashboard.html:686-687`).
   - Also approve adding `url_launcher` for `tel:` links.
2. **Complaint ownership (rows 9, 11, 12).**
   - `POST /api/complaint`, `GET /api/complaint/<id>` and `GET /api/case/<fir>/client-status` have no session or ownership checks, and complaints store no citizen ID.
   - **Decide:** (a) website parity now, with complaints anonymous and tracking by ID as the only capability; or (b) D5 server change: require a citizen session on file, store `citizen_user_id`, and add `GET /api/citizen/complaints` for a "My complaints" list.
   - Option (a) cannot satisfy the DoD line "citizen cannot access another citizen's data", because anyone with a tracking ID can read that complaint.
3. **Officer notes shown to citizens** (row 11; D2 CMP-2). Show `officer_notes` verbatim as the website does, or wait for a server split into public and internal notes?
4. **Face-match mode** (row 14; D2 MP-1). Confirm from the Flask start-up log that `face_recognition_helper` loads, and that sightings are not scored by `random.uniform`.
5. **Server-side fixes ownership** (rows 10 and 9). Is changing `website/app.py` in scope for this project? Examples: the rights-chat 500, and the website's own broken complaint form (`c_phone`). If not, row 10 must ship with a "service unavailable" error state for questions that get no RAG match.
6. **Forgot password** (row 5). Build a reset backend (C) or drop the link from the app? There is no email infrastructure in `website/`.
7. **Shared auth fixes** (row 1). AUTH-1 and AUTH-2 change code shared with Police sign-up (`signup_screen.dart`, `validators.dart`). Approve this as a justified change to working Police code.
8. **Citizen routing.** Proposed: a new `AppRoutes.citizenPrefixes` (for example `/citizen/...`) guarded to `role == citizen`, keeping `/missing-persons` police-only. Alternatively, move missing-persons browsing out of `policePrefixes`.
9. **Citizen home layout** (row 7). A tabbed shell like `PoliceDashboardScreen` (for example Home / Complaints / Rights / More), or a single scroll of `ActionCard`s like the website sidebar?
10. **Landing page** (row 6). Confirm it is out of scope for the app (splash + sign-in already serve as entry).
11. **Folder placement.** Proposed: citizen screens go inside existing features where the domain already exists (`complaints`, `missing_persons`, `legal`, `dashboard`), and new features only for `emergency` and `case_status`. Confirm this, or prefer a single `features/citizen/` folder.

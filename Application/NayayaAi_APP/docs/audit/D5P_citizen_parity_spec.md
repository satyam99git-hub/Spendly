# D5-P — Citizen Website → Flutter Parity Specification

**Status:** pre-implementation. No Citizen code has been written.
**Governing directive (2026-09-20):** **website = source of truth**. Reproduce the website's Citizen functionality natively in Flutter. **Do not modify** the website, backend, Flask routes, database logic or templates. Anything the backend cannot support is recorded as a **limitation** (§4), never worked around silently.
**Sources:** `website/templates/citizen_dashboard.html` (CD), `website/templates/missing_persons_fragment.html` (MPF), `website/templates/login.html`, `website/templates/signup.html`, `website/app.py`, `website/missing_person.py`. Line numbers are as of 2026-09-20.

---

## 0. Effect of the directive on D4

| D4 item | Before | After the directive |
|---|---|---|
| OQ-2 complaint ownership | open | **Resolved: website parity.** Complaints stay anonymous and are tracked by ID only. The DoD ownership gap is recorded as limitation **L1**. |
| OQ-3 officer notes | open | **Resolved:** shown verbatim, as the website does (**L5**). |
| OQ-5 server fixes | open | **Resolved: none allowed.** The rights-chat 500 becomes limitation **L2**. |
| OQ-1 static content | open | **Resolved:** reproduce the website's static text verbatim. The Ambulance number is still open (**D-2**). |
| OQ-6 forgot password | C | **Not implementable** (no backend). Limitation **L3**. |
| OQ-9 home layout | open | **Resolved by parity:** mirror the website's sidebar with a Drawer holding the same 7 sections (§2, P-5). |
| D4 row 9 (File complaint) | B | **A as-is**, with limitation L1 |
| D4 row 10 (Rights chat) | B | **A as-is**, with limitation L2 |
| D4 row 5 (Forgot password) | C | **Limitation L3.** No Flutter feature. |

D5 as originally briefed (backend gap specs) no longer applies because backend work is out of scope. Its role is taken by the limitation records in §4.

---

## 1. Exhaustive Citizen-visible feature inventory

The directive's list was 15 items plus "any other". Inspecting the source found **5 more** Citizen-visible features (marked ➕). None are invented; each cites its website source.

| # | Feature | In directive list? | Website source |
|---|---|---|---|
| P-1 | Citizen Registration | 1 | `signup.html` 354-530; `POST /signup` app.py:1979 |
| P-2 | Citizen Login | 2 | `login.html` 424-513; `POST /login` app.py:2052 |
| P-3 | Session Restoration | 3 | Flask session (app.py:2088-2094, 8 h); `/` redirect by role (app.py:502-513) |
| P-4 | Citizen Role Routing | 4 | `/citizen_dashboard` → `/citizen-dashboard` role gate (app.py:568-574, 2110-2112); `login.html:490-492` |
| P-5 | ➕ Citizen navigation shell (sidebar with 7 sections, top bar with "Citizen" badge and Sign out, mobile menu button) | — | CD 168-241, 766-806 |
| P-6 | Citizen Home / Dashboard (hero, 3 shortcut cards) | 5 | CD 244-320 |
| P-7 | ➕ Home Quick Actions (3 preset rights questions + Missing Persons) | — | CD 322-353 |
| P-8 | ➕ Home Emergency strip (6 dial buttons) | — | CD 355-382 |
| P-9 | Logout | 6 | CD 216, 238; `GET /logout` app.py:2114 |
| P-10 | Emergency Contacts (9 cards) + ➕ Safety Tips | 7 | CD 666-756 |
| P-11 | File a Complaint | 8 | CD 388-463, 813-863; `POST /api/complaint` app.py:584 |
| P-12 | Complaint Submission Success | 9 | CD 399-412, 853-856 |
| P-13 | Track Complaint (+ Status Timeline) | 10 | CD 466-527, 868-930; `GET /api/complaint/<id>` app.py:691 |
| P-14 | Know Your Rights AI (chat + 6 topic cards) | 11 | CD 570-650, 936-1016; `POST /api/rights-chat` app.py:724 |
| P-15 | My Case Status | 12 | CD 529-567, 1054-1110; `GET /api/case/<fir>/client-status` app.py:2520 |
| P-16 | Missing Persons (list, header, "How it works" banner, login-required / empty / error states) | 13 | MPF 1-68, 226-250, 401-445, 598-637; `GET /api/me`, `GET /get_missing_persons` |
| P-17 | Missing Person Details | 14 | **No separate view exists on the website.** Details are the card content (MPF 608-629). See the P-17 checklist. |
| P-18 | Report Missing Person Sighting (+ face-match result) | 15 | MPF 279-339, 761-834; `POST /report_sighting/<id>` missing_person.py:254 |
| P-19 | ➕ "Forgot password?" link | — | `login.html:442`. **Dead link with no route**, so limitation L3. |
| P-20 | ➕ Public landing page | — | `landing.html` via `/` (app.py:513). Shared by all roles before sign-in. See decision **D-4**. |

Checked and **confirmed absent** from the website Citizen experience, so **not** to be built: a "My complaints" history list, citizen profile view/edit, notifications, complaint attachments, complaint editing or withdrawal, sighting history for citizens, and confirmed-match views for citizens (police-only, MPF 447-452).

---

## 2. Website → Flutter parity matrix

API chain notation: `endpoint → Flutter data source/repository → screen`. "Existing" means the class already exists and is used unchanged. "New" means an additive file. No Police data source is modified.

| # | Website Feature | Website Location | API | Flutter repository / service → screen | Status |
|---|---|---|---|---|---|
| P-1 | Registration | `/signup` | `POST /signup` | existing `AuthRemoteDataSource.signup` → `AuthRepository` → `signup_screen.dart` (existing, **shared with Police**; parity gaps listed in the checklist) | Implemented — awaiting on-device run (see §7) |
| P-2 | Login | `/login` | `POST /login` | existing `AuthRemoteDataSource.login` → `login_screen.dart` (existing, shared) | Implemented — awaiting on-device run (see §7) |
| P-3 | Session restoration | Flask session cookie | `GET /api/me` | existing `AuthRepositoryImpl.restoreSession` → `AuthController` | Implemented — awaiting on-device run (see §7) |
| P-4 | Citizen role routing | `/citizen-dashboard` gate | — | `app_router.dart`: **new** `AppRoutes.citizenPrefix` guard (role == citizen); `role_home_screen.dart` citizen branch → new `CitizenShell` | Implemented — awaiting on-device run (see §7) |
| P-5 | Navigation shell | CD sidebar + top nav | — | **new** `features/citizen/presentation/citizen_shell.dart` (Drawer with the same 7 entries + Sign Out; app bar "NyayaAI" + "Citizen" badge + Sign out) | Implemented — awaiting on-device run (see §7) |
| P-6 | Home | CD `#home` | — | **new** `citizen_home_screen.dart` | Implemented — awaiting on-device run (see §7) |
| P-7 | Home quick actions | CD 328-351 | `POST /api/rights-chat` (via P-14) | P-6 screen → P-14 controller | Implemented — awaiting on-device run (see §7) |
| P-8 | Home emergency strip | CD 356-382 | — (`tel:`) | P-6 screen; `url_launcher` (**new dependency**, D-5) | Implemented — awaiting on-device run (see §7) |
| P-9 | Logout | CD 216, 238 | `GET /logout` | existing `AuthController.logout` | Implemented — awaiting on-device run (see §7) |
| P-10 | Emergency Contacts + Safety Tips | CD `#emergency` | — (`tel:`) | **new** `emergency_contacts_screen.dart`; content constants transcribed from CD with source comment | Implemented — awaiting on-device run (see §7) |
| P-11 | File a Complaint | CD `#file-complaint` | `POST /api/complaint` | **new** `CitizenComplaintRemoteDataSource.file` → **new** `CitizenComplaintRepository` → **new** `citizen_complaint_form_screen.dart` | Implemented — awaiting on-device run (see §7) |
| P-12 | Submission success | CD 399-412 | (response of P-11) | same screen, success state | Implemented — awaiting on-device run (see §7) |
| P-13 | Track Complaint | CD `#track-complaint` | `GET /api/complaint/<id>` | **new** `CitizenComplaintRemoteDataSource.track` (reuses the existing `ComplaintResponse.fromJson`, so the Police data source is untouched and the website's error strings are kept) → `CitizenComplaintRepository.track` → **new** `citizen_track_complaint_screen.dart` | Implemented — awaiting on-device run (see §7) |
| P-14 | Know Your Rights AI | CD `#know-rights` | `POST /api/rights-chat` | **new** `RightsChatRemoteDataSource` → **new** `RightsChatRepository` → **new** `rights_chat_screen.dart` | Implemented — awaiting on-device run (see §7) |
| P-15 | My Case Status | CD `#case-status` | `GET /api/case/<fir>/client-status` | **new** `CaseStatusRemoteDataSource` → **new** `CaseStatusRepository` → **new** `case_status_screen.dart` | Implemented — awaiting on-device run (see §7) |
| P-16 | Missing Persons list | CD `#missing-persons` / MPF | `GET /api/me`, `GET /get_missing_persons`, `/static/uploads/missing_persons/*` | existing `MissingPersonRepository.all` (unchanged) + existing `PersonPhoto` → **new** `citizen_missing_persons_screen.dart` | Implemented — awaiting on-device run (see §7) |
| P-17 | Missing Person Details | MPF card | (list data only) | **new** `citizen_missing_person_detail_screen.dart`, showing exactly the card fields | Implemented — awaiting on-device run (see §7) |
| P-18 | Report Sighting | MPF modal | `POST /report_sighting/<id>` | existing `MissingPersonRepository.reportSighting` (unchanged) → **new** citizen sighting sheet using the website's labels (the Police `ReportSightingSheet` is left untouched) | Implemented — awaiting on-device run (see §7) |
| P-19 | Forgot password link | `login.html:442` | none (404) | none | **Limitation L3** |
| P-20 | Public landing page | `/` | none | none proposed | **Decision D-4** |

**New endpoints created: none.** Every API above is an existing website endpoint called with the website's request format.

---

## 3. Per-feature parity checklists

Quoted strings are copied from the website source and are to be reproduced verbatim unless a decision says otherwise.

### P-1 Registration (`signup.html`, `POST /signup`)
| Aspect | Website | Flutter today (`signup_screen.dart`) | Parity action |
|---|---|---|---|
| Heading | "Create Account" / "Join us today — it only takes a minute." | "Create account" / "Register for access to NyayaAI services." | Shared with Police: decision **D-3** |
| Role picker | 4 buttons: Police, Citizen, Lawyer, Judge, under "Select your role". **None preselected** (hidden `<select>` starts at `""`). | `RoleSelector`, Citizen preselected | Keep the preselect (mobile adaptation; the website with no role silently blocks submit) → D-3 |
| Unique ID | Shown only for police/lawyer/judge; placeholder "POLxxx / LAWxxx / JUDxxx"; hint "Police: POLxxx · Lawyer: LAWxxx · Judge: JUDxxx" | Shown only for professional roles | ✅ functionally equal |
| Fields | Full Name, Email Address, Password, **Confirm** | Full name, Email, Password (**no confirm**) | **Add Confirm password** + "Passwords do not match" |
| Strength meter | 4 bars: len ≥6, len ≥10, upper+digit, special → weak/medium/strong. **Non-blocking.** | none | **Add a non-blocking 4-bar meter** with the same rules |
| Client validation | HTML `required`, `type=email`, confirm match | name 2–80, email regex, password ≥8 | Exceeds the website (allowed by DoD). Server remains authoritative. |
| Payload | `{fullname, email, password, role, unique_id}` | same keys (`unique_id` omitted for citizen) | ✅ server ignores `unique_id` for citizen (app.py:2025-2026) |
| Success | Shows `message` + "Your Unique ID: X", then redirects to `/login` after 2 s | Dialog with the ID, then pops to sign-in | Equivalent. Mobile keeps a tap-to-dismiss dialog so the ID is not lost → D-3 |
| Existing email | 200 `{message}` with no ID; the website shows "Your Unique ID: undefined" | Shows "Account created" (D2 AUTH-1) | **Show the server `message`; omit the ID line** |
| Errors | `result.error` in red; network: "An error occurred. Please try again." | `FormBanner(failure.message)`; `NetworkFailure` text | ✅ equivalent (server text shown verbatim) |

### P-2 Login (`login.html`, `POST /login`)
| Aspect | Website | Flutter today | Parity action |
|---|---|---|---|
| Heading | "Welcome Back" / "Sign in to continue to your account." | "Sign in" / "Authorised access only. Activity is logged." | Shared → D-3 |
| Fields | Email Address, Password | same | ✅ |
| Empty check | "Please fill in all fields." | per-field validators | ✅ equivalent |
| Submit | "Sign In" button or Enter | button or keyboard done | ✅ |
| Success | Green `message` ("Login successful"), then redirect after 1.2 s by role; citizen → `/citizen_dashboard` | Router redirect on auth state → `/home` → role branch (P-4) | ✅ equivalent |
| Errors | `data.error` (401 "Invalid credentials", 423 lock-out, 400); network: "An error occurred. Please try again." | `FormBanner(server text)` | ✅ |
| Forgot password | Link to a non-existent route | none | **L3**: do not add |
| Sign-up link | "Don't have an account? Create one" | "New to NyayaAI? Create an account" | Shared → D-3 |

### P-3 Session restoration
Website: the server-side session cookie (permanent, 8 h) and `/` redirect a signed-in citizen to the dashboard. Flutter: the persisted cookie jar + `GET /api/me` on cold start (existing). ✅ Equivalent; verify only. Limitation **L9** (no refresh; the session ends after 8 h).

### P-4 Citizen role routing
Website: `/citizen-dashboard` requires a session (else `/login`) and `role == 'citizen'` (else `/`). Flutter plan:
- a new `citizenPrefix` (for example `/citizen/...`), guarded to `role == citizen`, redirects to `/home` otherwise;
- `/home` renders `CitizenShell` for citizens.

The Police guard and routes are unchanged. `/missing-persons` stays police-only; the citizen gets `/citizen/missing-persons`.

### P-5 Navigation shell (CD 168-241)
| Website | Flutter |
|---|---|
| Sidebar title "NyayaAI", subtitle "Citizen Portal" | Drawer header, same text |
| Entries in order: Home, File a Complaint, Track Complaint, My Case Status, Know Your Rights, Missing Persons, Emergency Contacts | Drawer items, same order and labels; active item highlighted |
| Footer "Sign Out" | Drawer footer "Sign Out" |
| Top bar: "NyayaAI" + "Citizen" pill + "Sign out" | AppBar: "NyayaAI" + "Citizen" chip + sign-out icon (tooltip "Sign out") |
| Mobile menu button toggles the sidebar | AppBar menu icon opens the Drawer |
| Default section: Home (`showSection('home')`) | Initial destination: Home |

### P-6 Home (CD 244-320)
- Badge: "Powered by NyayaAI · Citizen Portal"
- Heading: "Justice, at your fingertips."
- Body: "File complaints, track their real-time status, and know your legal rights — all from one secure portal."
- Buttons: "File a Complaint" → P-11; "Track My Complaint" → P-13
- Cards:
  - "FILE COMPLAINT" / "Simple 2-min form" / "Instant tracking ID" → P-11
  - "TRACK STATUS" / "Real-time updates" / "4-stage timeline" → P-13
  - "KNOW YOUR RIGHTS" / "AI-powered help" / "Indian law, plain language" → P-14
- The website shows **no user data** on Home, so Flutter shows none. The existing `IdentityCard` is **not** added (it would add information the website does not show).

### P-7 Home quick actions (CD 322-353)
Heading "Quick Actions". Each item asks a question and then opens Know Your Rights:
- "Arrest Rights" → asks `What are my rights when I am arrested?`
- "FIR Refused?" → asks `What to do if police refuses to file my FIR?`
- "Free Legal Aid" → asks `What is free legal aid and how to get it in India?`
- "Missing Persons" → opens P-16

### P-8 Home emergency strip (CD 356-382)
Header "Emergency Contacts", right label "Available 24×7". Buttons dial with `tel:`: "Police 100", "Women 1091", "Emergency 112", "Cyber 1930", "Child 1098", "Legal Aid 15100".

### P-9 Logout
Website: "Sign Out" / "Sign out" link → `GET /logout` → `session.clear()` → landing page. **No confirmation.** Flutter: `AuthController.logout()` (clears the server session, cookie and cache) → router → login. Confirmation dialog: decision **D-4**.

### P-10 Emergency Contacts + Safety Tips (CD 666-756)
Heading "Emergency Contacts", sub "One tap to call. Available 24×7 across India." Nine cards (number / title / description, "Tap to call"):

| Number | Title | Description |
|---|---|---|
| 100 | Police | All-purpose police emergency |
| 112 | National Emergency | Police + Ambulance + Fire combined |
| 108 ⚠️ | Ambulance | Medical emergency, free transport |
| 101 | Fire Brigade | Fire and rescue operations |
| 1091 | Women Helpline | Harassment, domestic violence, assault |
| 1930 | Cyber Crime | Online fraud, hacking, digital crime |
| 1098 | Child Helpline | Child abuse, missing children |
| 14567 | Senior Citizen | Elder abuse, elder helpline |
| 15100 | Legal Aid | Free legal advice from NALSA |

⚠️ The Ambulance card displays **108** but its link dials **`tel:102`** (CD 686-687). Decision **D-2**.

"Safety Tips" (5 lines, verbatim):
1. "Save these numbers in your phone now, before an emergency."
2. "You can file a cyber crime complaint online at cybercrime.gov.in"
3. "You have the right to a free lawyer if you cannot afford one — just ask the court."
4. "Police must give you a copy of your FIR for free within 7 days of filing."
5. "A woman cannot be arrested after sunset and before sunrise without a female officer present."

### P-11 File a Complaint (`POST /api/complaint`)
| Aspect | Website | Flutter plan |
|---|---|---|
| Header | "File a Complaint" / "Your complaint will be reviewed by an officer. You'll receive a tracking ID instantly." | same |
| Full name | "Your Full Name *", placeholder "Enter your full name", maxlength 60, input stripped to `[A-Za-z ]` | same (input formatter + 60 limit) |
| Phone | Label "Phone Number". Intended rule: optional; if given, exactly 10 digits, error "Phone number must be exactly 10 digits." **Defect:** the input's id is `profile-years`, `type=number`, 2-digit cap. | Decision **D-1** |
| Date | "Date of Incident", `<input type=date>`, optional, no min/max, sent as `yyyy-MM-dd` or `""` | Date picker, optional, sent as `yyyy-MM-dd` or `""`. The picker's range will not add a future-date restriction the website does not have. |
| Location | "Location / Area", placeholder "Area, locality", optional | same |
| Description | "Describe the Incident *", placeholder "Describe what happened in your own words. Include who was involved, what happened, and any witnesses." | same |
| Notice | "This complaint is not an official FIR. A police officer will review it and may convert it to an official FIR if applicable." | same |
| Validation messages | "Name and incident description are required." / "Name should only contain letters and spaces." / "Phone number must be exactly 10 digits." | same texts |
| Request | JSON `{full_name, phone, incident_date, location, incident_description}` (trimmed) | identical keys and values |
| Loading | Button disabled, "Submitting…" | same |
| Errors | `data.error` or "Submission failed."; network "Network error. Please try again." | server text via the failure; network text as the website's |
| Not shown | `category`, `can_file_fir` (returned, never displayed) | **not displayed** |

### P-12 Submission success (CD 399-412)
- "Complaint Filed Successfully!"
- "Your tracking ID is:" followed by the ID (monospace)
- "Save this ID to track your complaint status"
- Button "Track My Complaint →" opens Track. The website does **not** pre-fill the ID, so Flutter will not either unless approved.
- The form stays hidden after success, and the website offers no "file another" action. Flutter will mirror this for the screen instance; navigating back to the section resets the form, as a page reload does on the website.
- Text selection/copy of the ID: SelectableText is a platform affordance, not a new capability.

### P-13 Track Complaint (`GET /api/complaint/<id>`)
- Heading "Track Your Complaint", sub "Enter your tracking ID to see the current status."
- Input placeholder "e.g. CMP-A1B2C3D4", forced to uppercase; Enter or the "Track" button submits.
- Empty input: "Please enter your tracking ID."
- Result fields:
  - "Tracking ID"
  - status pill: Pending, Under Review, FIR Filed or Closed, each with its own colour
  - "Name"
  - "Incident Date" (or "Not specified")
  - "Location" (or "Not specified")
  - "Filed On" (`created_at` as a date, en-IN long format, for example "20 September 2026")
  - "FIR Number" only if present
  - "Officer Notes" only if present (italic, verbatim; **L5**)
- **Not shown by the website, so not shown in Flutter:** `incident_description`, `category`, `is_cognizable`, `updated_at`.
- "Status Timeline", 4 steps with descriptions: Pending "Complaint received", Under Review "Officer reviewing details", FIR Filed "FIR registered with police", Closed "Case closed". Steps up to the current index are filled; steps before it show a check. An unknown status highlights no step.
- Errors: `data.error` (404 "Complaint not found. Check your tracking ID.") or "Complaint not found."; network "Network error. Please try again."
- The previous result is hidden while a new search runs.
- Loading: the website shows none. Flutter shows a button spinner as a mobile adaptation (no new information).

### P-14 Know Your Rights AI (`POST /api/rights-chat`)
- Header "Know Your Rights", sub "Ask anything about your legal rights in plain language. Powered by AI + Indian Law DB."
- Six topic cards (title / subtitle → question):

| Title | Subtitle | Question sent |
|---|---|---|
| If You Are Arrested | Right to bail, lawyer, silence | `What are my rights when I am arrested?` |
| Right to Bail | Bailable vs non-bailable | `What is my right to bail under Indian law?` |
| Right to Lawyer | Free legal aid, when to call | `What is the right to a lawyer when arrested in India?` |
| FIR Refused? | Steps if police won't register | `What to do if police refuses to file my FIR?` |
| Women's Rights | POCSO, domestic violence | `Rights of women under Indian law when filing a complaint` |
| Free Legal Aid | Who qualifies, how to apply | `What is free legal aid and how to get it in India?` |

- Opening bot message: "Hello! I'm here to help you understand your legal rights under Indian law. Ask me anything — or click one of the topics above to get started."
- Input placeholder "Ask about your rights…"; button "Ask"; Enter submits; empty input is ignored.
- Flow: the user bubble is appended, then a "Thinking…" bubble, which is replaced by the answer. The chat history is in memory only and is lost on reload, the same as the website.
- Response handling: display `answer` **whatever the HTTP status** (the website does not check `res.ok`, so a 400 `{answer}` is shown as an answer). Formatting matches `formatAnswer`: `**bold**`, lines starting with `-` or `•` become bullets, newlines are kept.
- Failure: a non-JSON body or network error shows "Could not connect. Check your server is running and try again." This includes the known 500 (**L2**).

### P-15 My Case Status (`GET /api/case/<fir>/client-status`)
- Heading "My Case Status", sub "Enter your FIR number to see the status your lawyer has shared."
- Placeholder "e.g. FIR0009"; "Check" or Enter; empty input does nothing.
- Request: the FIR number is URL-encoded.
- Result: FIR number; status pill (`status`, or "Active" if empty); "Next Hearing" (value or "Not scheduled"); "Note from your lawyer" only if `client_note` is present, with relative time:
  - "just now"
  - "Updated N min ago"
  - "Updated N hr(s) ago"
  - "Updated N day(s) ago"
  - otherwise "Updated on <d MMM yyyy>" (browser `en-IN` short month)
- Errors: amber box with `data.error` (404 "Status not available for this FIR") or "Your lawyer hasn't shared this case's status yet."; network "Network error. Please try again."

### P-16 Missing Persons list (MPF)
- Header: "Missing Persons" / "AI face recognition · Community sightings · Real-time matching"; role badge "Citizen".
- Login-required state ("Login Required" / "Please sign in to access the Missing Persons feature."): unreachable in Flutter, because citizen routes need a session. Equivalent behaviour comes from the router guard.
- Citizen sees only the "Citizen Reports" view. The Police Dashboard and Confirmed Matches tabs are not offered.
- Banner "How it works": "If you've seen someone below, click **Report Sighting** and upload a photo — our AI compares faces in seconds and notifies the investigating officer." Reproduced verbatim per the static-content rule. ⚠️ The backend sends no notification (it only stores the sighting), so the text overstates it. Flagged, not changed.
- Card fields:
  - photo (fallback: a local "No Photo" placeholder, since the website uses an external placehold.co image)
  - "MISSING" badge
  - "Last seen <last_seen_date>" if present
  - name
  - "Age: N" and " · <gender>" if present
  - location if present
  - description if present (2-line clamp)
  - button "Report Sighting"
- Order: as returned (newest first). Only `status='Missing'`.
- Empty state: "All clear — no active cases" / "Thank you for checking. Every visit matters."
- Error: "Error loading data."
- Loading: spinner with "Loading…".

### P-17 Missing Person Details
The website has **no detail view**. Everything it shows about a person is on the card (P-16). The Flutter detail screen is a mobile adaptation that shows **exactly those fields**, with the description unclamped, plus the same single action "Report Sighting". It does **not** show sightings, match scores, `created_at`, `status` or `person_id`, because the website shows none of these to citizens. Approval of this adaptation is part of decision **D-4**. The alternative is card-only, with no detail screen.

### P-18 Report Sighting (`POST /report_sighting/<person_id>`)
- Title "Report Sighting", sub "For: <name>".
- Fields:
  - "Location *", placeholder "Where did you see this person?"
  - "Date *", defaults to today
  - "Photo *": "Click to upload photo", "JPG · PNG · WEBP"; accepts jpeg/png/webp/gif; preview shown
  - Mobile: camera or gallery via the existing picker
- Buttons "Cancel" / "Submit Sighting"; while sending: "Analysing face…", disabled.
- Client checks, in order: "Please enter a location." / "Please select a date." / "Please upload a photo."
- Request: multipart `{location, sighting_date (yyyy-MM-dd), photo}`, exactly as the website sends.
- Success, match: "✓ Match Confirmed!", "Confidence: N%" (`round(score×100)`), `details`, "This sighting is now logged in Confirmed Matches."; the sheet auto-closes after 2 s and the list reloads.
- Success, no match: "Sighting Recorded", "Confidence: N%", `details`, "Thank you for reporting. Every sighting helps."; the sheet stays open.
- Error: the server `error` (400 no face / bad file / no location, 401, 404 "Record not found or already resolved.") or "An error occurred."; network "Network error — please try again."
- Limitation **L4** applies.

---

## 4. Backend limitations (NO SILENT CHANGES)

**L1 — Complaint ownership**
- FEATURE: P-11, P-13.
- WEBSITE BEHAVIOR: Anonymous complaint; anyone holding a tracking ID can view it.
- AVAILABLE BACKEND SUPPORT: `POST /api/complaint` and `GET /api/complaint/<id>` have no session check, and no citizen ID is stored.
- FLUTTER IMPLEMENTATION: Identical. No "My complaints" list is invented.
- LIMITATION: The brief's DoD line "citizen cannot access another citizen's data" cannot be enforced for complaints. The app itself never lists or fetches another citizen's complaint; only a known ID is looked up.

**L2 — Rights chat 500** *(live status 2026-09-20: latent — not reproduced; see §7.3)*
- FEATURE: P-14.
- WEBSITE BEHAVIOR: Questions with no RAG match hit an unbound `groq_prompt` and an undefined `build_keyword_fallback` (app.py:758-789), giving HTTP 500. The website shows "Could not connect…".
- AVAILABLE BACKEND SUPPORT: The endpoint works only for greetings and questions that match a section.
- FLUTTER IMPLEMENTATION: Shows the same message as the website.
- LIMITATION: A server fault is indistinguishable from an outage in the UI. The fix belongs to the website team.

**L3 — Forgot password**
- FEATURE: P-19.
- WEBSITE BEHAVIOR: The link returns 404.
- AVAILABLE BACKEND SUPPORT: No route, token store or email.
- FLUTTER IMPLEMENTATION: None; a dead link is not reproduced.
- LIMITATION: Citizens cannot reset a password on either client.

**L4 — Face match mode** *(live status 2026-09-20: the server log shows `[MissingPersons] face_recognition_helper loaded.`, so matching was real on this machine; see §7.3)*
- FEATURE: P-18.
- WEBSITE BEHAVIOR: Shows the server's match result.
- AVAILABLE BACKEND SUPPORT: Real `face_recognition` if it imports; otherwise `random.uniform` scores (missing_person.py:18-33).
- FLUTTER IMPLEMENTATION: Displays the server result verbatim.
- LIMITATION: The client cannot detect demo mode. The server start log must show `[MissingPersons] face_recognition_helper loaded.` before this feature is manually tested.

**L5 — Officer notes**
- FEATURE: P-13.
- WEBSITE BEHAVIOR: Shows `officer_notes` verbatim.
- AVAILABLE BACKEND SUPPORT: A single field that also holds internal notes written by the Police app (officer names, escalation reasons).
- FLUTTER IMPLEMENTATION: Shows it verbatim.
- LIMITATION: Internal police text is citizen-visible (D2 CMP-2).

**L6 — Case status linkage**
- FEATURE: P-15.
- WEBSITE BEHAVIOR: Public lookup by FIR number.
- AVAILABLE BACKEND SUPPORT: No citizen↔FIR link; gated only by the lawyer's `visible_to_client`.
- FLUTTER IMPLEMENTATION: Identical.
- LIMITATION: No ownership check.

**L7 — Complaint auto-category**
- FEATURE: P-11.
- WEBSITE BEHAVIOR: The server returns `category` and `can_file_fir`; the website does not display them.
- AVAILABLE BACKEND SUPPORT: Returned in the 201 response.
- FLUTTER IMPLEMENTATION: Not displayed.
- LIMITATION: None (parity).

**L8 — Missing-person "notifies the officer" text**
- FEATURE: P-16.
- WEBSITE BEHAVIOR: The banner claims a notification.
- AVAILABLE BACKEND SUPPORT: Only a stored sighting row (visible to police via `/get_sightings`).
- FLUTTER IMPLEMENTATION: The text is reproduced verbatim.
- LIMITATION: No notification occurs on either client.

**L9 — Session lifetime**
- FEATURE: P-3.
- WEBSITE BEHAVIOR: 8 h permanent session.
- AVAILABLE BACKEND SUPPORT: No refresh endpoint.
- FLUTTER IMPLEMENTATION: Expiry is detected at the next cold start (`/api/me`).
- LIMITATION: Mid-session expiry shows as a request error (D2 AUTH-3).

---

## 5. Website defects and how Flutter handles them

| # | Defect (website source) | Flutter handling |
|---|---|---|
| W1 | Complaint phone input has the wrong id (`profile-years`), a 2-digit cap and `type=number`; `submitComplaint` then throws on `c_phone` (CD 426-428, 828, 843). **No complaint can be filed on the website.** | **Decision D-1** |
| W2 | Ambulance card shows 108 but dials 102 (CD 686-687) | **Decision D-2** |
| W3 | Track: the FIR Number and Officer Notes rows are never re-hidden, so a second lookup shows the previous complaint's FIR number or notes (CD 892-899) | Flutter renders each lookup's own data. This is not a capability change; it prevents showing another complaint's data. |
| W4 | Rights chat: the user question is inserted into `innerHTML` unescaped (CD 967) | N/A (Flutter `Text` is not HTML) |
| W5 | Signup with an existing email shows "Your Unique ID: undefined" | Show the server `message` without an ID line (P-1) |

---

## 6. Decisions needed before implementation

| ID | Question | Recommendation |
|---|---|---|
| **D-1** | Phone field (W1): reproduce the website literally (a 2-digit number box that makes submission fail), or implement the rule its own code states: optional phone, exactly 10 digits, message "Phone number must be exactly 10 digits." | Implement the stated rule. A literal copy would make the feature not work at all. |
| **D-2** | Ambulance (W2): show 108 and dial 102 (literal), show and dial 108, or show and dial 102? | Show and dial **108**, the number printed on the card and the national ambulance number. Record the deviation. |
| **D-3** | Shared auth screens: adding Confirm password, the strength meter and the W5/AUTH-1 message is functional parity, and it also changes Police sign-up because the website's sign-up page is shared by all roles too. Should the headings/labels ("Welcome Back", "Create Account"…) also be changed? That changes Police screens and golden images. | Make the functional additions (they match the website for all roles). **Do not** change headings or labels on the shared screens. |
| **D-4** | Mobile adaptations: (a) keep the app's existing sign-out confirmation dialog, or sign out immediately as the website does; (b) allow the P-17 Missing Person detail screen (card fields only); (c) confirm the public landing page (P-20) is not reproduced, since the app already opens on splash → sign-in for every role. | (a) Sign out immediately (website behaviour). (b) Allow. (c) Not reproduced. |
| **D-5** | Add the `url_launcher` dependency for `tel:` dialling (P-8, P-10). There is no other way to place a call from Flutter. | Approve. |

### Decisions recorded (2026-09-20, answered by the project owner)

| ID | Decision |
|---|---|
| D-1 | **Follow the code's rule.** Phone is optional; if entered it must be exactly 10 digits, with the message "Phone number must be exactly 10 digits." |
| D-2 | **Show and dial 108.** This deviates from the website's `tel:102` and is recorded here. |
| D-3 | **Behaviour only.** Add Confirm password ("Passwords do not match"), the non-blocking 4-bar strength meter, and the server's `message` for an existing email. Headings and labels on the shared auth screens stay unchanged. |
| D-4a | **Citizen signs out immediately** (website behaviour). Police keeps its confirmation dialog. |
| D-4b, D-4c, D-5 | Not yet answered. The recommendations stand as working assumptions until confirmed: allow the P-17 detail screen (card fields only); do not reproduce the landing page; add `url_launcher`. |

**Changes to existing Flutter files that the plan requires:** these are additive, and no Police data source or Police screen logic changes.
- `routes/app_routes.dart`, `routes/app_router.dart`: add citizen routes and a citizen guard.
- `features/dashboard/presentation/screens/role_home_screen.dart`: the citizen branch renders `CitizenShell` in place of the "COMING NEXT" list.
- `features/authentication/presentation/screens/signup_screen.dart`: add Confirm password, the strength meter and the AUTH-1 message (D-3).
- `pubspec.yaml`: add `url_launcher` (D-5).


---

## 7. Implementation status and final parity audit (2026-09-20)

### 7.1 What was built

Every new file is under `flutter_app/lib/features/citizen/`. The names differ from the working names in §2; this is the real list.

| Layer | File | Role |
|---|---|---|
| content | `domain/entities/citizen_content.dart` | Helplines, home strip, safety tips, 6 rights topics, 3 quick actions, greeting, timeline: verbatim from CD, with line references |
| data | `data/datasources/citizen_remote_data_sources.dart` | `CitizenComplaintRemoteDataSource` (`file`, `track`), `RightsChatRemoteDataSource`, `CaseStatusRemoteDataSource` |
| data | `data/datasources/citizen_failure.dart` | Turns errors into the website's own sentences (server JSON `error`, else the page's fallback, else its network text) |
| data | `data/models/citizen_complaint_models.dart`, `data/models/case_client_status.dart` | Wire models; the `formatRelativeTime` port |
| data | `data/repositories/citizen_repositories_impl.dart`, `domain/repositories/citizen_repositories.dart` | Repository contracts and implementations |
| state | `presentation/controllers/citizen_providers.dart`, `citizen_section.dart`, `complaint_controllers.dart`, `rights_and_case_controllers.dart` | Riverpod providers and controllers; `validateComplaint`; `showCitizenSection` |
| UI | `presentation/screens/citizen_shell.dart` | Drawer (sidebar) + `IndexedStack` of the 7 sections; immediate sign-out |
| UI | `presentation/screens/citizen_home_screen.dart`, `emergency_contacts_screen.dart`, `file_complaint_screen.dart`, `track_complaint_screen.dart`, `case_status_screen.dart`, `rights_chat_screen.dart`, `citizen_missing_persons_screen.dart`, `citizen_missing_person_detail_screen.dart` | The sections and the P-17 page |
| UI | `presentation/widgets/citizen_widgets.dart`, `citizen_sighting_sheet.dart` | Dial, alert, status pill (website colours), timeline, `formatAnswer` port, busy button, sighting sheet |

Changes to existing files:
- `pubspec.yaml`: `url_launcher: ^6.3.2`.
- `AndroidManifest.xml`: `DIAL`/`tel` query.
- `core/constants/api_endpoints.dart`: 3 citizen endpoints.
- `routes/app_routes.dart` + `app_router.dart`: `/citizen` prefix, citizen guard (redirect step 6), citizen detail route.
- `dashboard/.../role_home_screen.dart`: citizen → `CitizenShell`.
- Sign-up (D-3): new `authentication/domain/entities/signup_result.dart`; `AuthRepository`/`AuthRepositoryImpl`/`AuthController.signup` now return `SignupResult`; `signup_screen.dart` gains Confirm password, the strength meter and the already-registered message.
- New shared widget: `shared/widgets/inputs/password_strength_meter.dart`.

No Police data source, Police screen logic, website file or backend file was changed.

### 7.2 Automated verification

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` (offline suite) | **515 passed, 0 failed.** 453 existing tests plus new ones in `test/unit/features/citizen_test.dart` (25) and `test/widget/features/citizen_portal_test.dart` (29), 3 new sign-up tests, 4 new route-guard tests and 1 new splash test. |
| Existing tests adjusted | Signup tests fill the new Confirm field. Route-guard tests treat `CitizenShell` as a citizen's home. The splash "sign out" test now uses a judge (who keeps the confirmation), and a citizen case was added for immediate sign-out. |
| Formatting side effect | `dart format` was run over `test/`, which reflowed whitespace and trailing commas in some existing test files (no logic change). |

### 7.3 Live verification against the real backend (unmodified Flask + MongoDB + SQLite)

`test_live/citizen_live_test.dart` runs the app's own data sources over a cookie Dio configured like `DioClient`, with `--dart-define=API_BASE_URL=http://127.0.0.1:5000`. Result: **12/12 passed.**

| Feature | Live result |
|---|---|
| P-1 | New citizen registered and given `CIT014`. The same email again gave 200, no ID, "If eligible, your account has been created." (AUTH-1 path confirmed). |
| P-2/P-3 | Login gave role `citizen`; `/api/me` gave `logged_in: true`, `role: citizen`. |
| P-11/P-13 | Filed complaint `CMP-1967E48B` came back `Pending`; tracked back (lower-case input accepted). Unknown ID gave "Complaint not found. Check your tracking ID."; empty name gave the server's 400 text. The Police endpoint `/api/complaints/all` lists it with its phone number (Police inbox parity). |
| P-14 | Greeting gave the canned intro; preset question answered (731 chars). **L2:** off-topic and nonsense questions also returned 200 with an answer, because `search_law` returned sections for every query tried. The 500 path in the code is **latent, not observed**; the app still maps it to the website's "Could not connect…". |
| P-15 | Unshared FIR gave "Status not available for this FIR". |
| P-16/P-18 | 2 active cases listed. A sighting using the case's own photo gave `is_match=true`, 100%, "Face distance: 0.0. MATCH FOUND! Confidence: 100.0%". Server log: `face_recognition_helper loaded.` (L4 not in demo mode). |
| P-9 | Logout ends the session (`/api/me` gives `logged_in: false`). |

**Test data now in the shared database (not deleted):**
- Mongo `users`: `zz.flutter.citizen.1789853457566@example.com` (`CIT014`)
- SQLite `citizen_complaints`: `CMP-1967E48B`
- SQLite `missing_person_sightings`: `SG_47076DE998F5` against the **real open case `MP_6CBFDFF92A3A`**, confirmed match, with its file `website/static/uploads/sightings/SG_47076DE998F5.jpg`. ⚠️ It appears in the Police "Confirmed Matches".

**Not done:** running the UI on a device or emulator. The screens are covered by widget tests, and the data layer by the live run, but the DoD's "manually exercised end-to-end" on a handset is still open. That is why no feature is marked Complete yet.

### 7.4 Final parity audit

Key: ✅ equivalent · ⚖️ equivalent with a recorded, approved deviation · — not applicable.

The audit columns are: Has / Function / API / Fields / Valid. (validations) / Actions / Success / Error / Info / Cond. (conditional behaviour) / Nav / Auth-role / Missing website capability / Invented capability.

| # | Feature | Has | Function | API | Fields | Valid. | Actions | Success | Error | Info | Cond. | Nav | Auth-role | Missing website capability | Invented capability | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P-1 | Registration | ✅ | ✅ | ✅ | ✅ (Confirm added) | ✅ + meter | ✅ | ⚖️ tap-to-dismiss dialog instead of a 2 s auto-redirect | ✅ | ⚖️ existing-email: message without "undefined" ID (W5) | ✅ ID field only for professional roles | ✅ | ✅ | none | none (Citizen preselected in the role picker; existing behaviour) | Implemented, awaiting device run |
| P-2 | Login | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚖️ lands directly, no "Login successful" flash | ✅ | ⚖️ wording unchanged (D-3) | — | ✅ | ✅ | "Forgot password?" not reproduced (L3, dead link) | none | Implemented, awaiting device run |
| P-3 | Session restoration | ✅ | ✅ | ✅ `/api/me` | — | — | — | ✅ | ✅ | — | — | ✅ | ✅ | none | none | Implemented, awaiting device run |
| P-4 | Role routing | ✅ | ✅ | — | — | — | — | — | — | — | ✅ | ✅ | ✅ `/citizen/*` citizen-only; police routes refuse citizens | none | none | Implemented, awaiting device run |
| P-5 | Navigation shell | ✅ | ✅ | — | — | — | ✅ 7 sections + Sign Out | — | — | ✅ | ✅ | ✅ Drawer = sidebar/mobile menu | — | none | none | Implemented, awaiting device run |
| P-6 | Home | ✅ | ✅ | — | — | — | ✅ | — | — | ✅ no user data | — | ✅ | — | none | none | Implemented, awaiting device run |
| P-7 | Quick actions | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ | ✅ | — | ✅ ask, then open Rights | — | none | none | Implemented, awaiting device run |
| P-8 | Home emergency strip | ✅ | ✅ | — (`tel:`) | — | — | ✅ | ✅ | ⚖️ snackbar if no dialler | ✅ | — | — | — | none | ⚖️ "Could not open the dialler. Call N." (platform failure only) | Implemented, awaiting device run |
| P-9 | Logout | ✅ | ✅ | ✅ | — | — | ✅ | ✅ | ✅ | — | — | ⚖️ goes to login, not landing (P-20) | ✅ | none | none | Implemented, awaiting device run |
| P-10 | Emergency + Safety Tips | ✅ | ✅ | — | — | — | ✅ | ✅ | ⚖️ as P-8 | ⚖️ Ambulance dials 108 (D-2) | — | — | — | none | as P-8 | Implemented, awaiting device run |
| P-11 | File a Complaint | ✅ | ✅ | ✅ same 5 keys | ✅ | ⚖️ phone rule per D-1 | ✅ | ✅ | ✅ website texts | ✅ category/can_file_fir hidden (L7) | ✅ | ✅ | ✅ (no auth on the API: L1) | none | none | Implemented, awaiting device run |
| P-12 | Submission success | ✅ | ✅ | — | — | — | ✅ "Track My Complaint →" without prefill | ✅ | — | ✅ | ✅ form hidden after success | ✅ | — | none | none (the ID is selectable) | Implemented, awaiting device run |
| P-13 | Track Complaint | ✅ | ✅ | ✅ | ✅ | ✅ empty-ID alert | ✅ | ✅ | ✅ | ✅ same fields, description/category hidden | ✅ FIR/notes rows only if present (W3 not reproduced) | ✅ | ✅ (L1, L5) | none | ⚖️ busy spinner on the button | Implemented, awaiting device run |
| P-14 | Know Your Rights | ✅ | ✅ | ✅ | — | ✅ empty ignored | ✅ 6 topics + free text | ✅ answer shown whatever the HTTP status | ✅ "Could not connect…" | ✅ | ✅ | ✅ | — | none | none | Implemented, awaiting device run |
| P-15 | My Case Status | ✅ | ✅ | ✅ | ✅ | ✅ empty does nothing | ✅ | ✅ | ✅ amber texts | ✅ 4 values | ✅ note only if present | ✅ | ✅ (public API: L6) | none | ⚖️ busy spinner | Implemented, awaiting device run |
| P-16 | Missing Persons list | ✅ | ✅ | ✅ | ✅ card fields | — | ✅ | ✅ | ✅ "Error loading data." | ✅ | ✅ empty "All clear…"; fetched on open | ✅ | ✅ citizen view only | none | ⚖️ local "No Photo" placeholder instead of placehold.co | Implemented, awaiting device run |
| P-17 | Missing Person Details | ✅ | ⚖️ page instead of card-only (working assumption) | ✅ list data only | ✅ same fields | — | ✅ Report Sighting | — | ✅ | ✅ nothing extra | ✅ | ✅ | ✅ | none | ⚖️ the page itself (approved assumption D-4b) | Implemented, awaiting device run |
| P-18 | Report Sighting | ✅ | ✅ | ✅ same multipart | ✅ | ✅ website order + image-type check | ✅ camera/gallery | ✅ match auto-closes after 2 s and reloads; no-match stays open | ✅ | ✅ confidence, details | ✅ | ✅ | ✅ any signed-in user | none | none | Implemented, awaiting device run |
| P-19 | Forgot password | — | — | — | — | — | — | — | — | — | — | — | — | L3: no backend | none | Limitation |
| P-20 | Landing page | — | — | — | — | — | — | — | — | — | — | — | — | Not reproduced (D-4c, working assumption) | none | Decision pending confirmation |

**To mark P-1…P-18 Complete:** run the manual script in `.claude/plan/citizen_implementation_plan.md` §Verification on an emulator or phone, and confirm the working assumptions D-4b, D-4c and D-5.

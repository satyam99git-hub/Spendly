# D3 — Website Citizen Feature Extraction

**Source of truth:** `/home/user/Documents/NayayaAi_main(1)_gmailmain/website/`.
**Stack (verified):** a Flask server-rendered site, not a SPA framework. The "router config" is the set of `@app.route` / blueprint routes in `website/app.py`, `website/missing_person.py` (`missing_person_bp`, registered at `app.py:333`) and `website/main/judge_routes.py` (`judge_bp`, `url_prefix="/judge"`, registered at `app.py:93`).
- The Citizen UI is **one template**, `templates/citizen_dashboard.html`. It shows and hides seven in-page `<section>`s through a JavaScript `showSection(id)` (`citizen_dashboard.html:766-778`), so those sections are the Citizen "client routes".
- The Missing Persons section loads a second template fragment at runtime (`missing_persons_fragment.html`).

Line numbers refer to the files as of 2026-09-20. The website has uncommitted changes (`git status`: `app.py`, `rag_engine.py`, `IndiaLaw.db`, `requirements.txt` modified), so these line numbers may move.

---

## Part A — Full route inventory (every registered route)

The table covers every route the Flask app registers, so no router entry is omitted. **Citizen-relevant rows** (marked ✅) get a full block in Part B. Every other row is listed with the reason it is out of Citizen scope.

| # | Method | Path | Handler (file:line) | Server auth | Used by Citizen UI? |
|---|---|---|---|---|---|
| 1 | GET | `/` | `home` app.py:502 | none; redirects by session role | ✅ public landing (`landing.html`) |
| 2 | GET | `/health` | `health` app.py:515 | none | no (ops) |
| 3 | GET | `/api/districts` | app.py:519 | none | no (police FIR form) |
| 4 | GET | `/api/police-stations/<district>` | app.py:524 | none | no (police) |
| 5 | GET | `/api/acts` | app.py:530 | none | no (police/law library) |
| 6 | GET | `/citizen-dashboard` | `citizen_dashboard` app.py:568 | session + `role=='citizen'` | ✅ |
| 7 | GET | `/judge-dashboard` | app.py:576 | judge/admin | no |
| 8 | POST | `/api/complaint` | `file_complaint` app.py:584 | **none** | ✅ |
| 9 | GET | `/api/complaints/all` | app.py:627 | **none** (docstring says "Police") | no (police) |
| 10 | PATCH | `/api/complaints/<tracking_id>` | app.py:661 | **none** | no (police) |
| 11 | GET | `/api/complaint/<tracking_id>` | `track_complaint` app.py:691 | **none** | ✅ |
| 12 | POST | `/api/rights-chat` | `rights_chat` app.py:724 | **none** | ✅ (AI) |
| 13 | GET | `/api/sections/<act>` | app.py:900 | none | no (police law library) |
| 14 | GET | `/api/section-detail/<act>/<no>` | app.py:955 | none | no |
| 15 | POST | `/api/predict-outcome` | app.py:977 | none | no (police) |
| 16 | GET | `/open-bare-act/<act_code>` | app.py:1056 | none | no (police console) |
| 17 | GET | `/lawyer_dashboard` | app.py:1079 | lawyer | no |
| 18 | POST | `/api/lawyer/draft-document` | app.py:1143 | lawyer | no |
| 19 | POST | `/api/lawyer/bail-draft` | app.py:1178 | lawyer | no |
| 20 | POST | `/api/lawyer/find-precedents` | app.py:1214 | lawyer | no. Note: `return` is indented inside `if not answer:` (app.py:1294-1303), so a successful Groq answer returns `None` and results in a 500. |
| 21 | POST | `/judge/precedents` | app.py:1385 | judge | no |
| 22 | GET | `/api/search-sections` | app.py:1570 | none | no (police) |
| 23 | POST | `/api/ask-law` | app.py:1651 | none | no (police) |
| 24 | POST | `/api/fir-records/<fir_no>/assign-lawyer` | app.py:1696 | lawyer | no |
| 25 | GET | `/api/fir-records` | app.py:1711 | **none** | no (police) |
| 26 | GET | `/api/fir-records/<path:fir_no>` | app.py:1722 | **none** | no (police) |
| 27 | POST | `/api/suggest-sections` | app.py:1737 | police/admin/officer | no |
| 28 | POST | `/generate_fir` | app.py:1786 | **none** | no (police) |
| 29 | POST | `/upload_evidence/<fir_no>` | app.py:1936 | none | no (legacy upload) |
| 30 | GET, POST | `/signup` | `signup` app.py:1979 | `require_same_origin` + rate limit | ✅ |
| 31 | GET, POST | `/login` | `login` app.py:2052 | `require_same_origin` + rate limit | ✅ |
| 32 | GET | `/citizen_dashboard` | app.py:2110 | none (redirects to #6) | ✅ (login redirect target) |
| 33 | GET | `/logout` | app.py:2114 | none | ✅ |
| 34 | GET | `/dashboard` | app.py:2119 | session | no. Renders `dashboard.html`, which **does not exist** in `templates/`, so a signed-in request results in a 500. |
| 35 | POST | `/verify-locker-access` | app.py:2131 | none (PIN) | no (police) |
| 36 | POST | `/upload-evidence` | app.py:2147 | **none** | no (police) |
| 37 | GET | `/get-evidence/<path:fir_no>` | app.py:2186 | none | no |
| 38 | GET | `/evidence-file/<path:fir_no>/<filename>` | app.py:2191 | none | no |
| 39 | GET | `/api/evidence` | app.py:2198 | none | no |
| 40 | POST | `/api/evidence/log-access` | app.py:2235 | none (stub) | no |
| 41 | GET | `/get-all-evidence` | app.py:2241 | none | no |
| 42 | GET | `/fir/view/<path:fir_no>` | app.py:2250 | none | no |
| 43 | GET | `/fir/download/<path:fir_no>` | app.py:2312 | none | no |
| 44-54 | GET/POST/PATCH/DELETE | `/api/case/<fir_no>/{hearings,drafts,drafts/<id>,status,deadlines,deadlines/<id>,client-visibility}`, `/api/lawyer/{drafts,deadlines,profile,profile/photo}` | app.py:2356-2588 | lawyer (+ `lawyer_owns_case`) | no (lawyer) |
| 55 | GET | `/api/case/<fir_no>/client-status` | `get_client_status` app.py:2520 | **none (documented "Public")** | ✅ |
| 56 | GET | `/missing_persons` | app.py:342 | none (the page checks `/api/me` client-side) | ✅ (standalone page) |
| 57 | GET | `/script.js` | app.py:346 | none | no (police console JS) |
| 58 | GET | `/missing_persons_template` | app.py:351 | none | ✅ (fragment loaded by the Citizen dashboard) |
| 59 | GET | `/api/me` | `api_me` missing_person.py:116 | none; always 200 | ✅ |
| 60 | GET | `/get_missing_persons` | missing_person.py:138 | none | ✅ |
| 61 | POST | `/upload_missing_person` | missing_person.py:176 | police/admin/officer | no (police) |
| 62 | POST | `/report_sighting/<person_id>` | missing_person.py:254 | **any logged-in user** | ✅ |
| 63 | GET | `/get_sightings/<person_id>` | missing_person.py:350 | police | no |
| 64 | GET | `/get_confirmed_matches` | missing_person.py:388 | police | no |
| 65 | POST | `/update_missing_person_status/<person_id>` | missing_person.py:441 | police | no |
| 66 | GET | `/judge/dashboard` | judge_routes.py:16 | judge | no |
| 67-70 | GET/POST/PUT/DELETE | `/judge/docket`, `/judge/docket/<int:entry_id>` | judge_routes.py:24-102 | judge | no |
| — | GET | `/static/...` (Flask default static) | Flask | none | ✅ (missing-person and sighting photos: `/static/uploads/missing_persons/*`, `/static/uploads/sightings/*`) |
| — | GET | `/forgot-password` | **no route exists** | — | ✅ linked from `login.html:442`, so it returns **404** |

**Not registered, so dead code:** `website/main/auth_routes.py` (`/signup`, `/login`, `/logout`, `/dashboard`), `main/general_routes.py` (`/`, `/health`), `main/fir_routes.py`, `main/evidence_routes.py`, `main/legal_routes.py`. `main/__init__.py` imports them but `app.py` never calls `register_blueprint` for them (only `app.py:93` and `app.py:333` do).

---

## Part B — Citizen route blocks

### Route: `/` (landing)
- **Component(s):** `templates/landing.html` (rendered by `home()`, app.py:502-513, when there is no session). A signed-in citizen is redirected to `/citizen-dashboard` (app.py:508-509).
- **Auth required:** No (public).
- **User actions:** "Sign in" → `/login` (landing.html:117, 339); "Get started / Sign up" → `/signup` (landing.html:121, 152, 335). The rest is marketing copy with GSAP animation (landing.html:13-14, 360+).
- **API calls:** None.
- **Validation / error / loading states:** None.
- **Notes:** The feature cards (landing.html:211-242) describe police features. No Citizen data is shown.

### Route: `/signup` (GET page, POST API)
- **Component(s):** `templates/signup.html`; handler `signup()` app.py:1979-2050.
- **Auth required:** No. Guarded by `require_same_origin` (app.py:165-199) and `SIGNUP_RATE_LIMIT` (default `60 per hour` per IP, app.py:121).
- **User actions:** pick role (a button group sets the hidden `<select id="role">`, `selectRole()` signup.html:457-474) → fill full name, email, password, confirm password (+ unique ID for police/lawyer/judge only) → submit.
- **API calls:**
  - `POST /signup`. Payload: JSON `{fullname, email, password, role, unique_id}` (signup.html:507-513; `unique_id` is sent as `''` for citizens).
  - **201** `{message: "User registered successfully", unique_id: "CIT###", role}` (app.py:2042-2046). The citizen ID is generated by `generate_unique_id` (app.py:1951-1977): the highest existing `unique_id` for the role, +1, zero-padded to 3 digits.
  - **400** `{error}` for: missing fields, `Invalid email address` (`EMAIL_RE` app.py:201), `Invalid role`, password policy (`validate_password` app.py:206-217), unique-ID rules (professional roles only).
  - **200** `{message: "If eligible, your account has been created."}` with **no `unique_id`** when the email already exists (app.py:2004-2005; anti-enumeration).
  - **500** `{error: "Registration failed: …"}`.
  - Auth: none; the request is same-origin (browser `Origin`) or carries the `X-NyayaAI-Client` header (the app).
- **Validation:**
  - *Client (signup.html):* HTML `required` on name, email, password and confirm; `type="email"`; confirm must equal password (signup.html:501-504); strength meter only (does not block).
  - *Server:* all fields present; email regex; role ∈ {police, citizen, lawyer, judge}; password ≥10 characters with uppercase, lowercase, digit and special character; email is lower-cased and trimmed.
- **Error states observed in code:** `result.error` is rendered in red in `#message`; `.catch` shows "An error occurred. Please try again." (signup.html:519-530).
- **Loading states observed in code:** none; the button is not disabled.
- **Success:** shows `message` + "Your Unique ID: …", then redirects to `/login` after 2 s (signup.html:524-525). For the existing-email 200 response the page shows "Your Unique ID: undefined".
- **Notes:** Signup does **not** create a session.

### Route: `/login` (GET page, POST API)
- **Component(s):** `templates/login.html`; handler `login()` app.py:2052-2107.
- **Auth required:** No. `require_same_origin` + `LOGIN_RATE_LIMIT` (default `100 per 15 minutes`, app.py:122).
- **User actions:** enter email and password → "Sign In" button or the Enter key (login.html:453, 513) → role-based redirect. A "Forgot password?" link goes to `/forgot-password` (login.html:442), **which has no route (404)**.
- **API calls:**
  - `POST /login`. Payload `{email, password}` (login.html:477-481).
  - **200** `{message: "Login successful", role, unique_id, redirect}` + `Set-Cookie: session` (app.py:2088-2105; session holds `user_id`, `role`, `unique_id`, `fullname`; permanent, 8 h).
  - **400** `{error: "Email and password are required"}`.
  - **401** `{error: "Invalid credentials"}`.
  - **423** `{error: "Account temporarily locked. Try again later."}` after 5 failures (15-minute lock, app.py:203-204, 2070-2081).
  - **429** from Flask-Limiter.
- **Validation:** *Client:* both fields non-empty (login.html:470-473). *Server:* both present; email lower-cased.
- **Error states:** `data.error` rendered in `#msg`; `.catch` shows "An error occurred. Please try again."
- **Loading states:** none.
- **Navigation:** `role==='citizen'` → `/citizen_dashboard` (login.html:490-492) → 302 to `/citizen-dashboard` (app.py:2110-2112).

### Route: `/logout`
- **Component(s):** links in the Citizen sidebar and top nav (`citizen_dashboard.html:216, 238`).
- **Auth required:** No.
- **API calls:** `GET /logout` → `session.clear()` → 302 to `/` (app.py:2114-2117).

### Route: `/citizen-dashboard` → section `home` (default)
- **Component(s):** `templates/citizen_dashboard.html` `<section id="home">` (lines 244-385), sidebar (168-220), top nav (231-241), mobile menu toggle (223-225, 792-806).
- **Auth required:** **Yes: session and `role == 'citizen'`** (app.py:568-574). Otherwise it redirects to `/login` (no session) or `/` (another role).
- **User actions:**
  - Hero buttons "File a Complaint" and "Track My Complaint" → `showSection(...)`.
  - Three stat cards → file / track / know-rights sections.
  - Four quick actions (lines 328-351): "Arrest Rights", "FIR Refused?" and "Free Legal Aid" call `askRightsQuestion(<preset>)` and then open know-rights; "Missing Persons" opens that section.
  - Emergency strip: `tel:` links for 100, 1091, 112, 1930, 1098 and 15100 (lines 363-380).
- **API calls:** none directly (quick actions call `/api/rights-chat`, see below).
- **Notes:** The stat cards are static text ("Simple 2-min form", "4-stage timeline"), not counts. There is no per-citizen data on the home page. The page never reads the citizen's name or ID.

### Route: `/citizen-dashboard` → section `file-complaint`
- **Component(s):** `<section id="file-complaint">` (lines 388-463); `submitComplaint()` (lines 813-863).
- **Auth required:** The page needs a citizen session. **The API itself requires none** (app.py:584-624 has no session check), and the complaint is **not linked to the citizen's account** (the INSERT at app.py:602-614 stores no `user_id`).
- **User actions:** fill Full Name*, Phone, Date of Incident, Location / Area, Describe the Incident* → "Submit Complaint". On success a card shows the tracking ID with a "Track My Complaint →" button (lines 399-412).
- **API calls:**
  - `POST /api/complaint`. Payload JSON `{full_name, phone, incident_date (yyyy-mm-dd from <input type=date>), location, incident_description}` (lines 838-848).
  - **201** `{tracking_id: "CMP-XXXXXXXX", status: "Pending", category, can_file_fir}` (app.py:617-622). `tracking_id` is `"CMP-" + uuid4()[:8].upper()` (app.py:593). `category`, `is_cognizable` and `can_file_fir` come from the **keyword categoriser** `complaint_categorizer.categorize_complaint` (rule-based, not ML).
  - **400** `{error: "Name and incident description are required"}`.
  - **500** `{error: <exception text>}`.
  - Auth: none.
- **Validation:**
  - *Client:* name and description required (alert); name must match `/^[A-Za-z ]+$/` (the `oninput` handler also strips other characters, `maxlength="60"`, lines 418-420, 823-826); phone, if present, must be exactly 10 digits (lines 828-832).
  - *Server:* `full_name` and `incident_description` non-empty only.
- **Error states:** `alert(data.error || 'Submission failed.')`; network error gives `alert('Network error. Please try again.')`.
- **Loading states:** the button is disabled and relabelled "Submitting…" (lines 834-835, 859-862).
- **🔴 Defect in current source: website complaint submission is broken.** The Phone `<input>` has `id="profile-years"` (`type="number"`, `max="60"`, a 2-digit limit, line 426: a copy-paste from the lawyer profile form). `submitComplaint()` reads `document.getElementById('c_phone').value` (lines 828, 843). `c_phone` does not exist, so this throws `TypeError: Cannot read properties of null` after the name checks and **before** the `fetch`. No complaint can be filed from the website as the code stands. The endpoint itself is intact.
- **Notes:** The category and `can_file_fir` returned by the server are **not shown** to the citizen. The disclaimer says "This complaint is not an official FIR" (lines 450-454).

### Route: `/citizen-dashboard` → section `track-complaint`
- **Component(s):** `<section id="track-complaint">` (lines 466-527); `trackComplaint()` (lines 868-930).
- **Auth required:** The page needs a citizen session. **The API requires none**; knowing the tracking ID is the only access control. There is no ownership check, so any tracking ID returns that complaint's name, description, location and officer notes.
- **User actions:** type a tracking ID (the input upper-cases on input) → "Track" or Enter.
- **API calls:**
  - `GET /api/complaint/<tracking_id>` (line 876; the ID is not URL-encoded client-side, and the server upper-cases it).
  - **200** `{tracking_id, full_name, incident_description, incident_date, location, status, fir_no, officer_notes, created_at, updated_at, category, is_cognizable}` (app.py:707-720). `phone` is **not** returned.
  - **404** `{error: "Complaint not found. Check your tracking ID."}`.
  - **500** `{error}`.
- **Validation:** client: non-empty (alert). Server: none.
- **Rendering:** tracking ID; a status pill (CSS classes `status-Pending`, `status-Under-Review`, `status-FIR-Filed`, `status-Closed`, lines 60-78); name; incident date (or "Not specified"); location; "Filed On" (`new Date(created_at).toLocaleDateString('en-IN')`, where `created_at` is SQLite `YYYY-MM-DD HH:MM:SS` UTC); FIR number row only if `fir_no`; officer-notes row only if `officer_notes`. A **4-step timeline** `['Pending','Under Review','FIR Filed','Closed']` marks completed steps up to the current index (lines 906-923). An unknown status gives index -1, so no step is highlighted.
- **Error states:** a red `#trackError` box shows `data.error` or "Network error. Please try again."
- **Loading states:** none.
- **Notes:** `category` and `is_cognizable` are returned but not displayed. The officer notes are shown verbatim (see D2 CMP-2).

### Route: `/citizen-dashboard` → section `case-status` ("My Case Status")
- **Component(s):** `<section id="case-status">` (lines 529-567); `checkCaseStatus()` (lines 1073-1110); `formatRelativeTime()` (lines 1054-1071).
- **Auth required:** The page needs a citizen session. **The API is public** (app.py:2520-2532, docstring "Public — no login required"). Data appears only if the assigned lawyer set `visible_to_client` through `PATCH /api/case/<fir>/client-visibility` (app.py:2502-2517). There is no link between the citizen and the FIR, so anyone with the FIR number sees it once it is made visible.
- **User actions:** enter an FIR number → "Check" or Enter.
- **API calls:**
  - `GET /api/case/<encodeURIComponent(fir_no)>/client-status` (line 1081).
  - **200** `{fir_no, status, next_hearing_date, client_note, client_note_updated_at}`; data from Supabase `firs` via `get_fir`.
  - **404** `{error: "Status not available for this FIR"}` (covers both "not found" and "not shared").
- **Validation:** client: non-empty (returns silently if empty). Server: none.
- **Rendering:** FIR number, a status pill (lawyer statuses `Investigation / Court Proceedings / Trial / Closed`, app.py:2428; `Active` if empty), "Next Hearing" (or "Not scheduled"), and a "Note from your lawyer" block with relative time ("Updated N min ago").
- **Error states:** an amber `#csError` box with `data.error` (fallback "Your lawyer hasn't shared this case's status yet.") or "Network error. Please try again."
- **Loading states:** none.

### Route: `/citizen-dashboard` → section `know-rights` (AI)
- **Component(s):** `<section id="know-rights">` (lines 570-650); `askRightsQuestion(preset)` (lines 958-1016); `formatAnswer()` (lines 936-953).
- **Auth required:** The page needs a citizen session. **The API requires none** (app.py:724).
- **User actions:** tap one of 6 quick topics (lines 581-622: arrest, bail, lawyer, FIR refused, women's rights, legal aid; each sends a fixed English question) **or** type a question → "Ask" or Enter. The home page quick actions call the same function.
- **API calls:**
  - `POST /api/rights-chat`. Payload `{question}` (lines 985-989).
  - Response: `{answer: <plain text / light markdown>}`. **200** normally; **400** `{answer: "Invalid request."}` or `{answer: "Please ask a question about your rights."}`.
- **AI trace (end to end):**
  1. **Trigger:** a quick-topic click or input submit. The user bubble is appended, then a "Thinking…" bubble with a spinner (lines 965-981).
  2. **Server** `rights_chat()` app.py:724-791:
     - Greeting short-circuit: if the question is in the `GREETINGS` set, a canned intro is returned (lines 734-746).
     - `search_law(question)` (`rag_engine.py:137+`): exact section lookup if the question names a section (`law_data.csv` 84 IPC rows, then `IndiaLaw.db` via `sections_ai.find_section`); otherwise FAISS semantic search over `law_vector_db` with HuggingFace embeddings and `min_similarity=0.35`. It returns a list or `None`.
     - If there are results, a prompt is built with the top 3 sections and sent to `ask_groq(prompt, max_tokens=1200)` (app.py:1096-1136: Groq `openai/gpt-oss-120b`, temperature 0.3, key `GROQ_API_KEY`). The prompt caps the answer at 150 words and appends "⚠️ For official help call 15100".
     - If Groq fails (returns `None`) but results exist → `format_rights_answer(results)` (app.py:796-819), a template answer.
  3. **Client handling:** `res.json()`, then `formatAnswer` (escapes `& < >`, converts `**bold**` and `-`/`•` bullets, newline → `<br>`), and replaces the "Thinking…" bubble. `res.ok` is **not** checked, so a 400 `{answer}` is displayed like an answer.
- **🔴 Server defect: no-RAG-match path results in HTTP 500.** `groq_prompt` is assigned **inside** the `for r in results[:3]:` loop (app.py:758-772, an indentation error). When `search_law` returns `None` (any question with no section above the similarity threshold), line 775 `ask_groq(groq_prompt, …)` raises `UnboundLocalError`. The `except` then calls `build_keyword_fallback(...)` (app.py:789), which is **commented out** (app.py:822-898), so it raises `NameError` inside the handler and Flask returns a 500 (an HTML debug page, since `debug=True`). The client's `res.json()` throws, and the user sees "Could not connect. Check your server is running and try again." (lines 1001-1015).
- **Validation:** client: non-empty. Server: non-empty.
- **Error states:** a network or parse failure shows a red bubble, "Could not connect…".
- **Loading states:** a "Thinking…" bubble with a spinner.
- **Security note (website only):** the user's question is inserted into `innerHTML` unescaped (line 967), which is a self-XSS. Not applicable to Flutter.

### Route: `/citizen-dashboard` → section `missing-persons` (+ `/missing_persons_template`, `/missing_persons`)
- **Component(s):** `<section id="missing-persons">` (lines 653-663); `loadMissingPersons()` (lines 1020-1052) fetches `GET /missing_persons_template` (app.py:351-353 → `templates/missing_persons_fragment.html`), injects the HTML and re-executes its `<script>`. The standalone page `GET /missing_persons` (app.py:342-344 → `templates/missing_persons.html`) contains the same logic (API calls at missing_persons.html:254-615).
- **Auth required:** The fragment calls `GET /api/me`. If `logged_in` is false it shows "Login Required" (fragment lines 57-68, 405-411). A role other than police/admin/officer gets the **Citizen tab only** (lines 421-443); the Police and Matches tabs refuse with an alert (lines 447-452). Server: listing is public; `report_sighting` needs any session (401 otherwise).
- **User actions (citizen):**
  - Browse the active-case cards (photo, MISSING badge, "Last seen <date>", name, age · gender, location, 2-line description).
  - "Report Sighting" on a card opens a modal (lines 280-339) with Location*, Date* (defaults to today, line 765) and Photo* (`accept="image/jpeg,image/png,image/webp,image/gif"`, with preview) → "Submit Sighting".
- **API calls:**
  - `GET /api/me` → `{logged_in, role, user_id}` (missing_person.py:116-133).
  - `GET /get_missing_persons` → `{success, missing_persons: [{person_id, name, age, gender, description, photo_url ("/static/uploads/missing_persons/MP_xxx.jpg"), last_seen_location, last_seen_date, created_at, status}]}`. Only `status='Missing'`, newest first (missing_person.py:138-171).
  - `POST /report_sighting/<person_id>` (lines 796-801). Multipart `{location, sighting_date, photo}`. **200** `{success:true, sighting_id, face_match_score (0–1), is_match, details, message}`. **400** `{success:false, error}` for no photo, a non-image extension, no location, or "No face detected in your photo…". **401** "Please log in to report a sighting." **404** "Record not found or already resolved." **500** `{success:false, error}`.
  - Images are served from `/static/uploads/...` (Flask static).
- **AI trace:** Trigger: submit sighting → server saves the photo, calls `extract_face` (the face must be present, otherwise the file is deleted and 400 returned) → `compare_faces(police_photo, citizen_photo, tolerance=0.55)` (`face_recognition_helper.py`) → the row is inserted into `missing_person_sightings` with `is_confirmed = is_match` → the client shows "✓ Match Confirmed!" (green) or "Sighting Recorded" (yellow), the confidence `Math.round(score*100)%` and `details`. On a match the modal closes after 2 s and the list reloads (lines 803-818). **Risk:** if the face library fails to import, `missing_person.py:18-33` returns **random** scores (see D2 MP-1).
- **Validation:** *Client:* location, date and photo required (alerts, lines 788-790). *Server:* photo present with an allowed extension (jpg/jpeg/png/gif/webp); location required; `sighting_date` defaults to today; the person must exist and be `Missing`; a face must be detected.
- **Error states:** a list fetch error gives "Error loading data."; the modal shows `data.error` in a red box or "Network error — please try again."; a fragment load failure gives "Error loading Missing Persons data. Please refresh."
- **Loading states:** a spinner while the fragment and list load; the submit button shows "Analysing face…" with a spinner and is disabled.
- **Empty state:** "All clear — no active cases" (fragment line 605).

### Route: `/citizen-dashboard` → section `emergency`
- **Component(s):** `<section id="emergency">` (lines 666-756).
- **Auth required:** The page needs a citizen session. There is no API.
- **User actions:** tap a card to dial with `tel:`: 100 Police, 112 National Emergency, **"108 Ambulance" (the card displays 108 but links to `tel:102`, lines 686-687, a data defect)**, 101 Fire, 1091 Women, 1930 Cyber, 1098 Child, 14567 Senior Citizen, 15100 Legal Aid.
- **API calls:** none. The content is **static HTML**.
- **Notes:** a "Safety Tips" list of 5 static strings (lines 742-753).

### Route: `/forgot-password`
- **Component(s):** a link only (`login.html:442`).
- **Auth required:** n/a.
- **API calls:** **none. No Flask route exists, so the link returns 404.** There is no password-reset handler, token table or email sender in `website/`. (`Application/NayayaAi_APP/database/schema/password_reset.sql` exists but no code uses it.)

---

## Part C — Summary of verified Citizen facts

| Topic | Finding |
|---|---|
| Citizen identity in data | Complaints and case-status lookups are **not tied to the citizen account**. Only sightings record `uploaded_by_citizen = session user_id` (missing_person.py:324). |
| "My complaints" list | **Does not exist** on the website. Tracking is by manually entered ID only. |
| Profile / edit profile | **Does not exist** for citizens. The page never shows name or ID. |
| Notifications | **Do not exist** (no endpoint or push). The "notifies the investigating officer" copy (fragment line 236-237) is not backed by any notification code; it only writes a row. |
| File uploads | Sighting photos only. Complaints have no attachments. |
| AI integrations | (1) Know-Your-Rights: RAG plus Groq LLM, with a known 500 on the no-match path. (2) Sighting face match (`face_recognition`, with a random-score fallback risk). (3) Complaint auto-category (keyword rules, result not shown to the citizen). |
| Broken in current website source | File-complaint submit (`c_phone` null); rights-chat no-match 500; forgot-password 404; Ambulance card dials 102. |

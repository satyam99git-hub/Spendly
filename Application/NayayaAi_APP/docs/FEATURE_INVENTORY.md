# NayayaAI — Feature Inventory (Website Study → Flutter Build Plan)

> **Build log**
>
> | Feature | State | Notes |
> |---|---|---|
> | **F0 — App Foundation** | ✅ Done | Routing, Dio + session cookie, DI, `Failure` mapping, secure storage |
> | **F1 — Auth** | ✅ Done | Sign in / register / sign out / session restore, against the existing MongoDB users. See `features/01-authentication.md` |
> | **F2 — Social login** | ⏸ Deferred | Excluded by instruction; also needs backend work |
> | **F8 — FIR Registration** | ✅ Done | FORM IF-1 in full — 27 entries across a four-step wizard with a review page, draft autosave, against the existing `fir_records`. See `features/02-fir-registration.md` |
> | **Police dashboard** | ✅ Done | Tabbed console (FIR · Complaints · Evidence · Law) for police and admin; other roles keep the role list. See `features/03-evidence-locker.md` |
> | **F10 — Evidence Locker** | ✅ Done | PIN gate (server-checked via `POST /verify-locker-access`), list grouped by FIR, upload, file detail, against the existing `evidence_files`. See `features/03-evidence-locker.md` |
> | **F9 — FIR History & Viewer** | ✅ Done | List, in-app FORM IF-1 viewer, PDF download. Reads the same `fir_records` F8 writes. See `features/04-fir-history.md` |
> | **F11 — Complaints Inbox** | ✅ Done | Stage / category / date / text filters, respond, escalate, and convert to an FIR with the two linked on filing. Reads `citizen_complaints` in SQLite; built without F3/F4. See `features/05-complaints.md` |
> | **F12 — Law Library** | ✅ Done | All eight acts, per-act paging and search, cross-act search, and a two-section comparison. See `features/06-law-library.md` |
> | **Ask NyayaAI** | ✅ Done | `POST /api/ask-law` — a legal question in plain words, answered from the same section tables. See `features/06-law-library.md` |
> | **Which sections apply** | ✅ Done | `POST /api/predict-outcome` — a described incident matched against the sentencing dataset. Reads the structured `results`, not the website's HTML. See `features/06-law-library.md` |
> | **Missing Persons** | ✅ Done | Register a case, browse open cases, report a sighting with server-side face comparison, review confirmed matches, mark found. See `features/07-missing-persons.md` |
> | **Terms & the new codes** | ✅ Done | The glossary and the IPC/CrPC → BNS/BNSS renumbering the console keeps in its sidebar. No endpoint exists for either; both are transcribed into the app. See `features/06-law-library.md` |
> | **Suggested acts & sections** | ✅ Done | `POST /api/suggest-sections` — Groq reads the narrative, every section it names is verified against `IndiaLaw.db` and dropped if it does not exist. Falls back to the old keyword matcher when Groq is down, and says which answered. See `features/08-section-suggestions.md` |
> | Citizen / Lawyer / Judge dashboards | Not started | The three roles still land on the "coming next" list. See §0.2 |
>
> **Police-console parity was audited twice.** The first pass was endpoint-driven and therefore incomplete:
> every route `templates/index.html` calls was covered, but five of the console's features call no route at
> all. Those are now built too — the legal glossary, the 2023 renumbering lookup, the four complaint counts
> and the tab badge, the complaints board (drawn vertically; see `features/05-complaints.md`), and the
> evidence locker's filter by kind of file.
>
> Two console functions are deliberately **not** built: `analyzeDocument` is a stub that prints a filename and
> says an analysis "would need backend processing", and the language switcher is commented out in its
> entirety. `/fir/view/<no>` is not called either — the app renders the record itself, which
> `features/04-fir-history.md` argues for.
>
> **Order note:** F8 and F10 were built before F3–F7, out of the suggested order below, on instruction — they
> are the police console's flagship and the thing filed against it. F8's one dependency that mattered
> (F12, for act/section lookup) was worked around: the act picker uses `GET /api/acts`, which is a flat list
> and needs none of F12's paging or search, and section numbers are typed. Browsing sections while filing
> arrives with F12.
>
> **F10's PIN now goes to the server.** It used to be compared in Dart against `INDIA@123` while the website
> used `secure@123`, so the handset and the console opened the same locker with two different strings. It is
> `POST /verify-locker-access` on both now. That bought parity, not safety: `/upload-evidence`,
> `/api/evidence`, `/get-all-evidence` and `/evidence-file/...` still have no session check at all, so the
> gate protects an unattended handset and not the evidence. Adding session checks to those four routes is
> the outstanding server-side fix.
>
> **Server changes made for the app** (in `website/`, all backwards-compatible with the website):
> - `require_same_origin` now admits a request carrying `X-NyayaAI-Client`. Without it every `POST` from the
>   app was **403 `{"error": "Request rejected."}`** — the app could not sign in at all. A custom header is a
>   real CSRF defence: a cross-origin page cannot set one without a preflight, and this server answers none.
> - `/api/predict-outcome` returns `results` alongside its `prediction` HTML, so a native client does not
>   have to scrape Tailwind markup.
> - Auth rate limits raised and made configurable (`SIGNUP_RATE_LIMIT`, `LOGIN_RATE_LIMIT`). They are keyed
>   on IP, and a police station is one IP; the old 5-per-hour signup ceiling was a station-wide ceiling.
> - FIR numbers containing `/` — the standard `41/2026` format — now work. Filing 500'd (the PDF write took
>   the number as a path) and lookup/download 404'd (the routes could not match a slash). Fixed with
>   `secure_filename` on the generated file and `<path:fir_no>` converters.
>
> **What the app reads that it did not before:** `pdf_url` (the server renamed `pdf_file` when PDF storage
> moved to Supabase — the app was reporting every FIR filed since as having no PDF), and `category` /
> `is_cognizable` on a complaint, which the website's board has always shown.
>
> **Decisions taken** (were open questions §0):
> - **Folder:** building in `NayayaAi_APP/flutter_app/`.
> - **Auth transport:** Flask session cookie via a persistent jar, behind a swappable seam
>   (`DioClient.clearSession`). No JWT.
> - **Base URL:** `--dart-define=API_BASE_URL`, defaulting to `http://10.0.2.2:5000` for the Android emulator.
> - **Judge/Lawyer data (§0.2):** still open. Not blocking anything until F13.

**Three server bugs found and fixed while building the section suggester** (all in `website/`, all
backwards-compatible):

- **The Law Library was broken for three of its eight acts.** `IndiaLaw.db`'s tables come from two sources
  and do not share a schema — IPC/CRPC/NIA/IEA/HMA use `section_title`/`section_desc`, while CPC/IDA/MVA use
  `title`/`description`. Every law route hardcoded the first shape, so `/api/sections/CPC`,
  `/api/section-detail/MVA/184` and friends answered **500 `no such column: section_title`**, and
  `/api/search-sections` silently skipped those three because its per-act failure is caught and continued
  past. **491 of the 1,968 sections were unreachable from both clients.** Fixed with an `ACT_COLUMNS` map and
  an `act_columns()` helper the three routes now share.
- **Ask NyayaAI could not answer about seven of the eight acts.** `search_law` answers exact-section
  questions out of `law_data.csv`, which is 84 IPC sections; anything else fell through to a semantic search
  over those same 84 rows and returned whichever was nearest in vector space. "What does CrPC 154 say" — the
  FIR-registration section, the single most relevant provision to a police officer — was unanswerable. It now
  falls back to `IndiaLaw.db` across all eight acts, and `extract_act` disambiguates a bare section number
  (there is a section 154 in IPC, CrPC, IEA, CPC and MVA).
- **Every Ask NyayaAI answer was labelled `📘 IPC Section N`.** True while the only corpus was IPC-only;
  false the moment the lookup above could reach CrPC and MVA. Now labelled with the act the row came from.

**Status:** The police console is at parity with the website's. Citizen, lawyer and judge are not built.
**Source studied (read-only):** `app.py` (1887 L), `missing_person.py`, `case.py`, `rag_engine.py`,
`ai_engine.py`, `face_recognition_helper.py`, `templates/*.html` (~9.4k L), `static/style.css`, `script.js`.
**Nothing in the website was modified.**

---

## 0. Before we start — 4 things I need decided

These change what gets built, so please answer them with the "Build Feature 1" instruction.

### 0.1 Target folder name

Your instructions say to work only inside `nayaayi_app/`. **That folder does not exist.** What exists is:

```
NayayaAi_APP/
├── flutter_app/     ← Flutter project (package name: nayaya_app) — 21 .dart files already present
├── backend/         ← empty scaffold (all .gitkeep)
├── database/        ← MySQL schema SQL files (users, roles, permissions, refresh_tokens, …)
├── deployment/      ← empty scaffold
└── docs/            ← this file
```

I am assuming **`NayayaAi_APP/flutter_app/`** is the intended target and have written only this doc so far.
Confirm, or tell me to rename/create `nayaayi_app/`.

### 0.2 The Judge and Lawyer dashboards have **no backend at all**

This is the single biggest finding. I grepped every `fetch()` call in both templates:

| Dashboard | Backend calls | Where the data actually lives |
|---|---|---|
| Judge | **zero** | `localStorage` keys: `nyayaai_docket`, `nyayaai_hearings`, `nyayaai_timelines`, `nyayaai_remands`, `nyayaai_efilings`, `nyayaai_deadlines`, `nyayaai_audit`, `nyayaai_signqueue`, `nyayaai_judge` |
| Lawyer | 3 (all AI drafting — excluded per your instructions) | `localStorage` key `nyaya_lawyer_state` |

So ~22 of the 36 features below (every Judge panel, every Lawyer panel) are **browser-local demo data**.
There is no server, no sync, no multi-device, no cross-user visibility. Three options:

- **(A) Mirror the website** — persist locally on-device (Drift/Isar). Fast, honest to current behaviour, but a
  judge's docket vanishes on reinstall and never reaches the lawyer who filed it. *Recommended for now.*
- **(B) Build real endpoints** in `NayayaAi_APP/backend/` (that folder + the MySQL schema in `database/`
  suggest this was already the plan). Correct long-term, but it is backend work outside the Flutter app and
  the website stays untouched either way.
- **(C) Defer** — build Features 1–12 (which *do* have a backend) and revisit Judge/Lawyer later.

**My recommendation: (C) then (B).** Ship the real, server-backed features first; do not invest mobile UI
effort in 22 screens of localStorage demo data until there is an API behind them.

### 0.3 Auth is session-cookie based, not token based

`login` sets a Flask server-side session (`session['user_id']`, `role`, `unique_id`, `fullname`) and returns a
`Set-Cookie`. There is **no JWT, no refresh token, no `/api/me` for the main app** (only the missing-persons
blueprint has `/api/me`). Your spec asks for a Token Manager + Authentication Manager.

Options: **(A)** Dio + `cookie_jar` persisting the Flask session cookie (works against the website as-is), or
**(B)** add JWT endpoints to the new backend (the `database/schema/refresh_tokens.sql` file implies this was
intended). I will build the auth layer with a `TokenStore` abstraction so either backs it without touching UI.
**Default if you don't answer: (A)**, so Feature 1 works against the running website today.

### 0.4 Base URL

Website runs at `http://localhost:5000` (debug). Android emulator needs `10.0.2.2:5000`. I will put this in a
build-time `--dart-define` with an emulator-friendly default unless you have a deployed host.

---

## 1. System understanding (what the website actually does)

**Stack:** Flask + Jinja templates + Tailwind CDN + vanilla JS. Two data stores, split oddly:

| Store | Holds |
|---|---|
| **MongoDB** | `users_collection`, `fir_collection` (FIRs), `evidence_collection` (evidence metadata) |
| **SQLite** `IndiaLaw.db` | Law section tables (`IPC`, `CRPC`, `NIA`, `IEA`, `HMA`, `CPC`, `IDA`, `MVA`), `citizen_complaints`, `missing_persons`, `missing_person_sightings` |
| **Filesystem** | `static/uploads/evidence/<fir_no>/`, `static/uploads/missing_persons/`, `static/uploads/sightings/`, `generated_firs/*.pdf` |

**Roles:** `citizen`, `police`, `lawyer`, `judge` (+ `admin` treated as police/judge in places).
Post-login redirect: citizen → `/citizen-dashboard`, judge → `/judge-dashboard`, lawyer → `/lawyer-dashboard`,
police → `/` (the FIR console, `index.html`).

**Signup ID rules (real validation, must be reproduced):**
- `police` / `lawyer` / `judge` → user **supplies** a unique ID that must start with `POL` / `LAW` / `JUD`
  (uppercased server-side) and must not already exist.
- `citizen` → server **auto-generates** `CIT###`.

**Role gates observed:** `_is_police()` = role in (`police`, `admin`, `officer`). Judge dashboard allows
(`judge`, `admin`). Sighting reporting requires any logged-in user. Missing-persons list is public.

---

## 2. Excluded — AI features (per your instructions)

Skipping entirely. Listed so nothing is silently lost.

| Endpoint / behaviour | What it is |
|---|---|
| `POST /api/rights-chat` | Citizen "Know Your Rights" chatbot (FAISS RAG → OpenRouter → keyword fallback) |
| `POST /api/ask-law` | Legal assistant Q&A |
| `POST /api/lawyer/draft-document` | Groq-generated legal drafts |
| `POST /api/lawyer/bail-draft` | Groq-generated bail applications |
| `POST /api/lawyer/find-precedents` | RAG precedent search |
| AI section suggestion inside `POST /generate_fir` | Auto-fills `act_sections` when left blank |
| Ollama half of `GET /api/search-sections` | LLM-suggested sections merged into DB results |
| Document Analysis panel (`index.html`) | AI document analysis UI |
| `ai_engine.py`, `rag_engine.py`, `law_vector_db/` | Supporting AI infrastructure |

**Three borderline cases — your call:**

1. `POST /api/predict-outcome` (**Case Outcome Predictor**) is labelled "AI-assisted" in the UI but `case.py`
   is a **pure keyword-scoring lookup over `case.csv`** — no LLM, no model, fully deterministic. Genuinely
   useful offline. *I suggest keeping it (F12b).*
2. **Face matching** in Missing Persons (`face_recognition_helper.py`, dlib) is server-side biometrics, not an
   LLM. The mobile app only uploads a photo and renders the returned confidence score. *I suggest keeping it* —
   the client work is a multipart upload, nothing AI.
3. Judge's **Verdict Assistant / Bail Risk Assessor / Precedent Finder / Sentencing Guide** are marketed as AI
   but are client-side template-fillers, a scoring calculator, and a static-array keyword filter respectively
   (`generateVerdict()`, `assessBailRisk()`, `findPrecedents()` — no network call). *Rule-based, not AI, but
   flagging since the UI calls them AI.*

---

## 3. Feature Inventory

Complexity: **S** ≈ 1 screen/simple form · **M** ≈ 2–3 screens + state · **L** ≈ multi-screen + upload/media ·
**XL** ≈ large sub-system.

### Foundation

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F0** | **App Foundation** | Not a user feature — the spine. GoRouter + auth redirect, Dio client + interceptors (cookie/token, logging, error mapping), `Failure`/`Result` error model, secure storage, Riverpod DI, env config, MD3 theme wired to existing `AppColors`, shared widgets, `flutter analyze` clean. | — | — | — | — | **M** |

### Authentication (all roles)

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F1** | **Sign Up / Sign In / Session** | Email+password auth. Signup enforces role-prefix unique-ID rules (§1). Session persisted; role decides landing route. Logout clears. Splash resolves session. | Splash *(built)*, Login *(UI built, no API)*, Signup, Role picker, Forgot-password stub | `POST /login`, `POST /signup`, `GET /logout` | Public | F0 | **M** |
| **F2** | **Social Login** | Google + GitHub OAuth. Web flow is a server redirect (`/auth/google` → callback → session). On mobile this needs native SDK + a token-exchange endpoint, or an in-app browser capturing the session cookie. **Backend work likely required — flag before scheduling.** | Login (buttons already designed) | `/auth/google`, `/auth/github` + callbacks | Public | F1 | **L** |

### Citizen

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F3** | **File a Complaint** | Citizen submits name, phone, incident description, date, location. Server returns `CMP-XXXXXXXX` tracking ID, status `Pending`. Validation: name + description required. | Citizen Home, Complaint Form, Success/Tracking-ID card | `POST /api/complaint` | Any (form is open) | F0, F1 | **S** |
| **F4** | **Track a Complaint** | Look up by tracking ID. Shows status, FIR no. if filed, officer notes, timestamps. 404 → "Check your tracking ID." Statuses: Pending / Under Review / FIR Filed / Closed. | Track form, Complaint Detail w/ status timeline | `GET /api/complaint/<tracking_id>` | Any | F3 | **S** |
| **F5** | **Emergency Contacts** | Tap-to-dial directory (100 Police, 112, 1091 Women, 1098 Child, 15100 Legal Aid) + legal-aid info cards. Pure client data — no API. | Emergency Contacts | — | Any | F0 | **S** |

### Missing Persons (shared citizen ↔ police)

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F6** ◐ | **Missing Persons — Public & Citizen** — *the sighting half is built; see `features/07-missing-persons.md`* | Public grid of active missing persons (photo, name, age, gender, last seen). Logged-in users report a sighting: camera/gallery photo + location + date → server face-matches and returns a confidence score. | Missing Persons List, Person Detail, Report Sighting (sheet) | `GET /get_missing_persons`, `POST /report_sighting/<person_id>`, `GET /api/me` | List public; sighting needs login (any role) | F1 | **L** |
| | | *Built inside the police console. The endpoints allow any signed-in role and the screens would work for a citizen, but there is no citizen dashboard to reach them from — the routes sit behind the police guard until there is.* | | | | | |
| **F7** ✅ | **Missing Persons — Police Console** — *built; see `features/07-missing-persons.md`* | Register a missing person (photo + details; server rejects photos with no detectable face), review all sightings per person with match scores, view confirmed matches grouped by person, update status Missing/Found/Closed. | Register Person, Sightings Review, Confirmed Matches, Status update | `POST /upload_missing_person`, `GET /get_sightings/<id>`, `GET /get_confirmed_matches`, `POST /update_missing_person_status/<id>` | **police / admin / officer only** | F6 | **L** |

### Police / Officer Console

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F8** ✅ | **FIR Registration** — *built; see `features/02-fir-registration.md`* | The website's flagship. FORM IF-1 is a 27-field statutory form; the app collects **nine** of them — FIR no, district, PS, FIR date · date and place of occurrence · complainant, acts & sections, narrative — and sends the other eighteen blank, so the stored record keeps its shape. Server rejects duplicate FIR numbers and generates a PDF. *(Originally built as a 4-step wizard over all 27; cut down on instruction — see the build log above.)* | FIR form (1 page), Receipt | `POST /generate_fir`, `GET /api/districts`, `GET /api/police-stations/<district>`, `GET /api/acts` | police | F0, F1 | **XL** |
| **F9** ✅ | **FIR History & Viewer** — *built; see `features/04-fir-history.md`* | Every FIR on record, newest first, searched client-side by number / complainant / station / section (the endpoint takes no query). One record rendered in FORM IF-1 order **in the app**, not by opening the server's `/fir/view` HTML page; blank entries hidden. The generated PDF is streamed to app-private storage and handed to the handset's viewer — a missing PDF is a normal outcome and says so. Read-only: the server has no update route. | FIR History, FIR Record viewer | `GET /api/fir-records`, `GET /api/fir-records/<fir_no>`, `GET /fir/download/<fir_no>` | police | F8 | **M** |
| **F10** ✅ | **Evidence Locker** — *built; see `features/03-evidence-locker.md`* | PIN-gated via **`POST /verify-locker-access`**, the same check the website makes (**not real auth either way — the four evidence endpoints have no session check at all**). Upload files against an existing FIR (rejected if the FIR doesn't exist), browse grouped by FIR with search, auto-categorised image/video/audio/pdf/other, image preview inline, access logging sent to a server-side stub. | Evidence tab → PIN gate → List → Add → Detail | `POST /upload-evidence`, `GET /api/evidence?fir_no=`, `GET /get-all-evidence`, `GET /evidence-file/<fir>/<name>`, `POST /api/evidence/log-access` | police | F8 | **L** |
| **F11** ✅ | **Complaints Inbox (Triage)** — *built; see `features/05-complaints.md`* | Officer side of F3/F4, built without them. Every citizen complaint newest-first, narrowed by stage (All · Active · Pending · Under review · FIR filed · Closed), by a **UTC** date window (today / yesterday / last 7 / last 30 / custom range) and by text over the tracking ID, name, phone, place, FIR number, narrative and notes — all client-side, because the endpoint takes no query, no page and no filter. **Respond** appends a stamped, signed note to `officer_notes` and sets the status; **Escalate** records a fixed destination and a required reason and marks it under review (nothing is routed — there is no assignee column and no notification); **Register an FIR** seeds the FIR form from the complaint and links the two when `/generate_fir` accepts the record. Every write sends all three desk columns, because the PATCH overwrites whatever it is not given. **No session check on any of these routes.** | Complaints tab → Inbox → Detail → Respond / Escalate sheets | `GET /api/complaints/all`, `GET /api/complaint/<tracking_id>`, `PATCH /api/complaints/<tracking_id>` | police | F0, F1, F8 (F3 not required) | **L** |
| **F12** ✅ | **Law Reference / Bare Acts** — *built; see `features/06-law-library.md`* | Browse 8 acts (IPC, CRPC, NIA, IEA, HMA, CPC, IDA, MVA). Paginated section list (20/page) with server-side search, section detail, **section comparison** (stacked rather than side by side — two columns of legal text do not fit a 390-point screen). Bare-act PDF links not built: `/open-bare-act/<code>` covers five acts the section tables do not, and a handset has nowhere useful to put a 3 MB statute. | Law tab → Library (act chips + both searches) → Section detail → Compare sheet | `GET /api/acts`, `GET /api/sections/<act>?search=&page=&limit=`, `GET /api/section-detail/<act>/<sec>`, `GET /api/search-sections?q=` (DB results only), `GET /open-bare-act/<code>` | Any logged-in | F0 | **M** |
| **F12b** ✅ | **Case Outcome Reference** — *built; see `features/06-law-library.md`* | Plain-language incident description → ranked relevant sections with punishment, sentencing range, cognizable/bailable badges, BNS equivalent. Deterministic CSV lookup, no LLM. *(The server returned only pre-rendered Tailwind HTML; `results` was added to the handler for this app rather than scraping it.)* Presented as "which sections apply", not as a prediction — there is no model and no case history behind it. | Law tab → Which sections apply | `POST /api/predict-outcome` | Any logged-in | F12 | **M** |

### Lawyer Dashboard — ⚠️ all localStorage, no backend (see §0.2)

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F13** | Case Docket | CRUD list of cases (title, court, client, sections, next date, status) | List, Add/Edit, Detail | none | lawyer | F0 + §0.2 | **M** |
| **F14** | Hearing Calendar & Deadlines | Calendar of hearings, upcoming-deadline widget on overview | Calendar, Add Hearing | none | lawyer | F13 | **M** |
| **F15** | e-Filing Manager | Track filings: case, court, type, date, status | List, Add Filing | none | lawyer | F13 | **S** |
| **F16** | Document Vault | Per-case document upload + list | Vault, Upload | none | lawyer | F13 | **M** |
| **F17** | Order Repository | Store court orders (case, date, court, summary) | List, Add Order | none | lawyer | F13 | **S** |
| **F18** | Client Portal | Client directory (name, phone, email, linked cases) | List, Add Client | none | lawyer | F13 | **S** |
| **F19** | Fee & Invoice Tracker | Invoices, amounts, paid/unpaid, totals | List, Add Invoice | none | lawyer | F13 | **M** |
| **F20** | Case Timeline | Chronological events per case | Timeline, Add Event | none | lawyer | F13 | **S** |
| **F21** | IPC → BNS Amendment Tracker | Static mapping of old IPC sections to new BNS equivalents | Mapping list + search | none | lawyer | F12 | **S** |

### Judge Dashboard — ⚠️ all localStorage, no backend (see §0.2)

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F22** | Judge Overview | Greeting, case stats, quick-access cards | Overview | none | judge/admin | F0 + §0.2 | **S** |
| **F23** | Case Docket | Judge's case list + detail | List, Detail | none | judge | F22 | **M** |
| **F24** | Hearing Scheduler | Schedule/reschedule hearings | Scheduler, Add | none | judge | F23 | **M** |
| **F25** | Case Timeline | Per-case chronology | Timeline | none | judge | F23 | **S** |
| **F26** | Charge Framing Tool | Build charges from sections | Form, Output | none | judge | F12, F23 | **M** |
| **F27** | Verdict Drafting *(rule-based template)* | Fills a verdict template from inputs | Form, Preview | none | judge | F23 | **M** |
| **F28** | Bail Risk Assessor *(rule-based scoring)* | Weighted-factor risk score | Form, Score | none | judge | F23 | **M** |
| **F29** | Precedent Finder *(static array filter)* | Keyword filter over a bundled precedent list | Search, Results | none | judge | — | **S** |
| **F30** | Sentencing Guide | Sentencing ranges by section | Lookup | none | judge | F12 | **S** |
| **F31** | Daily Order Sheet | Compose/list daily orders | List, Compose | none | judge | F23 | **M** |
| **F32** | Warrant & Summons Issuer | Generate warrants/summons | Form, Preview | none | judge | F23 | **M** |
| **F33** | Bail Order Generator | Generate bail orders w/ conditions | Form, Preview | none | judge | F28 | **M** |
| **F34** | Remand Extension Tracker | Track remand periods + expiry alerts | List, Add | none | judge | F23 | **M** |
| **F35** | Accused Profile Viewer | Accused details + case history | Profile | none | judge | F23 | **M** |
| **F36** | e-Filing Inbox & Response Tracker | Incoming lawyer filings + responses | Inbox, Detail, Responses | none | judge | F15 | **M** |
| **F37** | Pendency Dashboard | Case-age/pendency stats + charts | Dashboard | none | judge | F23 | **M** |
| **F38** | Audit Trail | Chronological action log | Log | none | judge | F22 | **S** |
| **F39** | Digital Signature Queue | Queue of documents awaiting signature | Queue, Sign | none | judge | F31 | **M** |

### Cross-cutting

| # | Feature | Description | Screens | APIs | Permissions | Depends on | Cx |
|---|---|---|---|---|---|---|---|
| **F40** | **Settings & Language** | Interface language + document language (website stores `nyaya_language`, `nyaya_document_language`), theme mode (light/dark/system — theme already supports both), notification prefs. | Settings | — | Any | F0 | **S** |
| **F41** | **Profile** | Name, email, role badge, unique ID, avatar, sign out. | Profile | session data | Any | F1 | **S** |

---

## 4. Suggested development order

Ordered by dependency and by *real backend exists → highest value first*.

**Phase 1 — Spine** (nothing ships without it)
1. **F0** App Foundation
2. **F1** Auth (login screen UI already exists — needs the data layer + signup + session)

**Phase 2 — Citizen loop** (smallest complete vertical slice; proves the whole stack end-to-end)
3. **F3** File Complaint → 4. **F4** Track Complaint → 5. **F5** Emergency Contacts

**Phase 3 — Law reference** (F8 depends on it)
6. **F12** Law Reference / Bare Acts *(→ optional **F12b**)*

**Phase 4 — Police core** (the product's centre of gravity)
7. ~~**F11** Complaints Inbox~~ — ✅ built, ahead of Phase 2 rather than after it. It was listed as depending on
   F3 because F3 is what fills the table; in practice the website's own citizen dashboard already does, so the
   police half stands on its own. F3 and F4 now arrive to a working officer side rather than the other way round.
8. ~~**F8** FIR Registration~~ — ✅ built (FORM IF-1, four steps + review)
9. ~~**F9** FIR History & Viewer~~ — ✅ built. It also unblocks the locker's last hand-typed identifier:
   `firHistoryProvider` can back an FIR picker on the evidence Add screen, which today asks for the number.
10. ~~**F10** Evidence Locker~~ — ✅ built

**Phase 5 — Missing Persons**
11. **F6** Citizen/public side → 12. **F7** Police side

**Phase 6 — Polish**
13. **F40** Settings · 14. **F41** Profile · 15. **F2** Social Login *(after the OAuth question in §0.3 is settled)*

**Phase 7 — Lawyer & Judge (F13–F39)** — *blocked on the §0.2 decision.* If (B), backend first. If (A), these
become local-persistence features and can start any time after F0.

**Why this order:** Phase 2 is the shortest path to a running, testable, server-backed app. F12 must precede F8
because the FIR form pulls acts and sections. F11 immediately after Phase 2 makes complaints demonstrable from
both sides. The 27 localStorage features are deliberately last — they are the largest block of work and the
least real.

---

## 5. Current state of `flutter_app/`

Already present (21 `.dart` files), so **F1's UI is roughly half-built**:

- `theme/` — `AppColors` (navy / blue / saffron palette, light + dark), `AppTheme`, `AppTypography`, `AppDimensions`
- `features/splash/` — splash screen + brand animation
- `features/authentication/` — **login screen UI only, no API integration**, plus auth header/divider/station-footer widgets
- `shared/widgets/` — primary/secondary buttons, text field, password field, justice crest
- `core/` — `validators.dart`, `start_destination.dart`; every other `core/` folder is an empty `.gitkeep`
- `test/` — widget + golden tests for splash and login (**note: `test/golden/failures/` contains failure diffs, so goldens are currently failing — I'll fix in F0**)
- `pubspec.yaml` — only `flutter_riverpod`. `dio`, `go_router`, `flutter_secure_storage`, `shared_preferences`,
  `image_picker`, etc. are commented out with a note to add each with the feature that needs it. F0 adds the first batch.

Missing entirely: routing, networking, DI, models, repositories, error handling, storage.

---

## 6. Open questions summary

| # | Question | My default if unanswered |
|---|---|---|
| 1 | Target folder — `NayayaAi_APP/flutter_app/` or create `nayaayi_app/`? | Use `NayayaAi_APP/flutter_app/` |
| 2 | Judge/Lawyer data — local-only (A), new backend (B), or defer (C)? | **(C) defer**, build Phases 1–6 first |
| 3 | Auth transport — Flask session cookie (A) or JWT on a new backend (B)? | **(A)** cookie jar, behind a `TokenStore` abstraction |
| 4 | API base URL / deployed host? | `http://10.0.2.2:5000` via `--dart-define` |
| 5 | Keep Case Outcome Predictor (F12b) and face matching (F6/F7)? | **Keep both** — neither uses an LLM |

---

**Discovery complete — stopping here as instructed. No Flutter code written.**
Say **"Build Feature 1"** (or **"Build F0"** — F1 needs the foundation, so I'd fold F0 in) to begin.

# Lawyer Side — Analysis D1–D7 (analysis only, no implementation)

**Audit date:** 2026-09-27.
**Governing rules:** Lawyer brief v2 §1. **Rule 0** applies: no changes to the website, Flask, the DB or templates. Backend gaps are documented (D6), never patched.
**Sources:**
- `website/templates/lawyer_dashboard.html` (**LD**, 1734 lines, read in full)
- `website/app.py` (**app**)
- `website/main/storage_service.py` (**SS**)
- `website/missing_person.py` (**MP**)
- `website/templates/login.html`, `signup.html`
- Flutter: `Application/NayayaAi_APP/flutter_app/lib/**`

Paths starting `lib/` are relative to `flutter_app/`.

> **Freshness check.** The website source has not changed since the Citizen audit. `app.py` was last modified 2026-09-20 01:00, before D1 (01:27). The only files under `website/` that are newer than D1 are `IndiaLaw.db` and one sighting upload. Line numbers in the Citizen D1–D4/D5P therefore still hold, and are reused here.

---

## Headline findings (read first)

1. **The website has a complete Lawyer portal.** It is one server-rendered page, `GET /lawyer_dashboard` (app:1079-1088), with:
   - 5 sidebar sections: Home, My Cases, Case Workspace, Legal Assistant, Drafts
   - a Profile modal
   - 22 lawyer-relevant endpoints
   - 3 Supabase tables used only by lawyers (`case_hearings`, `case_drafts`, `case_deadlines`), a storage bucket (`avatars`), and 5 lawyer columns on `firs`.
2. **"My Cases" has no JSON endpoint.**
   - The list is rendered server-side with Jinja: `get_firs_by_lawyer(session['user_id'])` → `render_template(..., cases=cases)` (app:1086-1088; LD:438-459).
   - The Home stats and the "Upcoming Hearings" strip are computed in JS **from the rendered cards** (LD:1423-1471).
   - Flutter cannot get this list from a lawyer endpoint. It *can* rebuild the same result from two existing endpoints: `GET /api/fir-records`, filtered on `assigned_lawyer_id == /api/me user_id`. This is decision **OQ-L1**.
3. **Two of the website's AI features fail with HTTP 500 whenever Groq answers successfully.**
   - In `lawyer_find_precedents`, the only `return` (app:1303) is indented inside `if not answer:`. When `ask_groq` returns text, the view returns `None`, and Flask then raises "view function did not return a valid response" → 500.
   - The endpoint backs both **Legal Assistant** (LD:1588) and the **AI Summary** tab (LD:1226). `GROQ_API_KEY` is present in `website/.env` (key name checked; value not read), so success is the normal path.
   - Code-verified. The live 500 is `UNVERIFIED — requires source confirmation` (runtime), because the server was not running during this audit.
4. **The Citizen `client-status` endpoint is confirmed as the read side of a Lawyer writer.**
   - Writer: `PATCH /api/case/<fir>/client-visibility` (app:2502-2517) → `set_client_visibility` (SS) sets `visible_to_client`, `client_note` and `client_note_updated_at`.
   - Reader: the public `GET /api/case/<fir>/client-status` (app:2520-2532), which Flutter's Citizen P-15 already calls.
   - The `status` that a citizen sees is written by the lawyer's `PATCH /api/case/<fir>/status` (app:2430-2442).
   - The `next_hearing_date` that a citizen sees is written as a side effect of the lawyer's `POST /api/case/<fir>/hearings` (app:2380-2383).
5. **Routing trap in Flutter.**
   - `AppRoutes.policePrefixes` contains `'/law'` (`lib/routes/app_routes.dart`), and the guard is `policePrefixes.any(location.startsWith)` (`lib/routes/app_router.dart`, step 5).
   - **Any route under `/lawyer/...` starts with `/law` and would be bounced to `/home` for a lawyer.**
   - Lawyer routes therefore need a prefix that does not begin with `/law` (proposed: `/advocate`). The alternative, making the Police guard segment-aware, would change a shared Police file (see D1 §3).
6. **Cross-role write.**
   - `PATCH /api/case/<fir>/status` overwrites `firs.status`, the same column Police sets to `"Saved to Police Records"` at filing (app:1911).
   - Police's `FirRecordScreen` shows it (`lib/features/fir/presentation/screens/fir_record_screen.dart:431`), and the judge dashboard reads `/api/fir-records` (judge_dashboard.html:497, 792).
   - A lawyer status change is therefore visible to Police and Judge. The website behaves the same way, so this is parity, not a regression. It is recorded so the regression test does not flag it as a Flutter bug.

---

## D1 — Flutter Architecture Delta

**Baseline reused unchanged:** `docs/audit/D1_flutter_architecture.md` (2026-09-20).
- Riverpod 2 with `Notifier`/`AsyncValue`, no codegen.
- Dio with a persistent cookie jar and the `X-NyayaAI-Client` header.
- GoRouter with a single redirect.
- Feature-first Clean Architecture.
- Hand-written `fromJson`.
- `ErrorMapper` → `Failure`.

Since then, Citizen work added:
- `lib/features/citizen/`;
- `url_launcher ^6.3.2` (`pubspec.yaml:97`);
- redirect step 6 plus `AppRoutes.citizenPrefixes`.

The test suite is now 515 tests (`.claude/plan/citizen_implementation_plan.md`, progress log).

### 1. Existing `lawyer` references in Flutter (complete grep of `lib/`, `test/`, `test_live/`)

| Where | What exists | Usable for Lawyer? |
|---|---|---|
| `lib/core/enums/user_role.dart` | `UserRole.lawyer('lawyer','Lawyer','LAW')`. It is in `registerable`, and `requiresUserSuppliedId` is true. `hasPoliceAccess` is false. `fromWire('lawyer')` → `lawyer`. | ✅ Complete. No change needed. |
| `lib/features/authentication/presentation/widgets/role_selector.dart:29` | Lawyer tile with icon `Icons.balance_outlined` | ✅ Sign-up already supports lawyer |
| `lib/features/authentication/presentation/screens/signup_screen.dart:27,80` | Unique-ID field for professional roles; clears a stale `POL` ID when the role switches to Lawyer | ✅ |
| `lib/core/utils/validators.dart:87` | Validates a role-prefixed unique ID (`LAW…`) | ✅ |
| `lib/features/dashboard/presentation/screens/role_home_screen.dart:48-56, 105-122` | A lawyer falls through to `_RoleHomeList`: an identity card plus a non-interactive "COMING NEXT" list ("Case docket", "Hearing calendar", "**Law library**") | ⚠️ Placeholder. This is the extension point. Note: **"Law library" is not a website Lawyer feature**. `/` redirects lawyers away from `index.html` (app:510-511), and LD has no law-library section. Do not build it. |
| `lib/features/citizen/**` (e.g. `case_client_status.dart`, `case_status_screen.dart`) | The citizen **reader** of lawyer-shared data | ✅ The Lawyer writer must stay wire-compatible (D3 §3) |
| `test/unit/auth_contract_test.dart:19-33,153-161`; `test/widget/features/fir_route_guard_test.dart:300`; `signup_screen_test.dart:57,94,163` | Lawyer wire value, prefix, session restore; **a lawyer is redirected away from `/fir`** | ✅ These tests must stay green |
| Models | **No** lawyer model. `FirRecord` (`lib/features/fir/domain/...`, parsed by `FirRecordResponse`, `fir_models.dart:132-170`) does **not** read `assigned_lawyer_id`, `visible_to_client`, `client_note`, `client_note_updated_at` or `next_hearing_date` | New lawyer-side parser needed. **Do not modify `FirRecordResponse`**: it is shared with Police. |
| `lib/features/profile/` | Empty scaffold (`.gitkeep` only) | Available, but see §4 |
| `database/schema/*.sql` | Not referenced by Dart or Flask (D1). No lawyer tables. | ❌ Irrelevant |

### 2. How role is determined today
- **`POST /login`** returns `role` (app:2096-2105). **`GET /api/me`** returns `role` + `user_id` (MP:116-133). `AuthRepositoryImpl.restoreSession` takes the role from the server.
- **Gap relevant to Lawyer:**
  - after a *fresh* `login()`, `AuthUser.userId` is **null**, because `/login` returns no `user_id` (`auth_repository_impl.dart:41-60`, `auth_user.dart`);
  - `fullName` is also absent unless it was cached at sign-up on this device.
  - The Lawyer layer needs `user_id` for OQ-L1, so it must call `GET /api/me` itself. It can also take its display name from `GET /api/lawyer/profile` → `fullname`.
  - Neither approach touches shared auth code.

### 3. Minimal extension points (identify only; not implemented)

| Extension point | File | Current Police/Citizen usage | Minimal Lawyer change | Shared? |
|---|---|---|---|---|
| Role branch | `role_home_screen.dart:48-56` | `hasPoliceAccess` → `PoliceDashboardScreen`; `citizen` → `CitizenShell`; else `_RoleHomeList` | Add `if (user.role == UserRole.lawyer) return const LawyerShell();`. Remove the lawyer case from `_plannedFor` (it returns `[]` as unreachable, as for citizen). Judge is unchanged. | **Yes — sign-off needed** |
| Route prefixes | `app_routes.dart` | `policePrefixes = [/fir, /evidence, /complaints, /law, /missing-persons]`; `citizenPrefixes = [/citizen]` | Add `lawyerPrefix = '/advocate'` + `lawyerPrefixes`. **It must not start with `/law`** (Headline 5). | **Yes** |
| Redirect | `app_router.dart` steps 5-6 | Police guard (step 5), citizen guard (step 6) | Add step 7: a path under `lawyerPrefixes` with `role != lawyer` → `/home`. Steps 1-6 are unchanged. | **Yes** |
| Endpoint constants | `lib/core/constants/api_endpoints.dart` | All server paths | Additive constants for the lawyer endpoints only | **Yes (additive)** |
| Dependencies | `pubspec.yaml` | — | Possibly a Markdown renderer (OQ-L2). `image_picker` (photo) and `url_launcher` already exist. | **Yes (additive)** |

### 4. Proposed folder
`lib/features/lawyer/{data/{datasources,models,repositories}, domain/{entities,repositories}, presentation/{controllers,screens,widgets}}`. This mirrors `lib/features/citizen/`, the precedent for a role shell with sections.

Reused **unchanged**:
- `EvidenceRepository.forFir` (`GET /api/evidence`)
- `evidenceFilePickerProvider` / `EvidenceSource` (camera/gallery for the profile photo)
- `AuthController.logout`
- shared widgets: `AppTextField`, `AppTextArea`, `PrimaryButton`, `SecondaryButton`, `FormBanner`, `StateMessage`, `AppPickerField`
- theme tokens
- `ServerTime`
- `FirNumber.label`

`lib/features/profile/` stays untouched, because lawyer profile endpoints are lawyer-only.

---

## D2 — Police / Citizen Regression Baseline

**Reused:** `docs/audit/D2_police_side_audit.md`, `.claude/spec/citizen_parity_spec.md` §7.

**Current state (re-run 2026-09-27):**
- `flutter analyze` → **No issues found**
- `flutter test` → see the result appended at the end of this section

Only the files the Lawyer work would touch are re-audited:

| Shared file | Police usage today | Citizen usage today | Lawyer change risk | Regression checks required |
|---|---|---|---|---|
| `role_home_screen.dart` | `hasPoliceAccess` branch → console | `citizen` branch → `CitizenShell` | Low: one new branch after the two existing ones | Police lands on the console, citizen on the shell, judge still on `_RoleHomeList` |
| `app_routes.dart` | `policePrefixes` | `citizenPrefixes` | Low if the prefix is `/advocate`. **High if `/lawyer/*` is used** (the police guard captures it). | `fir_route_guard_test.dart` (lawyer/judge kept off `/fir`); the citizen guard test; a new test that a lawyer can reach `/advocate/...` and police/citizen cannot |
| `app_router.dart` | step 5 | step 6 | Low: new step 7 only | Same as above |
| `api_endpoints.dart` | all police paths | citizen paths | None (additive) | Analyzer only |
| `pubspec.yaml` | — | `url_launcher` | Low (additive dependency) | Full `flutter test`; Android `assembleDebug` |
| Evidence data source (read-only reuse) | the locker uses `forFir` | — | None (consumed, not modified) | Evidence tests unchanged |

**Server-side cross-role effects** (parity behaviour, not Flutter regressions; record them in the regression report):
- a lawyer status change replaces Police's `"Saved to Police Records"` on the Police FIR record screen;
- a lawyer's client share changes what Citizen P-15 returns: 404 → 200.

**Baseline test result (2026-09-27):**
- `flutter analyze`: No issues found.
- `flutter test`: **522 passed, 0 failed** ("All tests passed!").

The plan's log recorded 515. The later count is the current baseline, and every Lawyer step must keep it green.

The live suites (`test_live/`) were **not** run, because the Flask server was not reachable (`/health` → no connection).

---

## D3 — Backend Delta Audit (Lawyer-relevant only)

Citizen D1/D4 already cover `firs` (Supabase) and `client-status`. Only the new material is listed here.

### 1. Stores used only or mainly by Lawyer

| Store | Table / bucket | Columns written by code (SS) | Readers | Schema in repo? |
|---|---|---|---|---|
| Supabase | `firs` (lawyer columns) | `assigned_lawyer_id` (SS `assign_lawyer_to_fir`), `status` (`update_fir_status`), `next_hearing_date` (`update_next_hearing_date`), `visible_to_client`, `client_note`, `client_note_updated_at` (`set_client_visibility`) | lawyer endpoints, `client-status`, `/api/fir-records*` (`select *`) | **No** DDL anywhere in the repo. Existence and types are `UNVERIFIED — requires source confirmation`. |
| Supabase | `case_hearings` | `fir_no, hearing_date, note` (+ `id`, `created_at`?) | hearings GET (ordered by `hearing_date`) | No DDL. `id`/`created_at` presence is `UNVERIFIED`. |
| Supabase | `case_drafts` | `fir_no, kind, content`; reads `id`, `created_at` (ordered by `created_at desc`) | drafts GET, lawyer/drafts | No DDL. The route `<int:draft_id>` implies an integer `id`. |
| Supabase | `case_deadlines` | `fir_no, deadline_type, due_date, note, completed` | deadlines GET, lawyer/deadlines | No DDL. The route `<int:deadline_id>` implies an integer `id`. |
| Supabase Storage | bucket `avatars` | `<user_id><ext>`, upsert, content-type forced to `image/jpeg` (SS `upload_profile_photo`) | public URL saved to Mongo `users.photo_url` | `UNVERIFIED` |
| Mongo | `users` extra fields | `phone, office_address, bio, years_experience, bar_enrollment_no, practice_area, photo_url` (app:2555-2594) | `/api/lawyer/profile` | Schemaless |

### 2. Endpoints whose role check permits `lawyer`

All use the inline check `if 'user_id' not in session or session.get('role') != 'lawyer': 401`.
- **Ownership** (✔O) means `lawyer_owns_case(fir_no)` is also applied (app:304-309): `str(fir.assigned_lawyer_id) == str(session.user_id)` → otherwise 403.
- **None** of these endpoints uses `@require_same_origin`, so Flutter needs no extra header beyond what it already sends.

| # | Method + path | Lines | Auth | Request | Response (success / error) |
|---|---|---|---|---|---|
| E1 | `GET /lawyer_dashboard` | 1079-1088 | session + lawyer, else redirect | — | **HTML** (Jinja: `cases`, `lawyer.name`). Not usable by Flutter. |
| E2 | `POST /api/fir-records/<fir_no>/assign-lawyer` | 1696-1703 | lawyer (no ownership, **no check for an existing assignee**) | none | 200 `{message:"Case added to your dashboard", fir_no}`; 404 `{error:"FIR not found"}`; 401 |
| E3 | `GET /api/case/<fir>/hearings` | 2356-2362 | lawyer ✔O | — | 200 `[{…row}]` (by date asc); 403 `{error:"Forbidden"}` |
| E4 | `POST /api/case/<fir>/hearings` | 2364-2385 | lawyer ✔O | `{hearing_date, note}` | 201 `{message:"Hearing added"}`; 400 `{error:"Hearing date required"}`. **Side effect:** sets `firs.next_hearing_date` to the earliest hearing ≥ today. |
| E5 | `GET /api/case/<fir>/drafts` | 2387-2393 | lawyer ✔O | — | 200 `[{id, fir_no, kind, content, created_at}]` (newest first) |
| E6 | `POST /api/case/<fir>/drafts` | 2395-2407 | lawyer ✔O | `{kind, content}` | 201 `{message:"Draft saved", id}`; 400 `{error:"Draft content required"}` |
| E7 | `DELETE /api/case/<fir>/drafts/<int:id>` | 2409-2416 | lawyer ✔O | — | 200 `{message:"Draft deleted"}` (also when nothing matched) |
| E8 | `GET /api/lawyer/drafts` | 2418-2425 | lawyer | — | 200 drafts across all of the lawyer's FIRs (newest first) |
| E9 | `PATCH /api/case/<fir>/status` | 2428-2442 | lawyer ✔O | `{status}` ∈ `Investigation, Court Proceedings, Trial, Closed` | 200 `{message:"Status updated", status}`; 400 `{error:"Invalid status"}`; 404 |
| E10 | `GET /api/case/<fir>/deadlines` | 2450-2456 | lawyer ✔O | — | 200 `[{id, fir_no, deadline_type, due_date, note, completed}]` (due asc) |
| E11 | `POST /api/case/<fir>/deadlines` | 2458-2471 | lawyer ✔O | `{deadline_type, due_date, note}` | 201 `{message:"Deadline added", id}`; 400 `{error:"Deadline type and due date are required"}`. `DEADLINE_TYPES` (app:2445) is **declared but not enforced**. |
| E12 | `PATCH /api/case/<fir>/deadlines/<int:id>` | 2473-2482 | lawyer ✔O | `{completed}` | 200 `{message:"Deadline updated"}` |
| E13 | `DELETE /api/case/<fir>/deadlines/<int:id>` | 2484-2491 | lawyer ✔O | — | 200 `{message:"Deadline deleted"}` |
| E14 | `GET /api/lawyer/deadlines` | 2493-2500 | lawyer | — | 200 incomplete deadlines due ≤ today+14 (overdue included), across the lawyer's FIRs (SS `get_upcoming_deadlines_for_firs`) |
| E15 | `PATCH /api/case/<fir>/client-visibility` | 2502-2517 | lawyer ✔O | `{visible, note}` | 200 `{message:"Updated", visible}`; 404; 500 `{error:"Could not save. Check server logs."}` |
| E16 | `GET /api/lawyer/profile` | 2535-2553 | lawyer | — | 200 `{fullname, email, unique_id, phone, office_address, bio, years_experience, bar_enrollment_no, practice_area, photo_url}`; 404 |
| E17 | `PATCH /api/lawyer/profile` | 2555-2565 | lawyer | any subset of the 6 editable fields | 200 `{message:"Profile updated"}`; 400 `{error:"No fields to update"}`. **No server-side validation** of phone/years. |
| E18 | `POST /api/lawyer/profile/photo` | 2567-2589 | lawyer | multipart `photo` | 200 `{message:"Photo updated", photo_url}`; 400 `{error:"No photo provided"}`; 500 `{error:"Upload failed"}` |
| E19 | `POST /api/lawyer/draft-document` | 1143-1175 | lawyer | `{prompt}` | 200 `{text}` (Groq, falling back to the RAG template `generate_rag_document_lawyer` app:1467); 400 `{error:"Prompt required"}` |
| E20 | `POST /api/lawyer/bail-draft` | 1178-1210 | lawyer | `{prompt}` | same as E19 |
| E21 | `POST /api/lawyer/find-precedents` | 1214-1303 | lawyer | `{query, type}` (`laws`/`outcome`; the website sends only `laws`) | **Groq success → returns `None` → HTTP 500 (HTML).** Groq failure → 200 `{answer}` (RAG list or "No matching legal sections found…"). 400 `{answer:"Please enter a search query."}`. |

Public endpoints the lawyer UI also calls, with no role check:

| # | Endpoint | Lines | Used by |
|---|---|---|---|
| E22 | `GET /api/fir-records/<path:fir_no>` | 1722-1734 | Workspace Overview (LD:878). Flutter already calls it (`FirRemoteDataSource.record`). |
| E23 | `GET /api/evidence?fir_no=` | 2198-2232 | Documents tab (LD:1009). Flutter already calls it (`EvidenceRemoteDataSource.forFir`). |
| E24 | `GET /evidence-file/<fir>/<filename>` | 2191-2196 | Documents "VIEW" |
| E25 | `GET /api/fir-records` | 1711-1719 | **Not called by LD.** Candidate source for OQ-L1. Flutter already calls it (Police history). |
| E26 | `GET /api/case/<fir>/client-status` | 2520-2532 | Citizen reader of E9/E4/E15. Flutter Citizen already calls it. |

Auth and session endpoints shared with the other roles:
- `POST /signup`: role `lawyer`; `unique_id` required and must start with `LAW` (app:2011-2024)
- `POST /login`
- `GET /logout`
- `GET /api/me`
- `/` redirects a lawyer to `/lawyer_dashboard` (app:510-511)

Note: `/login`'s JSON `redirect` for a lawyer is `"/lawyer-dashboard"` (app:2103), and **that route does not exist**. It is harmless: `login.html:498-499` ignores it and navigates to `/lawyer_dashboard`. Flutter also ignores `redirect` (`app_routes.dart` header comment).

### 3. The Citizen pairing (explicit, per brief §5)

| Citizen reads (`client-status`) | Written by lawyer via |
|---|---|
| `visible_to_client` gate | E15 `{visible:true/false}` |
| `client_note`, `client_note_updated_at` | E15 `{note}` (the timestamp is set server-side on every E15 call, including "Stop sharing") |
| `status` | E9 (or Police's `"Saved to Police Records"` if the lawyer never changed it) |
| `next_hearing_date` | a side effect of E4 |

The Citizen `CaseClientStatus.fromJson` (`lib/features/citizen/data/models/case_client_status.dart`) already parses all five fields. **No citizen change is needed.**

### 4. Other backend findings
- **Case routes use the default `<fir_no>` converter.** E2–E15 cannot match an FIR number containing `/`, which `FIR_NO_RE` (app:229) permits. Flutter's `Uri.encodeComponent` produces `%2F`, which the WSGI layer decodes before routing. Low impact: D1/D2 note that `/generate_fir` already fails for such numbers.
- **E2 lets any lawyer take over any FIR.** The update does not check an existing `assigned_lawyer_id`, and drafts, deadlines and hearings are keyed by `fir_no`, so the new lawyer inherits them all.
- E22/E23/E24 are public (D1 S6). A lawyer's Overview and Documents need no ownership.

---

## D4 — Website Lawyer Feature Extraction

Line refs are into `lawyer_dashboard.html` (LD) unless noted. The page has a hover/slide sidebar (LD:24-38, 213-265) and a mobile menu button (LD:267-269, 1398-1410).

**Shell (LD:216-284):**
- Sidebar: "NyayaAI" / "Lawyer Portal"
- 5 links: Home · My Cases · Case Workspace · Legal Assistant · Drafts
- Footer: avatar initial + name (`lawyer.name` = `session.fullname`), which opens the Profile modal
- Top bar: "NyayaAI" + a "Lawyer" badge + "Sign out" (`/logout`)
- `showSection(id)` (LD:1374-1386) hides and shows sections (state preserved) and loads global drafts when entering `drafts`.

### 4.1 Home (`#home`, LD:287-393)
- **Hero:**
  - Badge "Powered by NyayaAI · Lawyer Portal"
  - "Welcome back, {name}."
  - Subtitle "Manage your cases, get practice guidance, and draft documents — all from one place."
  - Button **View My Cases** → `showSection('my-cases')`
- **Stat cards** (LD:324-341): Total Cases (`cases|length`), Investigation, Court Proceedings, Hearings This Week.
  - Computed client-side by `computeStatsAndHearings` (LD:1423-1471) from the card `data-status` / `data-hearing`.
  - Only the `investigation` and `court-proceedings` statuses are counted.
  - A hearing counts if `now ≤ new Date(next_hearing_date) ≤ now+7d`.
  - ⚠️ Quirk: a date-only string parses as UTC midnight, so a hearing *today* is usually `< now` and is excluded.
- **Quick actions** (LD:344-368):
  - View My Cases
  - Add a Case (switches to My Cases and focuses the claim input)
  - Legal Assistant
- **Upcoming Hearings** (LD:371-380):
  - One row per case whose `next_hearing_date` is within 7 days, as "FIR: {no}" plus the date, sorted ascending
  - Empty text: "No upcoming hearings scheduled."
  - **Not tappable.**
- **Upcoming Deadlines** (LD:382-390, `loadHomeDeadlines` LD:1168-1205):
  - Data: `GET /api/lawyer/deadlines` (E14), fetched once on page load (LD:1413)
  - Loading text: "Loading…"
  - Empty text: "No deadlines due in the next 14 days."
  - Error text: "Could not load deadlines."
  - Rows show "FIR: {no}", the type and the date; overdue rows (`due_date < today`) are red with " — OVERDUE"
  - **Tap → `openCaseWorkspace(fir_no)`**

### 4.2 My Cases (`#my-cases`, LD:396-463)
- **Search** "Search FIR no., client name…" (LD:401, 1415-1420). Filters cards by `innerText` containing the query, which covers FIR no., status, client, sections and next hearing.
- **Add a Case** (LD:405-416, `claimCase` LD:1478-1517):
  - Placeholder "Enter FIR number (e.g. FIR0008)"; Enter or the button submits
  - Empty input → red "Enter an FIR number."
  - While sending, the button shows "Adding…" and is disabled
  - Call: `POST /api/fir-records/{enc(fir)}/assign-lawyer` (E2)
  - Error → red `data.error` or "Could not add case."; network error → "Something went wrong. Please try again."
  - Success → green "Case added. Refreshing…", then **a page reload** after 700 ms
- **Stat cards:** same four as Home (LD:418-435).
- **Case cards** (LD:437-459):
  - "FIR: {fir_no}"; status pill `status or 'Active'` (colours LD:58-77: investigation amber, court-proceedings blue, trial red, saved-to-police-records/active green; closed has no colour); "Client: {complainant_name}"; "Sections: {act_sections}"; "Next Hearing: {next_hearing_date or '—'}"
  - Tap → `openCaseWorkspace`
  - Empty: "No cases yet. Add one above using an FIR number."
- **Data:** server-rendered (E1). There is **no JSON call.**

### 4.3 Case Workspace (`#case-workspace`, LD:546-748)
- **Empty state** (LD:550-554): "Select a case from **My Cases** to open its workspace." The link goes to My Cases.
- **`openCaseWorkspace(fir)`** (LD:841-859):
  - resets the summary and draft output;
  - switches to the Overview tab;
  - loads, in sequence: Overview (E22), Documents (E23), Hearings (E3), Deadlines (E10), Drafts (E5).
- **Header:** "← My Cases"; "FIR: {no}"; "Client: {complainant_name|—}"; status pill; **status `<select>`** "Change status…" with the 4 statuses (LD:573-580).
- **Tabs:** Overview · AI Summary · Documents · Hearings · Deadlines · Drafts.

| Tab | UI | Actions → API | States / messages |
|---|---|---|---|
| **Status change** (header) | select | `cwUpdateStatus` (LD:903-937) → E9 `{status}` | "✓ Updated" (green, hidden after 2 s), then the select resets. Error: `data.error` or "Could not update status." / "Something went wrong." **The My Cases card is not refreshed** (server-rendered). |
| **Overview** (LD:602-647) | District, Police Station, FIR Date, Occurrence Date, Act/Sections, Accused Details, Narrative (all `|| '—'`) | `cwLoadOverview` (LD:876-901) → E22 | Errors only go to `console.error`; there is no UI. |
| **Message to client** (LD:623-646) | "Message to client"; helper text; badge "Visible to client" (green) / "Not shared" (grey); textarea prefilled with `client_note`; **Send to Client**; **Stop sharing with client** (shown only when visible) | `cwSendToClient` (LD:939-964) → E15 `{visible:true, note}`; `cwStopSharing` (LD:966-989) → E15 `{visible:false, note}` | "Sending…" → "✓ Sent — visible to client now." / "Could not send. {err}"; "✓ Hidden from client." / "Could not update." The note may be empty. |
| **AI Summary** (LD:652-664) | "Generate Case Summary" | `cwGenerateSummary` (LD:1207-1240) → **E21** `{query:<composed from fir_no, act_sections, details_of_accused, statement[:500] + fixed instructions>, type:'laws'}` | Button disabled + "Thinking…". Result `answer` rendered as **Markdown** (`marked.parse`); "No summary returned." Error: "Something went wrong generating the summary." (**this is what users see on the E21 500**) |
| **Documents** (LD:667-674) | "Pulled from the Evidence Locker for this FIR." A grid of filename, category and **VIEW** (opens `file_url` in a new tab) | `cwLoadDocuments` (LD:1005-1028) → E23; VIEW → E24 | Empty: "No documents uploaded for this case yet." Errors go to the console only. |
| **Hearings** (LD:677-690) | date input; "Note (optional)"; **Add**; list of date + note | `cwLoadHearings` (LD:1030-1052) → E3; `cwAddHearing` (LD:1054-1074) → E4, then reload | No date → silently does nothing. Empty: "No hearings scheduled yet." Errors go to the console only. **No edit/delete exists.** |
| **Deadlines** (LD:693-714) | type select (6: Chargesheet Filing, Bail Application, Appeal Limitation, Revision Petition, Discharge Application, Custom); date; "Note (optional)"; **Add**; rows with a checkbox, type, date, note and **DELETE** | `cwLoadDeadlines` (LD:1076-1118) → E10; `cwAddDeadline` (LD:1120-1141) → E11; `cwToggleDeadline` (LD:1143-1155) → E12; `cwDeleteDeadline` (LD:1157-1165) → E13 (**no confirm**) | Completed rows are struck through and faded; overdue incomplete rows are red with " — OVERDUE". No date → does nothing. Empty: "No deadlines tracked yet." |
| **Drafts** (LD:717-745) | **Bail Application** / **General Document** buttons; "Drafting…"; result (Markdown); **Save Draft** (after generation only); "Saved Drafts" list: kind (capitalised) + raw `created_at` + **VIEW** / **DELETE** | `cwGenerateDraft` (LD:1245-1282): bail → E20 with prompt `Accused:…\nCourt: SESSIONS COURT\nFIR:…\nSection Charged:…\nGrounds: First-time offender, investigation complete`; general → E19 with `Draft a legal document based on FIR … Sections: … Facts: {statement[:500]}`. `cwSaveDraft` (LD:1284-1305) → E6 `{kind:'bail'|'document', content}`. `cwLoadDrafts` (LD:1307-1335) → E5. `cwViewDraft` shows content in the result area and hides Save. `cwDeleteDraft` → E7 (**no confirm**). | "No draft returned."; "Something went wrong generating the draft."; "✓ Draft saved." / "✗ Could not save draft."; empty: "No saved drafts for this case yet." |

### 4.4 Legal Assistant (`#legal-assistant`, LD:466-514, `askLegalAssistant` LD:1574-1605)
- Heading "Legal Assistant"; subtitle "Ask about practice, procedure, and drafting — …".
- Textarea (4 rows) with placeholder "e.g. When should I raise an objection…".
- 4 chips that fill the query and ask at once (LD:477-492):
  - "How do I file a Vakalatnama?"
  - "When should I raise an objection during cross-examination?"
  - "What is the format and procedure for a bail application?"
  - "What is a caveat and how do I file one?"
- **Ask** → E21 `{query, type:'laws'}`. An empty query does nothing.
- While waiting: "Thinking…" spinner; the button is disabled; the previous answer is hidden.
- The answer card is headed "Answer" and rendered as **Markdown** (headings, lists, tables, code, hr; styles LD:117-198). Empty answer → "No results found."; error → "Something went wrong. Please try again."
- **There is no history.** Each answer replaces the last.

### 4.5 Drafts (global) (`#drafts`, LD:518-543, `loadGlobalDrafts` LD:1520-1566)
- Loads on every entry (LD:1385), with "Loading drafts…".
- Data: E8.
- Rows: "FIR: {no}", kind, raw `created_at`, **VIEW** (preview card "Draft Preview" with CLOSE, Markdown) and **OPEN CASE** (opens the Workspace).
- Empty: "No drafts saved yet. Open a case's workspace to generate and save one."
- Error: "Something went wrong loading drafts."
- There is **no delete** here.

### 4.6 Profile modal (LD:751-832, JS LD:1607-1731)
- Opened by tapping the sidebar name/avatar. It closes on ×, or on a tap outside the modal.
- **Load:** E16. On a non-OK response it silently leaves the fields blank.
- **Read-only fields:** Name, Unique ID, Email.
- **Editable fields:**
  - Phone: digits only, max 10
  - Years of Experience: number, 0-60, max 2 digits
  - Office Address
  - Bar Enrollment No. (placeholder "MAH/1234/2020")
  - Practice Area (placeholder "Criminal Law")
  - Bio (2 rows)
- **Save** (`saveProfile`, LD:1680-1727). Client validation:
  - phone empty or exactly 10 digits, else "Phone number must be exactly 10 digits."
  - years empty or an integer ≤ 60, else "Years of experience must be a number up to 60."
  - Then E17 with **all 6 fields**, showing "Saving…" → "✓ Profile saved." (hidden after 2 s) / "Could not save. Try again."
- **Photo:**
  - "Change Photo" opens a file input with `accept=image/*`; the upload starts immediately (E18, field `photo`)
  - Messages: "Uploading…" → "✓ Photo updated." / "Upload failed."
  - The avatar (modal + sidebar) shows the photo, or else the initial.
  - ⚠️ The sidebar avatar only switches to the photo **after the modal has been opened**. The initial page shows the initial.

### 4.7 Auth entry points (shared pages)
- **Sign-up (`signup.html`):**
  - 4 role tiles including ⚖️ Lawyer (374-376)
  - Unique ID field shown for professional roles, hint "Lawyer: LAWxxx" (393-399, 457-473)
  - Server rules: app:2011-2024
- **Login (`login.html`):** lawyer → `/lawyer_dashboard` (498-499).
- "Forgot password?" is the shared dead link (Citizen limitation L3). It is **not** a Lawyer-specific feature.

### 4.8 Confirmed absent from the website Lawyer experience (do NOT build)
- law library / section browser
- Ask-Law RAG screen
- outcome finder
- an `outcome` search mode (the backend supports `type:'outcome'`, but no UI sends it)
- hearing edit/delete
- draft editing
- draft delete from the global list
- client list or messaging threads
- notifications
- document upload by the lawyer
- FIR creation
- un-claiming a case
- calendar view
- judge docket

---

## D5 — Master Lawyer Feature Inventory

Status legend is as in brief §6.
- **A** = reusable with no server change.
- **A (none)** = no endpoint needed.
- **B** = exists but needs a server change for parity or DoD. Per Rule 0, it becomes a **limitation**.
- **C** = does not exist.

"Flutter today" = whether any Flutter code calls that endpoint now.

| # | Lawyer Feature | Website Route | Components | User Actions | API/Backend | Flutter calls it today? | Data Model | Flutter Screen (proposed) | Status | Priority |
|---|---|---|---|---|---|---|---|---|---|---|
| L-1 | Lawyer registration | `/signup` | signup.html role tile + Unique ID | pick Lawyer, enter `LAW…` ID | `POST /signup` | **Yes** | `SignupRequest` | existing `signup_screen.dart` (no change) | **A** | High |
| L-2 | Lawyer login | `/login` | login.html | sign in | `POST /login` | **Yes** | `AuthUser` | existing `login_screen.dart` | **A** | High |
| L-3 | Session restore + role routing | `/` → `/lawyer_dashboard` (app:510, 1079-1084) | server redirect | — | `GET /api/me` | **Yes** | `SessionResponse` | `role_home_screen.dart` lawyer branch → `LawyerShell`; router step 7 with prefix `/advocate` | **A** | High |
| L-4 | Logout | top bar "Sign out" | LD:281-283 | sign out | `GET /logout` | **Yes** | — | `AuthController.logout` (sign-out confirmation style: OQ-L6) | **A** | High |
| L-5 | Portal shell (5 sections + top bar badge + profile entry) | `/lawyer_dashboard` | LD:216-284, `showSection` | switch section | — | n/a | — | new `lawyer_shell.dart` (Drawer + `IndexedStack`, like `CitizenShell`) | **A (none)** | High |
| L-6 | Home: hero + 4 stat cards | `#home` | LD:287-341, 1423-1457 | "View My Cases" | the case list (see L-10); name from E16 `fullname` or the cache | No | `LawyerCase` (new) | new `lawyer_home_screen.dart` | **A** via composition (depends on OQ-L1) | High |
| L-7 | Home quick actions | `#home` | LD:344-368 | 3 shortcuts ("Add a Case" focuses the claim field) | — | n/a | — | part of L-6 | **A (none)** | Medium |
| L-8 | Home upcoming hearings (≤ 7 days, from `next_hearing_date`) | `#home` | LD:371-380, 1459-1470 | view only | derived from the L-10 data | No | `LawyerCase.nextHearingDate` | part of L-6 | **A** via composition (today-exclusion quirk: OQ-L6) | Medium |
| L-9 | Home upcoming deadlines (≤ 14 days + overdue), tap → workspace | `#home` | LD:382-390, 1168-1205 | open case | E14 `GET /api/lawyer/deadlines` | No | `CaseDeadline` (new) | part of L-6 | **A** | High |
| L-10 | My Cases list + client-side search + stats + empty state | `#my-cases` | LD:396-463, 1415-1420 | search, open case | **No JSON endpoint** (E1 is HTML). Composition: E25 `GET /api/fir-records` filtered by `assigned_lawyer_id == GET /api/me user_id`, which is the same predicate as SS `get_firs_by_lawyer` | E25 **yes** (Police history); `/api/me` **yes** | `LawyerCase` (new parser over the `firs` row) | new `my_cases_screen.dart` | **C** for a dedicated endpoint (D6 G1); **A-composable** pending OQ-L1 | High |
| L-11 | Add (claim) a case by FIR number | `#my-cases` | LD:405-416, 1474-1517 | type FIR, submit | E2 `POST /api/fir-records/<fir>/assign-lawyer` | No | `{message, fir_no}` | in `my_cases_screen.dart`; refresh the list instead of reloading the page | **A** for parity; **B** for DoD (takeover, `/` in FIR: D6 G3, G4) → limitation | High |
| L-12 | Case Workspace shell (empty state, header, back, 6 tabs) | `#case-workspace` | LD:546-599, 841-874 | open, switch tabs | — | n/a | — | new `case_workspace_screen.dart` (pushed route `/advocate/case/:firNo`, `TabBar`) | **A (none)** | High |
| L-13 | Overview (FIR facts) | Workspace › Overview | LD:602-621, 876-901 | view | E22 `GET /api/fir-records/<fir>` | **Yes** (Police `FirRemoteDataSource.record`), but `FirRecord` lacks the lawyer fields | `LawyerCaseDetail` (new parser; `FirRecordResponse` untouched) | Overview tab | **A** | High |
| L-14 | Change case status (4 values) | Workspace header | LD:573-580, 903-937 | pick status | E9 `PATCH /api/case/<fir>/status` | No | `{status}` | header control | **A**. Cross-role: overwrites the Police status (Headline 6). | High |
| L-15 | Message to client / share toggle | Workspace › Overview | LD:623-646, 939-1003 | Send to Client, Stop sharing | E15 `PATCH /api/case/<fir>/client-visibility` | No. **Pairs with Citizen P-15 `client-status` (E26), which Flutter already calls.** | `{visible, note}` | Overview tab card | **A** (overlap with Citizen: D3 §3) | High |
| L-16 | AI case summary | Workspace › AI Summary | LD:652-664, 1207-1240 | Generate | E21 `POST /api/lawyer/find-precedents` | No | `{answer}` (Markdown) | Summary tab | **B**: 500 on Groq success (D6 G2) → limitation; the website shows "Something went wrong generating the summary." | Medium |
| L-17 | Case documents (from the evidence locker) + view | Workspace › Documents | LD:667-674, 1005-1028 | VIEW file | E23 `GET /api/evidence?fir_no=`, E24 `/evidence-file/...` | **Yes** (Police `EvidenceRemoteDataSource.forFir`) | existing `EvidenceItem` | Documents tab (viewer: OQ-L4) | **A** | Medium |
| L-18 | Hearings list + add | Workspace › Hearings | LD:677-690, 1030-1074 | add date + note | E3, E4 | No | `CaseHearing` (new) | Hearings tab | **A** | High |
| L-19 | Deadlines list/add/complete/delete + overdue | Workspace › Deadlines | LD:693-714, 1076-1165 | add, toggle, delete | E10–E13 | No | `CaseDeadline` | Deadlines tab | **A** | High |
| L-20 | Draft generation (bail / general) + save + saved list view/delete | Workspace › Drafts | LD:717-745, 1242-1352 | generate, save, view, delete | E19, E20, E5, E6, E7 | No | `CaseDraft` (new), `{text}` | Drafts tab | **A** (E19/E20 return correctly, with a template fallback) | High |
| L-21 | Legal Assistant (Q&A + 4 chips) | `#legal-assistant` | LD:466-514, 1569-1605 | ask, tap chip | E21 | No | `{answer}` (Markdown) | new `legal_assistant_screen.dart` | **B**: same defect as L-16 (G2) → limitation | High |
| L-22 | All drafts across cases (view, open case) | `#drafts` | LD:518-543, 1520-1566 | view, open case | E8 `GET /api/lawyer/drafts` | No | `CaseDraft` | new `all_drafts_screen.dart` | **A** | Medium |
| L-23 | Profile view/edit (+ client validation) | Profile modal | LD:751-832, 1607-1637, 1680-1731 | edit, save | E16, E17 | No | `LawyerProfile` (new) | new `lawyer_profile_screen.dart` (full screen or sheet) | **A** (the server does not validate: G6, informational) | Medium |
| L-24 | Profile photo upload + avatar | Profile modal / sidebar | LD:763-773, 1639-1678 | pick image | E18 (multipart `photo`) → Supabase `avatars` | No | `photo_url` | same screen; reuse `EvidenceFilePicker` camera/gallery | **A** (bucket existence `UNVERIFIED`) | Low |
| L-25 | Markdown rendering of AI output (cross-cutting) | L-16, L-20, L-21, L-22 | `marked.parse` + `.assistant-answer` CSS (LD:13, 117-198) | read | — | n/a | — | new shared lawyer widget; dependency per OQ-L2 | **A (none)** | High |

**Row count: 25.** Every D4 block maps to at least one row: 4.1 → L-6…L-9; 4.2 → L-10, L-11; 4.3 → L-12…L-20; 4.4 → L-21; 4.5 → L-22; 4.6 → L-23, L-24; 4.7 → L-1…L-4; the shell → L-5; Markdown → L-25.

**Overlap with Citizen, noted explicitly:**
- L-15, L-14 and L-18 are the writers for Citizen P-15 (`client-status`).
- L-13 and L-17 reuse endpoints Police already calls (E22, E23).
- L-10 would reuse E25 (Police FIR history).

**Acceptance criteria:**
- [x] Every route/component in D4 has a row (mapping above)
- [x] Every row has a Backend Status with a justification cross-referenced to D3/D4
- [x] No unresolved TBD. The open decisions are logged as OQ-L1…OQ-L9 below.
- [x] Citizen/Police overlaps are marked (L-10, L-13, L-14, L-15, L-17, L-18)

### Open questions (need an owner answer before implementation)

| ID | Question | Options | Recommendation |
|---|---|---|---|
| **OQ-L1** | My Cases has no JSON endpoint (L-6, L-8, L-10). | (a) `GET /api/fir-records` + `GET /api/me`, filtered client-side on `assigned_lawyer_id == user_id`. This is the same predicate as `get_firs_by_lawyer`, uses only existing endpoints, and exposes nothing new (E25 is already public). Cost: it downloads every FIR. (b) Scrape the `/lawyer_dashboard` HTML. (c) Wait for a backend endpoint (G1, out of scope). | **(a)**, disclosed as limitation LL-1. (b) is fragile and is rejected. |
| **OQ-L2** | The AI output is Markdown with headings, lists, tables and code (L-25). No Markdown package is in `pubspec.yaml` or the local pub cache. | (a) Add a Markdown rendering dependency (package choice to be approved; it needs `pub get` network access). (b) Hand-roll a subset renderer like the Citizen `rights_answer_text.dart` (bold and bullets only, no tables). | (a). Tables and headings are common in Groq output, and (b) would visibly lose structure. |
| **OQ-L3** | E21 500 (L-16, L-21). | Ship with the website's own error strings ("Something went wrong…"), as limitation LL-2, exactly like Citizen L2. | Yes (Rule 0) |
| **OQ-L4** | Documents "VIEW" (L-17). The Police `EvidenceDetailScreen` sits under the police-guarded `/evidence` prefix. | (a) Open `baseUrl + file_url` externally with `url_launcher` (the website opens a new tab). (b) A lawyer-prefixed route reusing the evidence detail widget, **only if it can be reused unmodified**. | (a) for parity and zero shared-file risk |
| **OQ-L5** | E2 takeover risk and `/` in FIR numbers (L-11). | Parity plus documented limitations LL-3/LL-4. Optionally, a client-side confirmation? The website has none. | Parity, no extra dialog |
| **OQ-L6** | Website quirks: (i) today's hearing is excluded from "This Week"; (ii) the stats count only 2 statuses (by design); (iii) the sidebar avatar only updates after opening the profile; (iv) the status/claim/list are not refreshed without a reload; (v) there is no confirmation on draft/deadline delete; (vi) sign-out style (Citizen chose immediate, D-4a). | Replicate exactly, or fix the obvious defect (i)? | Replicate (ii) and (v). Fix (i) by comparing dates, not instants, with the owner's OK (as Citizen D-2 did). For (iii) load the profile on shell start. For (iv) refresh the providers, because the DoD requires no restart. For (vi) sign out immediately, as the website does. |
| **OQ-L7** | Shared-file sign-off (Rule 0/3): `role_home_screen.dart`, `app_routes.dart`, `app_router.dart`, `api_endpoints.dart`, `pubspec.yaml`. | Approve the minimal additive changes in D1 §3 | Approve |
| **OQ-L8** | Route prefix. `/lawyer` collides with the police `/law` prefix. | (a) `/advocate`; (b) change the police guard to segment matching (a shared Police change) | (a) |
| **OQ-L9** | Live verification and test data. Supabase lawyer columns, tables and the `avatars` bucket are `UNVERIFIED`. A live test must **claim a real FIR** (E2 writes `assigned_lawyer_id`), which would reassign it away from any real lawyer. | (a) Run a read-only probe first, with the owner starting Flask. (b) Create a `ZZFLUTTER` FIR as police and claim only that. | (a) then (b). Never claim a non-test FIR. |

---

## D6 — Backend Gap Report

*Specification only. Per Rule 0, **nothing here is implemented**. Each gap ships as a Flutter limitation (LL-n) that the UI and docs state honestly.*

### Backend Gap G1: Lawyer case list (L-6, L-8, L-10) — Status C → limitation LL-1
- **Website functionality:** My Cases grid, Home stats and upcoming hearings, from `get_firs_by_lawyer(session.user_id)`.
- **Current backend support:** only the server-rendered HTML (app:1079-1088). No JSON.
- **Required endpoint:** `GET /api/lawyer/cases`.
- **HTTP method:** GET.
- **Authentication / Authorization:** session with `role == 'lawyer'`; returns only rows where `assigned_lawyer_id == session.user_id`.
- **Request / Response:** none / `200 [ {fir_no, complainant_name, act_sections, status, next_hearing_date, visible_to_client, …firs row} ]`; `401 {error:"Unauthorized"}`.
- **Database impact:** none (a read of `firs`).
- **Flutter dependency:** until it exists, `GET /api/fir-records` + `GET /api/me` with client-side filtering (OQ-L1).
- **Risk if not implemented:** every Home/My Cases load downloads all FIRs, which is slow on large datasets. No new data exposure, because E25 is already public (D1 S6).

### Backend Gap G2: `find-precedents` returns None on success (L-16, L-21) — Status B → limitation LL-2
- **Website functionality:** Legal Assistant answers and AI case summary.
- **Current backend support:** the handler exists. `return jsonify({"answer": answer})` (app:1303) is nested under `if not answer:`, so the Groq-success path returns `None` → 500.
- **Required endpoint:** same endpoint, with the `return` dedented one level.
- **HTTP method:** POST.
- **Authentication / Authorization:** unchanged (lawyer).
- **Request / Response:** unchanged: `{query, type}` → `200 {answer}`.
- **Database impact:** none.
- **Flutter dependency:** the Flutter client must treat a non-JSON 5xx as the website's error text. Once fixed, no Flutter change is needed.
- **Risk if not implemented:** both AI features fail whenever Groq is healthy. They only "work" (with the RAG fallback list) when Groq is down.

### Backend Gap G3: Claiming an already-assigned FIR (L-11) — Status B → limitation LL-3
- **Website functionality:** Add a Case.
- **Current backend support:** `assign_lawyer_to_fir` overwrites `assigned_lawyer_id` unconditionally (SS; app:1696-1703).
- **Required endpoint:** same; reject with 409 when the FIR already has a different `assigned_lawyer_id`.
- **HTTP method:** POST.
- **Authentication / Authorization:** lawyer; plus ownership conflict detection.
- **Request / Response:** add `409 {error:"FIR already assigned to another lawyer"}`.
- **Database impact:** none (conditional update).
- **Flutter dependency:** display the server error (already generic).
- **Risk if not implemented:** any lawyer who knows an FIR number can take over another lawyer's case, including its drafts, deadlines, hearings and client note (all keyed by `fir_no`). DoD "role/ownership enforced" cannot be fully met.

### Backend Gap G4: FIR numbers containing `/` (L-11, L-13…L-20) — Status B → limitation LL-4
- **Website functionality:** every case-scoped action.
- **Current backend support:** routes use `<fir_no>` (string converter, no slashes). `FIR_NO_RE` (app:229) allows `/`.
- **Required endpoint:** the same routes with `<path:fir_no>`, as `/api/fir-records/<path:fir_no>` already does.
- **HTTP method:** unchanged.
- **Authentication / Authorization:** unchanged.
- **Request / Response:** unchanged.
- **Database impact:** none.
- **Flutter dependency:** none (Flutter already encodes).
- **Risk if not implemented:** low. Such FIRs already fail at `/generate_fir` (D1/D2).

### Backend Gap G5: Public FIR detail and evidence (L-13, L-17) — Status B (security, parity unaffected) → limitation LL-5
- **Website functionality:** Overview and Documents.
- **Current backend support:** E22/E23/E24 have no session check (D1 S6).
- **Required endpoint:** same routes, requiring police, or a lawyer who owns the case.
- **HTTP method:** GET.
- **Authentication / Authorization:** a role plus `lawyer_owns_case` for lawyers.
- **Request / Response:** add 401/403.
- **Database impact:** none.
- **Flutter dependency:** none. The app already sends the cookie. `Image.network` previews would then need the cookie header.
- **Risk if not implemented:** anyone can read any FIR and its evidence. This is pre-existing and not introduced by Lawyer work.

### Backend Gap G6: No server validation on profile / deadline type / deletes (L-19, L-20, L-23) — Status B (minor) → limitation LL-6
- **Website functionality:** profile save, deadline add, draft/deadline delete.
- **Current backend support:**
  - E17 does not validate phone or years;
  - E11 does not enforce `DEADLINE_TYPES` (app:2445);
  - E7/E13 return 200 even when no row matched;
  - E4/E6/E11 call `request.get_json()` without guarding against a null body (500 without JSON).
- **Required endpoint:** same routes, with validation and a 404 when nothing was deleted.
- **HTTP method:** unchanged.
- **Authentication / Authorization:** unchanged.
- **Request / Response:** add 400/404.
- **Database impact:** none.
- **Flutter dependency:** Flutter enforces the website's client rules and always sends JSON.
- **Risk if not implemented:** low (bad data through other clients only).

---

## D7 — Lawyer Implementation Plan (to start only after approval)

**Definition of Done for every step (Citizen DoD):**
- real endpoints only, with no mocks in `lib/`;
- loading, error and empty states using the website's exact strings where they exist;
- role guard (router step 7) and server ownership respected;
- state changes visible without a restart (invalidate providers after each mutation);
- `flutter analyze` clean and the full `flutter test` green after each step;
- no Police/Citizen file changed beyond the OQ-L7 list.

| Step | Content | D5 rows | Files (all new unless marked) |
|---|---|---|---|
| 0 | Owner decisions OQ-L1…L9. Live **read-only** probe (with Flask running): sign in as a test `LAW` account, `GET /api/lawyer/profile`, `GET /api/lawyer/deadlines`, `GET /api/lawyer/drafts`, `GET /api/fir-records` (check the `assigned_lawyer_id` key), confirming the Supabase columns and tables. Copy this file to `.claude/spec/lawyer_D1-D7.md`; write `.claude/plan/lawyer_implementation_plan.md`. | — | docs only |
| 1 | Routing + shell: `/advocate` prefix, step 7, role branch, `LawyerShell` (Drawer with Home · My Cases · Case Workspace · Legal Assistant · Drafts; app bar "NyayaAI" + "Lawyer" badge + sign-out; drawer header with avatar/name → Profile). Remove lawyer from `_plannedFor`. | L-3, L-4, L-5 | **modified (shared, OQ-L7):** `app_routes.dart`, `app_router.dart`, `role_home_screen.dart`; new `features/lawyer/presentation/screens/lawyer_shell.dart`, `controllers/lawyer_section.dart` |
| 2 | Data layer: `LawyerRemoteDataSource` (E2–E21 + `/api/me` + E22/E25 parsing into lawyer models); `LawyerRepository`; models `LawyerCase`, `LawyerCaseDetail`, `CaseHearing`, `CaseDeadline`, `CaseDraft`, `LawyerProfile`; `LawyerFailure` mapping to the website strings; non-JSON 5xx handling (for G2). | all | **modified (additive):** `api_endpoints.dart`; new `features/lawyer/data/**`, `domain/**` |
| 3 | My Cases (search, stats, cards, empty) + Add a Case (validation, "Adding…", messages, then list refresh). Then Home (hero with name from E16, stats, quick actions, upcoming hearings, upcoming deadlines with tap → workspace). | L-6…L-11 | `my_cases_screen.dart`, `lawyer_home_screen.dart`, `lawyer_cases_controller.dart`, widgets `case_card.dart`, `lawyer_status_pill.dart` (LD colours) |
| 4 | Case Workspace route `/advocate/case/:firNo`: header + status change (E9, "✓ Updated") + tabs. Overview (E22) + Message to client (E15 send/stop, badge). Invalidate the case list after status/share changes. | L-12…L-15 | `case_workspace_screen.dart`, `overview_tab.dart`, `workspace_controllers.dart` |
| 5 | Hearings tab (list, add, next-hearing refresh) + Deadlines tab (6 types, add, toggle, delete, overdue styling). Invalidate the Home deadlines after changes. | L-18, L-19 | `hearings_tab.dart`, `deadlines_tab.dart` |
| 6 | Documents tab (E23 via the existing `EvidenceRepository`, category label, VIEW per OQ-L4) | L-17 | `documents_tab.dart` |
| 7 | Markdown widget (OQ-L2), then Drafts tab (bail/general with the website's exact prompts, Save, saved list view/delete), AI Summary tab (the website's exact composed query), Legal Assistant (4 chips, "Thinking…", single answer), All Drafts (view preview, open case). The E21 failure shows the website's error text (LL-2). | L-16, L-20, L-21, L-22, L-25 | **modified (additive):** `pubspec.yaml`; `lawyer_markdown.dart`, `drafts_tab.dart`, `summary_tab.dart`, `legal_assistant_screen.dart`, `all_drafts_screen.dart`, `lawyer_content.dart` (verbatim website strings and prompts, with LD line refs, following the precedent of `citizen_content.dart`) |
| 8 | Profile: load (E16), read-only name/ID/email, 6 editable fields with the website validation, save (E17); photo via camera/gallery → E18; avatar in the drawer. | L-23, L-24 | `lawyer_profile_screen.dart`, `profile_controller.dart` |
| 9 | Tests and reports. Fakes: `fake_lawyer_repository.dart`, helper `pump_lawyer_app.dart`. Unit tests: request JSON keys; composed prompts equal the website's; the case-filter predicate; overdue/this-week logic; profile validation. Widget tests: every section's strings and states; guard tests (lawyer can reach `/advocate/*`; police/citizen/judge cannot; lawyer still kept off `/fir`, `/law`, `/citizen`). Live `test_live/lawyer_live_test.dart` against a `ZZFLUTTER` FIR only (OQ-L9). Then the parity table and the Police/Citizen regression report (brief §11). | all | `test/**`, `test_live/**`, `.claude/spec/lawyer_parity.md` |

**Limitations that will ship (restated):**
- LL-1: case list via all-FIR fetch (G1)
- LL-2: AI Summary and Legal Assistant fail while Groq is healthy (G2)
- LL-3: claim can take over another lawyer's FIR (G3)
- LL-4: FIR numbers containing `/` are unsupported (G4)
- LL-5: public FIR and evidence reads (G5)
- LL-6: no server validation (G6)

**Hard stop.** This document is analysis only. No Lawyer code has been written. Implementation starts only after explicit approval of D1–D7 and answers to OQ-L1…OQ-L9.

---

## §8 Implementation record (2026-09-28)

**Owner directive (2026-09-28):** "Inspect the website implementation and reproduce it exactly. If the website already determines the behavior, follow the website. Only ask when the behavior cannot be determined from source." Each open question was settled from the source, as follows:

| OQ | Settled by the website | Implemented as |
|---|---|---|
| OQ-L1 case list | The page lists `firs` where `assigned_lawyer_id == session.user_id` (app.py:1086), and there is no JSON route | The same predicate over `GET /api/fir-records`, using the `user_id` from `GET /api/me` (LL-1) |
| OQ-L2 Markdown | The page renders every answer with `marked.parse` (GFM) | `flutter_markdown_plus ^1.0.12`, the maintained successor of the discontinued `flutter_markdown`, with the GFM extension set |
| OQ-L3 E21 500 | The page shows its own sentences | The same sentences (LL-2) |
| OQ-L4 VIEW | `<a target="_blank">` | Opens externally with `url_launcher` |
| OQ-L5 claim | No confirmation | None added |
| OQ-L6 quirks | Today's hearing excluded; only 2 statuses counted; avatar photo appears only after the profile loads; no delete confirmations; immediate sign-out; page reload onto Home after a claim | All reproduced |
| OQ-L8 prefix | The workspace is a section of the page, not a separate page | **No new route.** All five sections live in `LawyerShell`, so `app_routes.dart` and `app_router.dart` are **unchanged** and the `/law` collision never arises |

**Files changed outside `lib/features/lawyer/`:**
- `lib/features/dashboard/presentation/screens/role_home_screen.dart`: lawyer branch → `LawyerShell`; the lawyer "COMING NEXT" list is removed.
- `lib/core/constants/api_endpoints.dart`: additive lawyer constants.
- `pubspec.yaml`: `flutter_markdown_plus`.
- `test/widget/features/fir_route_guard_test.dart`: a `lawyerRepositoryProvider` fake override. A lawyer now lands on a portal that fetches on build; the file already does the same for the complaints inbox.

**New files:**
- `lib/features/lawyer/` (13 files)
- `test/helpers/fake_lawyer_repository.dart`
- `test/helpers/pump_lawyer_app.dart`
- `test/unit/features/lawyer_test.dart` (33 tests)
- `test/widget/features/lawyer_portal_test.dart` (29 tests, including a 320-px-wide layout pass)

**Verification:**
- `flutter analyze`: no issues.
- `flutter test`: **584/584** (the 522 baseline plus 62 new).
- **Not yet done:** a live run against the real server. Flask was not running, and a live claim writes `assigned_lawyer_id` on a real FIR (OQ-L9).

**Where the app knowingly differs from the page:**

| # | Difference | Why |
|---|---|---|
| X-1 | After a status change, an added hearing, or a deadline add/toggle/delete, the case list and Home's deadlines are refetched. The page shows the old values until a reload. | Brief DoD ("no restart needed to see state changes"). An app has no reload. |
| X-2 | Opening a case resets every workspace input and message. The page resets only the summary and draft output, and leaves the previous case's "Save Draft" button live, which could save case A's draft into case B. | Carrying one case's state into another is a defect, not a behaviour. |
| X-3 | A small spinner shows while a tab loads; the page shows blank. | Mobile UI adaptation only. |
| X-4 | My Cases has an error state with Retry. | The page cannot fail this way: its list arrives inside the HTML. |
| X-5 | The greeting name comes from `GET /api/lawyer/profile` → `fullname`, else the cached name, else "Advocate". | A sign-in on the app returns no name. The server's session value comes from the same field. |
| X-6 | The case-card header wraps, and Markdown tables scroll sideways. | Phone width |
| X-7 | The profile photo offers camera or gallery, and non-image picks are ignored. | `accept="image/*"` on a phone |
| X-8 | A share that fails with no JSON reads "Could not send. Failed to fetch". | The page prints the browser's own error text, which differs by browser. This is Chrome's. |

---

## §9 Live integration run (2026-09-28)

**Setup:**
- `website/app.py` was run **unmodified** (`venv/bin/python app.py`). The start-up log shows `[MissingPersons] face_recognition_helper loaded.`
- Suite: `flutter test test_live/lawyer_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:5000`. It drives the app's own `LawyerRemoteDataSource`.

**Result: 25/25 passed.**

| Area | Result against the real server |
|---|---|
| L-1..L-3 | ✅ The lawyer registers with a `LAW` ID, signs in, and `/api/me` reports role `lawyer`. The profile returns `fullname` (the greeting). |
| Test FIR | ✅ Filed through the Police data source. Status `Saved to Police Records`. |
| L-10/L-11 | ✅ Claiming an unknown FIR → "FIR not found". The claim succeeds, and My Cases then holds exactly that FIR. |
| L-13 | ✅ All four lawyer columns exist in Supabase `firs` (`assigned_lawyer_id`, `visible_to_client`, `client_note`, `next_hearing_date`). This resolves the D3 `UNVERIFIED` for the columns. |
| L-14 | ✅ An invalid status → "Invalid status". Court Proceedings is saved. **Cross-role:** the Police FIR record now reads "Court Proceedings". |
| L-15 ↔ Citizen P-15 | ✅ Unshared → citizen 404. Send → the citizen sees the status and note. Stop → 404 again. The FIR is left shared at the end. |
| L-17 | ✅ The evidence list answers (empty for a new FIR). |
| L-18 | ✅ A hearing is added, and `next_hearing_date` follows it. `case_hearings` exists. |
| L-19 | ✅ Add ×2, overdue logic, the Home 14-day list, complete, delete. `case_deadlines` exists. |
| L-20/L-22 | ✅ Bail and general drafts generated by Groq (bail: 4480 chars). Save, per-case list, all-drafts list, delete. `case_drafts` exists. |
| L-23 | ✅ The six fields are saved and read back. |
| L-24 photo | ⏭ Not run (it writes to Supabase storage; left out by agreement). The `avatars` bucket is still `UNVERIFIED`. |

**Known backend limitations, observed and documented, not fixed (Rule 0):**
- **LL-1** (the case list uses every FIR): `/api/fir-records` returned 26 FIRs to show this lawyer 1.
- **LL-2** (`app.py:1294-1303`): both the Legal Assistant question and the AI Summary query returned **HTTP 500**. The Flask log shows `TypeError: The view function for 'lawyer_find_precedents' did not return a valid response`, raised because Groq answered successfully. The app shows the website's own sentences: "Something went wrong. Please try again." and "Something went wrong generating the summary."
- **LL-3** (takeover): a second test lawyer's claim of the already-assigned test FIR was **accepted**. The first lawyer's My Cases became empty, and its workspace calls now get 403 (the page reads this as empty lists). The second lawyer inherits the FIR's hearings.

**Police/Citizen spot-check in the same run:**
- the Police FIR record read (`FirRemoteDataSource.record`) and the Citizen case-status reader (`CaseStatusRemoteDataSource`) both work against the lawyer-modified row;
- the full offline suite is unchanged at 584/584.

**Records left in place (by owner decision), for reproducing this later:**

| Kind | Record |
|---|---|
| Mongo users | `zz.flutter.lawyer.1790536627399@example.com` (`LAWZZ0536627399`) |
| | `zz.flutter.lawyer2.1790536627399@example.com` (`LAWZZB0536627399`) |
| Supabase `firs` | `FIRZZFLUTTERL0536627399`, plus its PDF in bucket `firs`. It is assigned to `LAWZZB0536627399` after the takeover probe, has status Court Proceedings, and is shared with the client (note "ZZ probe: chargesheet filed."). |
| `case_hearings` | 1 row (2099-01-15) |
| `case_deadlines` | 1 row ("ZZ kept", 2099-12-31) |
| `case_drafts` | 1 row ("ZZ probe kept draft") |

**Still open:** an on-device or emulator walk-through of the screens.

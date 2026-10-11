# Judge Side — Analysis D1–D7 (analysis only, no implementation)

**Audit date:** 2026-10-11.
**Governing rules:** Judge brief §1. Nothing under `website/`, Flask, MongoDB, Supabase or `lib/` was modified. Backend gaps are documented (D6), not patched.

**Sources (all read from the working tree, website HEAD `14ef68e`):**
- `website/templates/judge_dashboard.html` (**JD**, 1195 lines, read in full)
- `website/main/judge_routes.py` (**JR**, 139 lines, read in full)
- `website/main/storage_service.py` (**SS**), lines 164-215 (docket functions)
- `website/app.py` (**app**, 3480 lines): the judge, law-library, auth and evidence sections
- `website/missing_person.py` (**MP**): `/api/me`
- `website/templates/login.html`, `signup.html`
- Flutter: `Application/NayayaAi_APP/flutter_app/lib/**`, `test/**`, `test_live/**`
- Prior reports: `.claude/spec/lawyer_D1-D7.md`, `docs/FEATURE_INVENTORY.md`

Paths starting `lib/` or `test/` are relative to `flutter_app/`.

Evidence labels used below:
- **[SRC]** verified source-code fact
- **[TEST]** test result run during this audit
- **[LIVE]** observed live-server behaviour (none this audit: Flask was not running)
- **[INF]** inference
- **UNVERIFIED — requires source confirmation**

---

## Headline findings (read first)

1. **The website has a real, backend-connected Judge portal.** [SRC]
   - It is one page, `GET /judge-dashboard` (app:680-686; it admits roles `judge` and `admin`), rendering `judge_dashboard.html`.
   - The page has 4 working sections: **Home**, **Case Docket**, **Case Workspace** and **Law Library** (Browse Acts / Precedent Research / Bookmarks).
   - A 5th nav item, **"Orders & Drafts"**, has no `id`, no handler and no section (JD:85-87). It does nothing.
   - The backend is the `judge_bp` blueprint (JR, prefix `/judge`) plus `POST /judge/precedents` (app:1989-2078). The data lives in one Supabase table, `case_docket` (SS:164-215).
   - **Verified feature count: 22 functional features (J-1…J-22), plus 1 inert nav item (J-23).** See D5.

2. **The Judge brief in `docs/FEATURE_INVENTORY.md` (F22–F35) is obsolete. Do not build it.** [SRC]
   - It lists Verdict Drafting, Bail Risk Assessor, Warrant & Summons, Remand Tracker, Daily Order Sheet and other features.
   - Those described the localStorage-only template in commit `a95ff14` (2571 lines; 19 `localStorage` uses, 20 "verdict", 14 "warrant").
   - Commit `ae229a9` (2026-09-15) replaced that template. The current template contains none of them (`grep -i "verdict|warrant|remand|sentenc|bail risk|order sheet"` → 0 hits).

3. **The Judge side writes nothing that other roles read.** [SRC]
   - `case_docket` is read and written only by `judge_bp`.
   - The `case_id` field is free text with no link to `firs` (SS:164-173). The page itself warns that a non-matching ID "will still save" (JD:557).
   - The judge only *reads* `firs`, through the public `GET /api/fir-records` and `GET /api/fir-records/<fir_no>`.
   - Result: unlike Lawyer, Judge work cannot change what Police, Citizen or Lawyer see.

4. **The website's Judge page has no sign-out control and never shows the judge's name.** [SRC]
   - There is no `/logout` link anywhere in JD (`grep logout` → 0 hits).
   - The greeting and sidebar read `session.get('name', 'Judge')` (JD:92-94, 110). Login stores `session["fullname"]` (app:2883), and **no code anywhere sets `session['name']`** (repo-wide grep). Every judge therefore sees "Welcome back, **Judge**." and the avatar letter "J".
   - Both are owner decisions: OQ-J1 and OQ-J2.

5. **⚠ Backend drift since the Lawyer baseline: today's merge changed behaviour that existing Flutter roles depend on.** [SRC]
   - The website repo was updated today: local commit `f3e6f5f` was merged with upstream `b26ade4` into `14ef68e` (2026-10-11 02:30).
   - An AST comparison of `app.py` before and after the merge shows these semantic changes:
     - `police_required` decorator added, now on every evidence endpoint;
     - `assign_lawyer` now returns 409;
     - `add_hearing` now validates past dates;
     - `home()` now sends admin to `/admin/dashboard`;
     - new admin blueprint.
   - Consequences:
     - the Flutter Lawyer **Documents** tab now gets 403;
     - the Police evidence **image preview** (`Image.network`, which sends no cookie) now gets 401;
     - a Flutter admin is now refused on evidence.
   - Offline tests still pass (584/584) because they use fakes. **This is outside Judge scope.** It is reported in D2 §3 for a separate decision (OQ-J8), and nothing was changed.

6. **One behaviour that matters cannot be determined from source:** the column type of `case_docket.hearing_date`. [SRC + UNVERIFIED]
   - No DDL exists anywhere in the repo.
   - The type decides three things:
     - what string the page displays;
     - whether a hearing whose date has passed can still be edited (for example, marked "completed");
     - whether the 30-minute conflict check can ever fire.
   - See D6 GJ-1. It needs a live probe (OQ-J7).

---

## D1 — Existing Flutter Architecture Audit (Judge delta)

**Baseline reused unchanged:**
- `docs/audit/D1_flutter_architecture.md`
- `lawyer_D1-D7.md` D1 and §8

The architecture is:
- Riverpod 2 (`Notifier`/`AsyncValue`, no codegen);
- Dio with a persistent cookie jar and the `X-NyayaAI-Client` header;
- GoRouter with one redirect (`lib/routes/app_router.dart:65-118`);
- feature-first Clean Architecture;
- hand-written `fromJson`;
- `ErrorMapper` → `Failure`.

The Citizen and Lawyer portals are each a **shell with in-place sections**, selected by role in `role_home_screen.dart`. Neither added routes; the Lawyer portal changed neither `app_routes.dart` nor `app_router.dart` (lawyer §8, OQ-L8).

### 1. Every existing `judge` reference in Flutter (complete grep of `lib/`, `test/`, `test_live/`)

| Where | What exists | Usable for Judge? |
|---|---|---|
| `lib/core/enums/user_role.dart:10,30,36,40` | `UserRole.judge('judge','Judge','JUD')`. It is in `registerable`; `requiresUserSuppliedId` is true; `hasPoliceAccess` is false; `fromWire('judge')` → judge. | ✅ Complete. No change. |
| `lib/features/authentication/presentation/widgets/role_selector.dart:30` | Judge tile (`Icons.gavel_rounded`) | ✅ Sign-up already supports judge |
| `lib/features/authentication/presentation/screens/signup_screen.dart:27`, `lib/core/utils/validators.dart:87` | Unique ID required, `JUD` prefix validated | ✅ |
| `lib/features/dashboard/presentation/screens/role_home_screen.dart:46-58, 111-130` | A judge falls through to `_RoleHomeList`: identity card, **sign-out with confirmation** (line 81, `confirmSignOut`), and a non-interactive "COMING NEXT" list ("Case docket", "Hearing scheduler", "Law library") | ⚠️ Placeholder. **This is the extension point.** |
| `test/unit/auth_contract_test.dart:20,26,34,86-88,251` | wire value, prefix, ID required, login parse, validator | ✅ Must stay green, unchanged |
| `test/widget/features/fir_route_guard_test.dart:206-213, 304-313` | a judge is kept off `/fir/new` and `/citizen/...` | ✅ Must stay green. It needs a judge-repository fake override once the judge lands on a shell that fetches on build (the same precedent as Lawyer, §8). |
| `test/widget/features/splash_screen_test.dart:130-176` | **Uses judge as the "generic role home" subject.** It expects the texts `'Test Judge'` and `'JUD001'` after sign-in, and taps `Icons.logout_rounded` then a confirmation "Sign out". | ⚠️ **Will break** once a judge lands on a Judge shell: the website shows neither name nor ID, and has no sign-out (Headline 4). These two tests must be retargeted (D2 §2). |
| `test/widget/features/login_screen_test.dart:121-126`, `signup_screen_test.dart:58,90,376-380` | judge email/role as form input | ✅ Unaffected (form-level) |
| Models | **No** judge model. `FirRecord` (`lib/features/fir/domain/entities/fir_record.dart`) already exposes `firNo`, `complainantName`, `district` (wire `dist`), `policeStation` (`ps`), `actSections` and `status`. These are exactly the fields the judge page reads (JD:519-552, 826-830). | ✅ Reuse read-only through `firRepositoryProvider` (`lib/features/fir/presentation/controllers/fir_providers.dart:25`). No change to Police files. |
| `lib/features/legal/data/datasources/legal_remote_data_source.dart` | `acts()` → `GET /api/acts`; `sections(act, search, page, limit)` → `GET /api/sections/<act>`; `section(act, no)` → `GET /api/section-detail/<act>/<no>` | ✅ The same three endpoints the judge Law Library uses. Reuse read-only through `legalRepositoryProvider` (`legal_providers.dart:13`), passing `limit: 15` as JD:935 does. **Do not reuse the police `LawLibraryScreen`:** it sits under the police-guarded `/law` prefix and behaves differently (all-act search, comparison, no bookmarks or bare acts). |
| `lib/core/storage/secure_storage_service.dart:25-43` | generic `read/write/delete(key)`. Sign-out clears the cookie session (`auth_repository_impl.dart:51,95,115`) and not arbitrary keys. | ✅ A candidate store for device-local bookmarks without a new dependency (OQ-J5) |
| `pubspec.yaml` | `url_launcher ^6.3.2` (external links), `flutter_markdown_plus` (not needed: judge output is structured plain text). `shared_preferences` is **not** a dependency (pubspec:109 comment). | ✅ No new dependency required |
| `docs/FEATURE_INVENTORY.md:270-287` (F22-F35) | the obsolete judge plan | ❌ Stale. Headline 2. |

**Conclusion:** the Judge role exists in authentication, sign-up, the role enum and the route guards. **No Judge feature exists in Flutter.** [SRC]

### 2. How a judge is identified today
- `POST /login` returns `{message, role, unique_id, redirect:"/judge-dashboard"}` (app:2885-2905). Flutter ignores `redirect` (`app_routes.dart:3-6`).
- `GET /api/me` returns `{logged_in, role, user_id}` (MP:116-133).
- The server identifies a judge only by `session['role'] == 'judge'` (JR:11-14; app:1991). **There is no judge model, court, jurisdiction or case-assignment record.** The docket is scoped by `judge_id = session['user_id']` (JR:38, 52, 99, 133).
- On the website, a judge goes from login to `/` (login.html:502-503 falls through to `"/"`), and `home()` then redirects to `/judge-dashboard` (app:593-594).

### 3. Minimal extension points (identified only, not implemented)

| Extension point | File | Current responsibility | Proposed change | Why | Other roles affected | Risk |
|---|---|---|---|---|---|---|
| Role branch | `lib/features/dashboard/presentation/screens/role_home_screen.dart:54-58, 113-130` | police/admin → console; citizen → `CitizenShell`; lawyer → `LawyerShell`; otherwise `_RoleHomeList` | Add `if (user.role == UserRole.judge) return const JudgeShell();`. The judge case in `_plannedFor` returns `[]`, like the other roles. | Landing on the portal | All roles route through this build method. The change is one branch after the existing three. | Low |
| Endpoint constants | `lib/core/constants/api_endpoints.dart` | every server path | Additive: `judgeDocket` (`/judge/docket`), `judgeDocketEntry(int id)`, `judgePrecedents` (`/judge/precedents`), `openBareAct(code)` | No hard-coded paths | None (additive) | None |
| Router | `lib/routes/app_routes.dart`, `app_router.dart` | the police and citizen guards | **No change.** All Judge sections, modals and the workspace detail live inside `JudgeShell` at `/home`, as Lawyer does. ⚠️ If a route were ever added, `/judge…` does not collide with `/law`, but `/law…` would (lawyer Headline 5). | — | — | None |
| Tests | `test/widget/features/splash_screen_test.dart:130-176`; `fir_route_guard_test.dart` | see §1 | Retarget the two splash tests and add a judge fake override | They assert the judge placeholder that is being replaced | Test-only | Low |
| `pubspec.yaml` | — | — | No change expected | — | — | None |

### 4. Proposed folder
`lib/features/judge/{data/{datasources,models,repositories}, domain/{entities,repositories}, presentation/{controllers,screens,widgets}}`. This mirrors `lib/features/lawyer/`.

Reused **unchanged**:
- `firRepositoryProvider` (`history()`, `record()`)
- `legalRepositoryProvider` (`acts()`, `sections()`, `section()`)
- `SecureStorageService`
- `AuthController.logout` (only if OQ-J1 approves sign-out)
- shared widgets and theme tokens
- the Lawyer pattern for a non-JSON 5xx reply (`lawyer_remote_data_source.dart` `_Reply`)

---

## D2 — Existing Regression Baseline

### 1. Current results (re-run 2026-10-11) [TEST]

| Check | Command (in `flutter_app/`) | Result |
|---|---|---|
| Toolchain | `flutter --version` | Flutter 3.44.9 stable |
| Analyzer | `flutter analyze` | **No issues found** (6.7 s) |
| Offline suite | `flutter test` | **584 passed, 0 failed** ("All tests passed!"). This matches the Lawyer §8 count (522 + 62). |
| Live suites | `test_live/*.dart` (auth, citizen, evidence, fir, lawyer, legal, missing_persons) | **NOT RUN.** `curl http://127.0.0.1:5000/health` → no connection. The Flask server was not running. |
| Mongo (read-only count) | `mongosh` `users.countDocuments` | 1 user with role `judge` (a real account; not used); 0 `zz.` test judges; 0 admins |

Nothing has been verified against a live server in this audit.

### 2. Shared files the Judge work would touch

| Shared file | Police today | Citizen today | Lawyer today | Judge change risk | Regression checks required |
|---|---|---|---|---|---|
| `role_home_screen.dart` | `hasPoliceAccess` → console | → `CitizenShell` | → `LawyerShell` | Low (one branch) | Police lands on the console; citizen and lawyer on their shells; judge on `JudgeShell`; admin still on the console |
| `api_endpoints.dart` | all paths | citizen paths | lawyer paths | None (additive) | Analyzer + full suite |
| `splash_screen_test.dart` | — | sign-out test (line 178+) | — | **Must change.** Two tests assert the judge placeholder (`'Test Judge'`, `'JUD001'`, confirmation sign-out). | Retarget: sign-in → assert the Judge shell's hero; sign-out → per the OQ-J1 decision. Keep the "never flashes the sign-in form" assertion. |
| `fir_route_guard_test.dart` | judge kept off `/fir/new` | judge kept off `/citizen/...` | — | Low (needs a fake override for the judge repository) | The existing judge guard tests stay green, unchanged in intent |
| Read-only reuse: `FirRepository`, `LegalRepository` | history/record; law library | — | My Cases | None (consumed, not modified) | `fir_history_screen_test`, `law_library_test` unchanged |

### 3. ⚠ Backend changes since the Lawyer baseline (outside Judge scope, reported, nothing fixed)

The Lawyer live run (2026-09-28) was against working tree `f3e6f5f`. HEAD is now `14ef68e` (merge of upstream `b26ade4`, commits `fc5164e` "add police only evidence locker access, admin audit trail" and `8135313`).
- Most of the `app.py` diff is quote reformatting. An AST comparison isolated these logic changes:

| # | Change (current source) | Flutter impact | Role |
|---|---|---|---|
| X-1 | `@police_required` (app:2329-2346: session plus Mongo `role == 'police'` exactly; 401/403) now guards `/upload-evidence` (2950), `/get-evidence/<fir>` (2997), `/evidence-file/<fir>/<file>` (3004), `/api/evidence` (3013), `/api/evidence/log-access` (3053) and `/get-all-evidence` (3062). Each read is logged to the Mongo `evidence_access_log` collection, and repeated views raise `admin_alerts` (2367-2421). | **Police:** Dio calls still work (cookie sent), but the evidence detail **image preview uses `Image.network`, which sends no cookie** (`lib/features/evidence/presentation/screens/evidence_detail_screen.dart:109-117, 174`). The preview will now fail. The code comment at line 113 predicted this. **Admin** (`hasPoliceAccess`) is now 403 on evidence. **Lawyer:** the Documents tab (L-17) gets 403, the error is swallowed (`workspace_tabs.dart` `_logOnly`), and the tab shows a blank card. The website lawyer page also breaks (it still calls `/api/evidence`). | Police, Lawyer, Admin |
| X-2 | `assign_lawyer` (app:2425-2443) now returns 409 "FIR {no} is already added to your cases." or "This FIR is already assigned to another lawyer." | Flutter shows the server's `error` text (`lawyer_remote_data_source.dart:130-135`), so it works. Lawyer limitation LL-3 is **now fixed upstream**, and the lawyer live test's takeover expectation is out of date. | Lawyer |
| X-3 | `add_hearing` (app:3202-3230) now returns 400 for a bad date format or a past date. `lawyer_dashboard.html` gained `cw-hearing-msg`, a `min` date and the red message "Hearing date cannot be in the past." | **Parity drift:** Flutter `addHearing` throws `LawyerSilentFailure` and shows nothing (`lawyer_remote_data_source.dart:218-225`, `workspace_tabs.dart:583-597`). | Lawyer |
| X-4 | `home()` sends admin to `/admin/dashboard` (app:599-600). A new admin portal exists (`main/admin_routes.py`, `admin_dashboard.html`). | Flutter admin still lands on the police console. Not addressed here. | Admin |

The line numbers in `lawyer_D1-D7.md` that refer to `app.py` are now stale, because the file was renumbered. The behaviour it describes is unchanged except for X-1…X-3.

**Recommendation:** handle X-1…X-3 as a separate, approved maintenance task (OQ-J8). They are not caused by, and not fixed by, Judge work. The Judge regression report must list them so they are not attributed to Judge changes.

### 4. Safe regression checks required after Judge work
- `flutter analyze` clean; full `flutter test` green (584 + new Judge tests).
- Role landing for all 5 roles (police, admin, citizen, lawyer, judge).
- The judge stays off `/fir/*`, `/evidence/*`, `/complaints/*`, `/law*`, `/missing-persons*` and `/citizen/*` (police and citizen guards unchanged).
- `law_library_test.dart` and `fir_history_screen_test.dart` unchanged (shared repositories consumed, not modified).
- Live: once Flask is running, re-run `auth_live_test`, `legal_live_test` and `fir_live_test` read paths. Lawyer and evidence live suites are expected to differ because of X-1…X-3, **not** Judge.

---

## D3 — Backend and Authorization Audit (Judge-relevant)

### 1. Judge storage

| Store | Table | Columns written by code | Readers | Schema in repo? |
|---|---|---|---|---|
| Supabase | `case_docket` | `judge_id` (Mongo user ObjectId string), `case_id` (free text), `hearing_date` (string as sent), `case_type`, `urgency`, `status` (**always `"scheduled"` on insert**), `remarks` (SS:164-173). Updates allow only `hearing_date, case_type, urgency, status, remarks` (JR:121-122). | `get_docket_for_judge` (`eq judge_id`, optional `eq status`, `eq urgency`, `order hearing_date` asc) SS:176-182; `get_docket_entry` SS:185-187; `check_docket_conflict` SS:189-205 | **No DDL anywhere.** The route `<int:entry_id>` implies an integer `id`. The `hearing_date` type and the existence of `created_at` are **UNVERIFIED — requires source confirmation** (D6 GJ-1). |
| Browser `localStorage` | key `nyayaai_judge_bookmarks` | `[{act, section, title}]` (JD:996-1047) | the page only | n/a. Per **browser**, not per judge (the comment at JD:996 says "per judge", but the key is not scoped by user). |
| SQLite `IndiaLaw.db` | 8 act tables (read-only) | — | `/api/sections`, `/api/section-detail`, `build_statutory_sections` | Two column schemes, handled by `act_columns` (app:452-475) |
| In-code data | `SECTION_MAPPINGS` (app:1538, 3 topics), `VERIFIED_PRECEDENTS` (app:1645, 5 cases), `LEGAL_PRINCIPLES` (app:1721) | — | `/judge/precedents` | Curated, static |

### 2. Judge endpoints

All `judge_bp` routes use `_require_judge()` (JR:11-14). It checks only `session['role'] == 'judge'` and returns **403 `{"error":"unauthorized"}`**, also for a signed-out caller (no 401).
- None has `@require_same_origin`; Flutter's existing headers suffice.
- `CSRFProtect` is imported (app:20) but never instantiated (grep `CSRFProtect(` → 0).

| # | Method + path | Handler | Auth / ownership | Request | Response (success / error) | DB |
|---|---|---|---|---|---|---|
| E1 | `GET /judge-dashboard` | app:680-686 `judge_dashboard` | session; role ∈ {judge, admin}, else redirect `/` | — | HTML | — |
| E1b | `GET /judge/dashboard` | JR:25-30 | judge (403 JSON) | — | HTML (same template). **Not linked from anywhere.** | — |
| E2 | `GET /judge/docket?status=&urgency=` | JR:33-42 | judge; rows `eq judge_id` | optional filters (empty → none) | 200 `[{id, judge_id, case_id, hearing_date, case_type, urgency, status, remarks, …}]` sorted by `hearing_date` asc | `case_docket` select |
| E3 | `POST /judge/docket` | JR:45-90 | judge | JSON `{case_id, hearing_date, case_type, urgency, status, remarks}`. **`status` is ignored** (SS:170 hard-codes `scheduled`). | **201** the inserted row (or `null` if Supabase returns none). 400 `{error:"invalid", message:"Case ID is required."}`; 400 `{…"Invalid hearing date."}` (`datetime.fromisoformat` fails); 400 `{error:"past_date", message:"Hearing date cannot be in the past."}` (vs server-local `datetime.now()`); **409** `{error:"duplicate", message:"Case {id} is already in your docket."}` (case-insensitive, **any status**, JR:67-73); **409** `{error:"conflict", message:"Overlaps with case {case_id} at {hearing_date}"}` (±30 min, excluding cancelled/completed, SS:189-205) | insert |
| E4 | `PUT /judge/docket/<int:id>` | JR:93-124 | judge; owner (`entry.judge_id == session.user_id`) else **404 `{error:"not_found"}`** (no message) | any of `hearing_date, case_type, urgency, status, remarks`. **`case_id` is silently ignored.** | 200 the updated row. When `hearing_date` differs from the stored string: 400 invalid / 400 past_date / 409 conflict (excluding self). **No duplicate check.** | update `eq id, eq judge_id` |
| E5 | `DELETE /judge/docket/<int:id>` | JR:127-139 | judge; owner else 404 | — | 200 `{deleted: id}` | delete |
| E6 | `POST /judge/precedents` | app:1989-2078 `judge_find_precedents` | session plus role judge, else **401 `{error:"Unauthorized"}`** | `{query}`; a null body raises → 500 | 200 `{current_law, directly_relevant[], related_authorities[], principles[], statutory_sections[], synthesis\|null, sources[], no_result_notice\|null, ai_notice\|null}`; 400 `{error:"Please enter a research query."}` | static data + SQLite + Groq |

**E6 pipeline** [SRC]:
1. `classify_topic` (app:1812) runs `fuzz.token_set_ratio` against the topic labels and keywords, with threshold 65.
2. `extract_section_reference` uses `SECTION_RE` (app:1755: "section N <act>").
3. `find_direct_and_related` (app:1828). Related authorities appear only when the query contains a comparison trigger.
4. `build_statutory_sections` (app:1853) builds the current and historical provisions, plus an explicit section looked up in SQLite.
5. Off-topic guard: nothing identified → the fixed `no_result_notice` "This does not appear to be an Indian legal research query — …" with `ai_notice: null`.
6. Otherwise `ask_groq(prompt, max_tokens=600)` (app:1306-1343). `parse_synthesis` (app:1962) splits the reply into `summary`, `current_position`, `historical_position` and `qualification`. A Groq failure returns `None` → `synthesis: null`; this is graceful, with no 500 (unlike the lawyer G2).
7. When the request carries `X-NyayaAI-Client`, Groq uses `GROQ_API_KEY_APP` if that is set (app:1298-1303).

### 3. Shared endpoints the Judge page calls (no role check)

| # | Endpoint | Handler | Used for | Flutter caller today |
|---|---|---|---|---|
| E7 | `GET /api/fir-records` | app:2450-2461 | FIR autocomplete in the hearing modal (JD:500-507). **Public; returns every FIR with every column.** | `FirRemoteDataSource.history()` (Police history, Lawyer My Cases) |
| E8 | `GET /api/fir-records/<path:fir_no>` | app:2464-2479 | Workspace "FIR Details" (JD:822). 404 `{error:"FIR record … not found"}` | `FirRemoteDataSource.record()` |
| E9 | `GET /api/acts` | app:623-626 | Law Library act list → `["IPC","CRPC","NIA","IEA","HMA","CPC","IDA","MVA"]` (app:452) | `LegalRemoteDataSource.acts()` |
| E10 | `GET /api/sections/<act>?page=&limit=15&search=` | app:1051-1105 | Browse. 200 `{act,total,page,limit,pages,results:[{section,title,description}]}`; 400 `{error:"Invalid act"}`; 500 `{error}` | `LegalRemoteDataSource.sections()` |
| E11 | `GET /api/section-detail/<act>/<no>` | app:1110-1130 | Opening a bookmark. 200 `{section,title,description}`; 404 `{error:"Section not found"}` | `LegalRemoteDataSource.section()` |
| E12 | `GET /open-bare-act/<code>` | app:1246-1275 | "Open Bare Act (PDF) ↗" / "Open Current Law (X) ↗": 302 to indiacode.gov.in, or an HTML 404/503 page. `BARE_ACTS_INFO` (app:1151+) covers the 8 acts plus BNS, BNSS and BSA. | none |

Auth endpoints (shared, unchanged):
- `POST /signup`: role `judge`; `unique_id` required and must start with `JUD` (app:2769-2793)
- `POST /login`
- `GET /logout` (app:2915-2918)
- `GET /api/me`

### 4. Authorization summary (security-relevant)
- **Role check only.** The server has no notion of which cases a judge may see or schedule: no court, jurisdiction or assignment. Any judge can docket any free-text ID and read any FIR through the public E7/E8. [SRC]
- **The docket is properly scoped per judge** (all reads filter by `judge_id`; edit and delete verify ownership). [SRC]
- **The `admin` role is admitted to the page (E1) but refused by every docket call (403).** The website admin therefore sees a page that fails. [SRC] In Flutter, admin lands on the police console. N/A.
- The FIR data on the judge page comes from a public endpoint. This is the pre-existing lawyer G5/LL-5, not new. [SRC]

---

## D4 — Website Judge Feature Extraction

**Searched:**
- `grep -rniI judge` over `website/` (excluding `venv`) → `app.py`, `main/judge_routes.py`, `main/admin_routes.py`, `main/storage_service.py`, `main/auth_routes.py` (legacy, unregistered: `main/__init__.py` registers none of the judge files, and `app.py` does not call `register_blueprints`) and the templates `judge_dashboard`, `admin_dashboard`, `signup`, `landing`, `missing_persons*`.
- Only `judge_dashboard.html` is a Judge UI. `signup.html` holds the role tile and the hint "Judge: JUDxxx" (378-399, 467). `landing.html` is marketing copy only.

Line refs are into JD unless noted.

### 4.0 Shell (JD:50-99, `showPage` 468-487)
- Hover sidebar (blue-900): "NyayaAI" / "Judge Portal".
- Nav: **Home · Case Docket · Case Workspace · Law Library · Orders & Drafts**.
  - "Orders & Drafts" (85-87) has no `id` and no listener, so a click follows `href="#"` and nothing changes. It is inert.
- Footer: avatar letter `session.get('name','J')[0]` + `session.get('name','Judge')`. This is always "J" / "Judge" (Headline 4).
- **No top bar, no sign-out, no profile.**
- `showPage` toggles sections (state is preserved) and scrolls to the top.
  - Entering Library loads the acts **once** per page load (`window._libraryLoaded`).
  - Entering Workspace through the **nav** calls `loadWorkspace()` (486). No other path refreshes it.
- On page load (1190-1192): `loadDocket()`, `loadFirOptions()`, `showPage('home')`.

### 4.1 Home (102-192)
- **Hero:**
  - badge "Powered by NyayaAI · Judge Portal"
  - "Welcome back, **Judge**." (name quirk)
  - "Manage your docket, review cases, and issue orders — all from one place." (copy only; no order feature exists)
  - **View Docket** → `showPage('docket')`
- **Stats (124-144):** Total Hearings, Urgent, Scheduled, Hearings This Week (`updateStats` 623-635).
  - Initial value `0`.
  - Computed from the **last `loadDocket` result, which is filtered by the Docket page's status and urgency selects.** Changing a docket filter therefore also changes the Home numbers (quirk).
  - "This week" means `now ≤ new Date(hearing_date) ≤ now + 7 days`, with any status.
- **Quick Actions (148-179):**
  - View Docket ("See all scheduled hearings")
  - Add a Hearing ("Schedule a new case hearing"): opens Docket, then clicks `+ New Hearing` after 50 ms
  - Law Library ("Browse acts & research precedents")
- **Upcoming Hearings (182-191, `renderUpcomingHearings` 596-621):**
  - Initial "Loading…".
  - Rows: `status === 'scheduled'` and `new Date(hearing_date) ≥ now`, ascending, **first 5**.
  - Each row shows `case_id` (mono), `case_type || 'General'`, the raw `hearing_date` string and an urgency pill (urgent red, otherwise indigo).
  - Empty: "No upcoming hearings".
  - **Not tappable.**
  - Uses the same filtered list as the stats.
- **No error handling.** `loadDocket` has no try/catch, so a failed fetch leaves "Loading…" and the zeros in place.

### 4.2 Case Docket (196-248; JS 582-767)
- Title "Case Docket"; button **+ New Hearing**.
- Filters:
  - Status: "All Status" / Scheduled / Adjourned / Completed / Cancelled
  - Urgency: "All Urgency" / Urgent / Normal
  - **Refresh**
  - A change → `loadDocket()` → E2 with the non-empty params. This re-renders the table, stats and upcoming list.
- **Table** columns: Case ID, Hearing Date (raw string), Type (`|| '-'`), Urgency pill, Status pill, Remarks (`|| '-'`), Actions (**Edit** / **Delete**).
  - Urgent rows have an orange background (`.row-urgent` #fff7ed).
  - Pill colours (571-580):
    - scheduled: blue
    - adjourned: yellow
    - completed: green
    - cancelled: slate
    - urgent: red
    - normal: indigo
  - Empty: "No hearings found" (colspan 7).
- **Delete** (691-695): `confirm("Delete this hearing entry?")` → E5 → `loadDocket()`. The response is not checked, so an error is silent.
- **Edit** (684-689): fetches the **unfiltered** docket (E2), finds the entry by `id` and opens the modal. If the entry is not found, nothing happens.
- **Hearing modal** (365-441; `openModal` 661-676; save 713-763):
  - Title "New Hearing" / "Edit Hearing"; close ×, **Cancel**, or a click on the backdrop.
  - Fields:
    - **Case ID (FIR Number)**, with placeholder "Search FIR number, complainant, or district…".
      - **Autocomplete** (509-545) over the FIR list loaded once at page load (E7).
      - A case-insensitive substring match on `fir_no`, `complainant_name` or `dist`, showing the first 8.
      - Each row shows `fir_no` and "complainant — dist". No match: "No matching FIR found".
      - The dropdown closes on any click outside.
      - **Preview line** (547-564), based on an exact `fir_no` match:
        - green `✓ {complainant_name||'Unknown'} · {dist||''} · {act_sections||'No sections'}`
        - otherwise red "⚠ No matching FIR record found — hearing will still save, but Case Workspace won't show FIR details."
        - hidden when the field is empty.
    - **Hearing Date & Time**: `datetime-local`. `min` is now for a new entry and none for an edit. Edit pre-fills `hearing_date.replace(" ", "T")`.
    - **Case Type**: free text, placeholder "e.g. Criminal, Civil".
    - **Urgency** (Normal/Urgent, default Normal).
    - **Status** (4 values, default Scheduled).
    - **Remarks**: 3-row textarea.
  - Client validation, in order, shown in the red `conflictWarning` box:
    1. "Case ID is required."
    2. "Hearing date & time is required."
    3. if new, or the date string differs from the original: "Hearing date cannot be in the past." (local time)
    4. new only: fetch E2 and, on a case-insensitive `case_id` match, "Case {caseId} is already in your docket."
  - Payload: `{case_id, hearing_date:"YYYY-MM-DD HH:MM", case_type, urgency, status, remarks}` → E3 (POST) or E4 (PUT `/judge/docket/{id}`).
  - Error → `err.message || err.error || "Could not save hearing."`. **The E4 404 shows "not_found"** (its `error` value; there is no `message`).
  - Success → close and `loadDocket()`. The Workspace is **not** refreshed.
  - **No loading state.** The Save button is never disabled, so a double tap can double-submit; the server's duplicate check blocks a second create.

### 4.3 Case Workspace (252-290; JS 770-841)
- Loads on nav entry (E2, **unfiltered**).
  - Groups entries by `case_id`, in server order (`hearing_date` asc).
  - One card per case: `case_id`; "{latest.case_type||'General'} · N hearing(s)"; status pill of the **last** entry.
  - Empty: "No cases in your docket yet."
  - No loading or error state.
- Because E3 rejects duplicates, a case normally has **one** entry, so "N hearings" is 1 unless rows predate the duplicate rule (JR diff `f3e6f5f..14ef68e`).
- **Detail panel** (`openWorkspaceDetail` 803-837), shown below the cards and scrolled into view:
  - header `case_id` + `items[0].case_type || "General"`; close ×.
  - **FIR Details:** "Loading…", then E8 → Complainant, District, Police Station, Act/Sections, Status (each `|| '-'`). Not found or error: "No linked FIR record found for this Case ID."
  - **Hearing Timeline:** ascending; each entry shows the date (raw), a status pill and `remarks || 'No remarks'`.
  - **Read-only**: no actions.
  - The panel stays open, with old content, if the judge leaves and returns.

### 4.4 Law Library (294-359; JS 843-1188)
Three tabs: **Browse Acts** (default), **Precedent Research**, **Bookmarks** (`switchLibraryTab` 1049-1062).

**Browse Acts:**
- Act list (E9, `loadActs` 877-903). Each act shows:
  - its code;
  - its full label (`ACT_LABELS` 844-853);
  - a badge: IPC/CRPC/IEA **"Repealed — see BNS/BNSS/BSA"** (orange); the others **"Current law"** (green) (`ACT_META` 866-875);
  - link **"Open Bare Act (PDF) ↗"** → new tab `/open-bare-act/{code}` (E12);
  - for repealed acts, **"Open Current Law (BNS|BNSS|BSA) ↗"**.
  - No loading or error state.
- Tap an act → highlight → clear the search → `loadSections` (927-959):
  - "Loading…" → E10 (`page`, `limit=15`, `search`).
  - Rows: "Section {n}", the title, and ★ if bookmarked.
  - No results, or an error body: "No sections found".
  - Before any act is chosen: "Select an act to browse its sections".
- **Search box:** placeholder "Search sections by number, title, or keyword — select an act to narrow, or search all acts…". Debounced 350 ms; resets to page 1.
  - **It only searches when an act is selected. "or search all acts" is not implemented** (quirk; preserve).
- **Pagination** (961-974): hidden when there is ≤ 1 page; otherwise "Prev" / "Page x of y" / "Next".
- **Section detail modal** (444-462, 976-994): "{ACT} § {section} — {title}"; description or "No description available."; **☆ Bookmark / ★ Bookmarked** toggle; close × or backdrop. The data comes from the list row; there is no extra fetch.

**Bookmarks** (996-1047):
- Toggle adds or removes `{act, section, title}` in `localStorage`, then refreshes the list stars and the bookmarks list.
- Tab list: "{ACT} § {section}" + title + **Remove**. Empty: "No bookmarked sections yet".
- Tapping a bookmark → E11 → modal.
  - ⚠️ With no error handling, a 404 renders "ACT § undefined — undefined" and "No description available." (quirk).
- Bookmarks are re-rendered only when the tab is entered or a toggle occurs.

**Precedent Research** (336-349, 1160-1188):
- Label "Ask about precedents, sections, or legal principles"; textarea (3 rows) with placeholder "e.g. Supreme Court precedents on anticipatory bail in economic offences"; **Research** button. An empty query does nothing.
- While waiting: button "Researching…" (disabled); result "Searching case law and statutes…".
- Then E6 `{query}`:
  - `data.error` → red text (for example "Unauthorized");
  - network or JSON failure → "Something went wrong. Please try again.";
  - otherwise `renderResearchResult` (1082-1158) renders these blocks, in order and each only if present:
    1. **Current Law**: "Section {current.section} — {current.act}", the subject, and "Historical corresponding provision: Section {h.section}, {h.act}".
    2. **Directly Relevant Precedents**: case cards (`renderCaseCard` 1064-1080):
       - case; "citation · court · bench · year"
       - Verified/Unverified badge
       - "Historical provision: Section X Act"
       - **Key Holding**; **Why Relevant**
       - italic orange `later_development_text`
       - **Source ↗** external link

       If there are none, the orange **`no_result_notice`** box is shown instead.
    3. **Related Authorities** (the same cards, with a lighter border).
    4. **Key Legal Principles** ("principle: explanation").
    5. **Relevant Statutory Provisions**: "{act} § {section} — {subject}" + a Current/Historical badge.
    6. **AI-Generated Research Synthesis**: summary (pre-wrap), "Current-law position:", "Historical-law position:", "Important qualification:", then the italic `ai_notice`. This block is omitted entirely when `synthesis` is null.
    7. **Sources & Verification**: "case — citation" + a Verified/Unverified badge.

    Nothing rendered → "No results.".
- **There is no history.** Each result replaces the last.

### 4.5 Auth entry points (shared pages)
- Sign-up: the Judge tile; Unique ID "JUDxxx" (signup.html:378-399).
- Login: judge → `/` → `/judge-dashboard`.
- "Forgot password?" is the shared dead link (Citizen L3). It is not Judge-specific.

### 4.6 Confirmed absent from the website Judge experience (do NOT build)
- orders, judgments, verdicts, decision records, case disposition
- order or draft generation (the "Orders & Drafts" nav item is inert)
- warrants, summons, bail orders, bail risk, sentencing guide, remand tracker, charge framing, accused profile (all F22–F35, removed 2026-09-15)
- document viewing or uploading; evidence access
- FIR status changes; any write to `firs`
- case assignment, allocation or claiming
- notifications
- profile view or edit; photo; settings
- sign-out control (OQ-J1)
- calendar view
- search across all acts (placeholder text only)
- cross-device bookmarks
- research history
- export or print

---

## D5 — Master Judge Feature Inventory

Status legend (brief §6):
- **A** = existing and reusable
- **A-None** = presentation-only or device-local
- **B** = partial support; needs a backend change for full parity
- **C** = missing
- **U** = unverified

"Flutter today" = whether any Flutter code calls that endpoint now.

| # | Judge Feature | Website Route | Component/File | User Actions | API/Backend | Data Model | Proposed Flutter Screen | Status | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| J-1 | Judge registration | `/signup` | signup.html:378-399, 467 | pick Judge, enter `JUD…` | `POST /signup` (app:2734-2826) | Mongo `users` | existing `signup_screen.dart` (no change) | **A** | `user_role.dart:10`, `auth_contract_test.dart:20-34` |
| J-2 | Login → Judge portal landing | `/login` → `/` → `/judge-dashboard` | login.html:502-503; app:593-594, 680-686 | sign in | `POST /login`; `GET /api/me` | `AuthUser` | `role_home_screen.dart` judge branch → `JudgeShell` | **A** | app:2828-2905; MP:116-133 |
| J-3 | Session restore | `/` | app:589-602 | — | `GET /api/me` | `SessionResponse` | existing splash/auth flow | **A** | `AuthRepositoryImpl.restoreSession` |
| J-4 | Portal shell (5 nav items, sidebar name footer) | `/judge-dashboard` | JD:56-96, `showPage` 468-487 | switch section | — | — | new `judge_shell.dart` (Drawer + `IndexedStack`, like `LawyerShell`); name per OQ-J2; sign-out per OQ-J1 | **A-None** | JD:56-96 |
| J-5 | Home hero + View Docket | `#home-page` | JD:104-120 | View Docket | — | — | new `judge_home_screen.dart` | **A-None** (name quirk: OQ-J2) | JD:110 vs app:2883 |
| J-6 | Home stats (Total, Urgent, Scheduled, This Week) | `#home-page` | JD:123-145, `updateStats` 623-635 | view | E2 (last, **filtered**, load) | `DocketEntry` | part of J-5 | **A** (filter coupling: OQ-J4) | JD:582-594 |
| J-7 | Home quick actions (3) | `#home-page` | JD:148-179 | View Docket / Add a Hearing / Law Library | — | — | part of J-5 | **A-None** | JD:153-176 |
| J-8 | Home upcoming hearings (scheduled, ≥ now, top 5) | `#home-page` | JD:182-191, 596-621 | view only | E2 | `DocketEntry` | part of J-5 | **A** | JD:599-602 |
| J-9 | Docket list + status/urgency filters + Refresh + pills + urgent highlight + empty state | `#docket-page` | JD:196-248, 582-659, 709-711 | filter, refresh | E2 `GET /judge/docket?status&urgency` (JR:33-42; SS:176-182) | `case_docket` → `DocketEntry` | new `docket_screen.dart` (cards instead of a 7-column table) | **A** | JR:33-42 |
| J-10 | New hearing (modal, validation, duplicate pre-check, server errors) | `#docket-page` modal | JD:365-441, 661-676, 713-763 | fill, Save, Cancel | E3 `POST /judge/docket` (JR:45-90; SS:164-173) | `case_docket` | new `hearing_form_sheet.dart` (full-screen sheet) | **A**; date round-trip **U** (GJ-1) | JR:54-80 |
| J-11 | FIR autocomplete + match preview in the modal | modal | JD:376-385, 500-564, 697-707 | type, pick FIR | E7 `GET /api/fir-records` (app:2450) | `FirRecord` (existing) | inside J-10 (reuse `firRepositoryProvider.history()`) | **A** (public endpoint: GJ-4) | JD:502, 519-523 |
| J-12 | Edit hearing | table "Edit" | JD:654, 684-689, 713-763 | edit, Save | E2 (unfiltered) + E4 `PUT /judge/docket/<id>` (JR:93-124) | `case_docket` | same sheet, title "Edit Hearing" | **A**; past-date edit and display **U** (GJ-1); `case_id` edits silently ignored (GJ-3) | JR:106-123 |
| J-13 | Delete hearing (confirm) | table "Delete" | JD:655, 691-695 | confirm, delete | E5 `DELETE /judge/docket/<id>` (JR:127-139) | `case_docket` | confirmation dialog "Delete this hearing entry?" | **A** | JR:134-139 |
| J-14 | Case Workspace list (grouped by case) | `#workspace-page` | JD:258-259, 770-801 | open case | E2 (unfiltered) | `DocketEntry` grouped | new `judge_workspace_screen.dart` | **A** | JD:771-778 |
| J-15 | Workspace detail: FIR details + hearing timeline | `#workspace-page` | JD:261-288, 803-841 | view, close | E8 `GET /api/fir-records/<fir>` (app:2464) | `FirRecord` (existing) + `DocketEntry` | detail view inside the Workspace section (back closes it) | **A** | JD:822-833 |
| J-16 | Law Library act list + repeal badges | Library › Browse | JD:313-318, 844-903 | pick act | E9 `GET /api/acts` | list of codes | new `judge_library_screen.dart` (reuse `legalRepositoryProvider.acts()`) | **A** | app:452, 623-626 |
| J-17 | Open Bare Act / Open Current Law (external) | Library › Browse | JD:886-906 | tap link | E12 `GET /open-bare-act/<code>` (app:1246-1275) | `BARE_ACTS_INFO` | `url_launcher` external open of `{baseUrl}/open-bare-act/{code}` (the Lawyer OQ-L4 precedent) | **A** | JD:905 |
| J-18 | Browse sections per act: debounced search (act required), 15 per page, pagination | Library › Browse | JD:319-331, 908-974 | search, page | E10 `GET /api/sections/<act>` | `LegalSectionPage` (existing) | part of J-16 (reuse `legalRepositoryProvider.sections(limit:15)`) | **A** | app:1051-1105 |
| J-19 | Section detail modal | modal | JD:444-462, 976-994 | view, close | — (row data) | `LegalSection` | bottom sheet | **A-None** | JD:978-979 |
| J-20 | Bookmarks: toggle, ★ in list, tab list, remove, open | Library › Bookmarks + modal | JD:351-357, 456-459, 996-1047 | bookmark, remove, open | device-local storage; E11 `GET /api/section-detail` (app:1110) to open | `{act, section, title}` | Bookmarks tab; store via `SecureStorageService` key `nyayaai_judge_bookmarks` (OQ-J5) | **A-None** (storage) + **A** (E11) | JD:998, 1039 |
| J-21 | Precedent Research (structured result, 7 blocks, notices) | Library › Research | JD:336-349, 1064-1188 | ask | E6 `POST /judge/precedents` (app:1989-2078) | response map → `PrecedentResearch` | Research tab | **A** (curated data; synthesis depends on Groq; graceful null) | app:2026-2078 |
| J-22 | Library tab switching | Library | JD:300-310, 1049-1062 | switch tab | — | — | `TabBar` inside the Library section | **A-None** | JD:1049-1062 |
| J-23 | "Orders & Drafts" nav item | sidebar | JD:85-87 | none (inert) | **none** | — | per OQ-J3 (inert drawer item, or omitted) | **N/A — no website functionality** | no `id`, no listener, no section |

**Row count: 23** (22 functional features + 1 inert nav item). Every D4 block maps to rows:
- 4.0 → J-4, J-23
- 4.1 → J-5…J-8
- 4.2 → J-9…J-13
- 4.3 → J-14, J-15
- 4.4 → J-16…J-22
- 4.5 → J-1…J-3

**Sign-out is deliberately not a row:** the website has none (OQ-J1).

**Overlap with other roles:**
- J-11 and J-15 reuse Police's FIR endpoints (as Lawyer does).
- J-16…J-20 reuse the Police law-library endpoints.
- **No Judge feature writes data any other role reads.**

---

## D6 — Backend Gap and Risk Report

*Specification only. Nothing is implemented. Unless the owner decides otherwise, each gap ships as a documented limitation (JL-n), following the Lawyer precedent.*

### Backend Gap GJ-1: `case_docket.hearing_date` storage type and round-trip — Status **U** → limitation JL-1
- **Website behaviour:**
  - The page sends `"YYYY-MM-DD HH:MM"` (JD:723).
  - It displays whatever string comes back, raw (JD:616, 648, 813).
  - Edit pre-fills `hearing_date.replace(" ","T")` (JD:667).
  - The page treats the date as changed when `hearingDate !== editingOriginalDate` (JD:726). The server uses the same comparison (JR:106).
- **Evidence:** SS:164-173 inserts the string as given. No DDL exists in the repo.
- **Current backend support:** the behaviour depends on the column type:
  - **If `timestamp`:** PostgREST returns `"YYYY-MM-DDTHH:MM:SS"`. Every edit then counts as a date change, so **an entry whose hearing time has passed can no longer be edited, for example marked "completed"**: "Hearing date cannot be in the past.". The display shows the ISO form. [INF]
  - **If `timestamptz`:** the same as `timestamp`, plus an offset and a possible timezone shift. [INF]
  - **If `text`:** the display and edits work, but the conflict check's string range `gte/lte` of `isoformat()` values (`…T09:30:00`) never matches values stored with a space (`' '` < `'T'`), so **overlap detection never fires**. [INF]
- **Current Flutter support:** none.
- **Required change:** none for parity. Flutter must send exactly `"YYYY-MM-DD HH:MM"` and compare raw strings, as the page does.
- **Authentication / Authorization:** unaffected.
- **Data model impact:** none (to confirm only).
- **Flutter dependency:** display formatting and the edit-flow tests depend on the answer.
- **Risk:** past-hearing edits or conflict detection may silently fail. The website has the same behaviour.
- **Recommended next step:** a live probe with a test judge account (OQ-J7). Create one future entry for `ZZFLUTTER-J…`, read it back, record the exact `hearing_date` string, then delete it.

### Backend Gap GJ-2: One docket entry per case, forever — Status **B (design quirk)** → limitation JL-2
- **Website behaviour:** the Workspace groups by case and shows "N hearings" plus a timeline (JD:788-817), which implies several hearings per case.
- **Evidence:** E3 rejects any `case_id` already in the judge's docket, **whatever its status** (JR:67-73). The client repeats the check (JD:731-738).
- **Current backend support:** a case can be re-listed only by editing its single entry (date, status). The adjournment history is therefore overwritten, not appended.
- **Current Flutter support:** none.
- **Required change (only if the owner wants multi-hearing timelines):** limit the duplicate rule to active statuses, or drop it.
- **Authentication / Authorization:** unchanged.
- **Data model impact:** none.
- **Flutter dependency:** none for parity.
- **Risk:** the timeline is almost always one row. This is parity behaviour.
- **Recommended next step:** preserve it. Note it in the parity report.

### Backend Gap GJ-3: Silently ignored fields — Status **B (minor)** → limitation JL-3
- **Website behaviour:** a judge can choose a Status on a new entry, and can change the Case ID while editing.
- **Evidence:**
  - POST: SS:170 hard-codes `status: "scheduled"`.
  - PUT: the allow-list at JR:121-122 excludes `case_id`.
- **Current backend support:** both are dropped without an error, and the page shows success.
- **Current Flutter support:** none.
- **Required change:** honour the fields, or reject them with a message.
- **Authentication / Authorization:** unchanged.
- **Data model impact:** none.
- **Flutter dependency:** for parity, Flutter sends the same payload and shows the same success.
- **Risk:** the user believes a change was saved when it was not.
- **Recommended next step:** preserve. Document it.

### Backend Gap GJ-4: Public, unfiltered FIR list and detail on the judge page — Status **B (security, pre-existing)** → limitation JL-4 (= lawyer LL-5 / G5)
- **Website behaviour:** the hearing-modal autocomplete downloads every FIR (E7). The Workspace reads any FIR (E8).
- **Evidence:** app:2450-2479. No session check.
- **Current backend support:** works for anyone, including signed-out callers.
- **Current Flutter support:** `FirRemoteDataSource.history()` / `record()` already call both.
- **Required change:** session plus role checks on E7/E8 (the same as G5). A narrow search endpoint for the autocomplete would avoid sending every column.
- **Authentication / Authorization:** no judge-to-case authorization model exists (D3 §4).
- **Data model impact:** none.
- **Flutter dependency:** none. The cookie is already sent.
- **Risk:** the exposure of complainant personal data is pre-existing. The judge feature adds a full-collection download on every portal start (the page does this too).
- **Recommended next step:** owner awareness only. Not a Judge blocker.

### Backend Gap GJ-5: No judge authorization model beyond role — Status **C (security)** → limitation JL-5
- **Website behaviour:** a judge schedules any free-text case ID.
- **Evidence:**
  - JR:11-14 checks the role only;
  - no court or assignment field exists in `users` (app:2803-2812) or in `case_docket` (SS:165-173);
  - `case_id` has no foreign key.
- **Current backend support:** per-judge scoping of the docket only (correct).
- **Current Flutter support:** none.
- **Required change:** only if the owner wants it. A judge-to-court or case assignment model would be a new design, not parity.
- **Authentication / Authorization:** the gap is the missing assignment rule.
- **Data model impact:** new fields or tables (unspecified, since no requirement exists).
- **Flutter dependency:** none.
- **Risk:** any account registered with a `JUD…` ID is a judge. Sign-up accepts any unused `JUD` ID, with no verification (app:2769-2793).
- **Recommended next step:** document only.

### Backend Gap GJ-6: Judge page identity and session gaps (template, not API) — Status **B** → limitation JL-6
- **Website behaviour:**
  - the name always reads "Judge" (`session['name']` is never set; login sets `fullname`, app:2883);
  - there is no sign-out control;
  - `_require_judge` answers 403 rather than 401 to a signed-out caller (JR:12-13).
- **Evidence:** JD:92-94, 110; JR:11-14.
- **Current backend support:** `GET /logout` exists and works for every role.
- **Current Flutter support:** `AuthController.logout` exists.
- **Required change:** none in the backend for the Flutter decisions OQ-J1 and OQ-J2.
- **Authentication / Authorization:** Flutter should treat a 403 from `/judge/*` as an authorization or session failure.
- **Data model impact:** none.
- **Flutter dependency:** the app needs a way to switch accounts (a phone has no URL bar).
- **Risk:** without a sign-out, a judge on the app cannot sign out at all.
- **Recommended next step:** an owner decision (OQ-J1, OQ-J2).

### Backend Gap GJ-7: Bookmarks are browser-local — Status **A-None for parity / C for cross-device** → limitation JL-7
- **Website behaviour:** `localStorage` key `nyayaai_judge_bookmarks`, per browser and shared by whoever uses that browser (JD:996-1016).
- **Evidence:** JD:998, 1016, 1045.
- **Current backend support:** none. None is needed for parity.
- **Current Flutter support:** `SecureStorageService` can hold a key.
- **Required change:** none, for parity.
- **Authentication / Authorization:** none.
- **Data model impact:** none.
- **Flutter dependency:** device-local store.
- **Risk:** bookmarks do not sync between the web and the phone, and they survive sign-out (as on the website).
- **Recommended next step:** OQ-J5.

### Backend Gap GJ-8: `POST /judge/precedents` edge cases — Status **B (minor)** → limitation JL-8
- **Website behaviour:** an empty query is blocked client-side.
- **Evidence:**
  - `request.get_json()` with no JSON body → `None.get` → 500 (app:1994-1995);
  - when Groq fails, `synthesis: null` and the AI block is omitted (app:2042-2045).
- **Current backend support:** works for valid JSON.
- **Current Flutter support:** none.
- **Required change:** none. Flutter always sends JSON.
- **Authentication / Authorization:** judge only (401).
- **Data model impact:** none.
- **Flutter dependency:** handle a non-JSON 5xx with the website's text "Something went wrong. Please try again.".
- **Risk:** low.
- **Recommended next step:** none.

### Security and authorization risks (summary)
1. Public FIR read of the full collection (GJ-4, pre-existing).
2. Role-only judge authorization with an unverified `JUD` ID at sign-up (GJ-5).
3. No sign-out on the website judge page (GJ-6).
4. Admin is admitted to the judge page but refused by its API. N/A for Flutter.
5. **Out of Judge scope, but urgent for existing roles:** X-1…X-3 (D2 §3).

**Hiding UI is not treated as security anywhere above.** The Judge shell would be reachable only through the role branch. The server independently enforces judge-only access on every `/judge/*` endpoint, and enforces ownership on edit and delete.

---

## D7 — Judge Implementation Plan (to start only after approval)

**Definition of Done for every step** (Lawyer DoD, unchanged):
- real endpoints only; no mocks in `lib/`;
- loading, success, empty and error states using the website's exact strings where they exist;
- server authorization respected;
- state changes visible without a restart (invalidate providers after each mutation);
- `flutter analyze` clean and the full `flutter test` green after each step;
- no Police, Citizen or Lawyer file changed beyond the list in D1 §3.

### Dependency-based order

Everything Home and Workspace show is derived from the docket list (E2), so the docket data layer and screen come first. The Library is independent of the docket, and Bookmarks depend on the Library.

| Step | Content | D5 rows | Files (new unless marked) |
|---|---|---|---|
| 0 | Owner decisions OQ-J1…J9. With Flask running and approval: a live **probe** with a dedicated test judge (`zz.flutter.judge.<ts>@example.com`, `JUDZZ<ts>`). Sign in; `GET /judge/docket` (expect `[]`); POST one entry for `ZZFLUTTER-J<ts>` 1 year ahead; record the exact returned `hearing_date` (**resolves GJ-1**); PUT status `adjourned`; DELETE. Report what was created. | — | `.claude/plan/judge_implementation_plan.md` |
| 1 | Role branch + `JudgeShell`: Drawer with "NyayaAI / Judge Portal", Home · Case Docket · Case Workspace · Law Library · Orders & Drafts (OQ-J3), footer name (OQ-J2), sign-out (OQ-J1). Retarget the two splash tests. | J-2, J-3, J-4, J-23 | **modified (shared):** `role_home_screen.dart`, `test/widget/features/splash_screen_test.dart`; new `features/judge/presentation/screens/judge_shell.dart`, `controllers/judge_section.dart` |
| 2 | Data layer: `JudgeRemoteDataSource` (E2–E6; same-string date handling; error mapping `message → error → "Could not save hearing."`; 403 handling; non-JSON 5xx → website text); `JudgeRepository`; models `DocketEntry`, `PrecedentResearch` (+ `CurrentLaw`, `PrecedentCase`, `Principle`, `StatutorySection`, `Synthesis`, `ResearchSource`); `judge_content.dart` with verbatim strings and JD line refs | all | **modified (additive):** `api_endpoints.dart`; new `features/judge/data/**`, `domain/**` |
| 3 | Case Docket: filters (status/urgency → query params), Refresh, cards with pills and the urgent tint, empty state, Edit (unfiltered refetch, then find by id), Delete with confirm. **Hearing form sheet:** FIR autocomplete (first 8 matches on fir_no/complainant/dist, "No matching FIR found"), green/red preview, date-time picker (min now for new), Case Type, Urgency, Status, Remarks; the client validation order and messages; duplicate pre-check through E2; server errors shown verbatim. | J-9…J-13 | `docket_screen.dart`, `hearing_form_sheet.dart`, `docket_controller.dart`, widgets `docket_card.dart`, `judge_pills.dart` |
| 4 | Home: hero, 4 stats and upcoming 5 computed from the **same filtered docket state** as the Docket section (OQ-J4); quick actions ("Add a Hearing" → Docket + opens the sheet). | J-5…J-8 | `judge_home_screen.dart` |
| 5 | Case Workspace: grouped cards (unfiltered E2, refreshed on entry), detail with FIR Details (E8 through `firRepositoryProvider.record`, with "No linked FIR record found for this Case ID.") and the hearing timeline. | J-14, J-15 | `judge_workspace_screen.dart` |
| 6 | Law Library › Browse: acts with labels and repeal badges; Open Bare Act / Open Current Law (external `url_launcher`); sections per act (limit 15, 350 ms debounce, search only when an act is selected), pagination; section sheet. | J-16…J-19, J-22 | `judge_library_screen.dart`, `section_detail_sheet.dart`, `judge_library_controller.dart` |
| 7 | Bookmarks: store (`judge_bookmarks_store.dart` over `SecureStorageService`), toggle in the sheet, ★ in the list, tab list, Remove, open through E11. | J-20 | `judge_bookmarks_store.dart`, `bookmarks_tab.dart` |
| 8 | Precedent Research: input, "Researching…", "Searching case law and statutes…", the 7 result blocks in website order, `no_result_notice`, `ai_notice`, Source ↗ external, error strings. | J-21 | `research_tab.dart`, `research_result_view.dart` |
| 9 | Tests and reports (below), the parity table, the regression report | all | `test/**`, `test_live/judge_live_test.dart`, `.claude/spec/judge_parity.md` |

### Test plan (offline)
- **Fakes:** `test/helpers/fake_judge_repository.dart`, `pump_judge_app.dart`. Reuse `fake_fir_repository.dart` and `fake_legal_repository.dart`.
- **Unit:**
  - the request body keys and the date string format `"YYYY-MM-DD HH:MM"`;
  - query params for each filter combination;
  - `DocketEntry.fromJson` tolerating a missing or null `case_type`/`remarks`;
  - stats arithmetic (total, urgent, scheduled, the 7-day window);
  - the upcoming-5 rule (scheduled, ≥ now, ascending);
  - grouping by `case_id` with "latest = last";
  - client validation order and messages;
  - duplicate pre-check, case-insensitive;
  - error-text precedence `message → error → fallback`;
  - FIR autocomplete matching and the limit of 8;
  - preview strings;
  - bookmark add, remove and persistence;
  - research parsing for full, off-topic, `synthesis:null` and `error` responses.
- **Widget:**
  - each section's strings and empty states;
  - modal flows (new, edit, cancel, server 409 conflict, 409 duplicate, 400 past date);
  - delete confirmation;
  - workspace detail with FIR found and not found;
  - library tab switching, pagination and search debounce;
  - research rendering block by block;
  - a 320-px-wide layout pass.
- **Guards:**
  - the judge lands on `JudgeShell`;
  - the judge is still kept off `/fir`, `/evidence`, `/complaints`, `/law`, `/missing-persons` and `/citizen`;
  - police, citizen, lawyer and admin never see `JudgeShell`.

### Live integration plan (only with Flask running and OQ-J7 approved)
- `test_live/judge_live_test.dart`, driven by the app's own `JudgeRemoteDataSource`, against `--dart-define=API_BASE_URL=http://127.0.0.1:5000`. Steps:
  1. Sign up and sign in the dedicated `ZZ` judge; `/api/me` reports role judge.
  2. Docket CRUD on `ZZFLUTTER-J<ts>` IDs only: create; duplicate → 409; overlap within 30 min → 409 (or record that it does not fire: GJ-1); past → 400; edit status; filter; delete.
  3. The non-owner check: a second ZZ judge's PUT and DELETE on the first judge's entry → 404.
  4. A non-judge (an existing ZZ lawyer) calling `/judge/docket` → 403; signed out → 403.
  5. Read-only: `/api/acts`, `/api/sections/IPC?limit=15`, `/api/section-detail`, `/open-bare-act/BNS` (302), `/judge/precedents` (anticipatory bail; off-topic; explicit "section 302 ipc").
- **No real case or FIR is modified.** The docket writes only to `case_docket` rows owned by the ZZ judge. Every created record is listed in the report, and left or deleted per the owner's instruction.

### Regression plan
- Full offline suite plus the analyzer after every step; the role-landing matrix for all 5 roles.
- `law_library_test` and `fir_history_screen_test` untouched.
- When live: the read paths of the auth, legal and fir live suites.
- Lawyer and evidence live differences are attributed to X-1…X-3, not to Judge.

### Acceptance criteria
- Every D5 row J-1…J-22 behaves as in D4, using the website's strings. J-23 follows OQ-J3.
- No endpoint is used that is not in D3. No fake data in `lib/`.
- Every mutation refreshes Docket, Home and (on entry) Workspace without a restart.
- Offline suite green (584 + new); analyzer clean.
- The parity report has 23 rows, each PASS / NOT APPLICABLE / BLOCKED / UNVERIFIED, with evidence.

### Open decisions and blockers (owner answers needed before implementation)

| ID | Question | Options | Recommendation |
|---|---|---|---|
| **OQ-J1** | The website judge page has **no sign-out** (GJ-6). | (a) Sign-out in the app bar, immediate (the Lawyer/Citizen precedent); (b) with a confirmation (the current placeholder style); (c) none (strict parity: a judge on a phone could never sign out) | **(a)**, recorded as a known difference |
| **OQ-J2** | The greeting and footer always read "Judge" / "J" because `session['name']` is never set. | (a) Reproduce literally ("Welcome back, Judge."); (b) use `fullname` (cached or `/api/me` has none; there is no judge profile endpoint, so it would only come from the sign-up cache) | **(a)**. The website determines it, and no server source of the name exists for a fresh login. |
| **OQ-J3** | The "Orders & Drafts" nav item is inert. | (a) Show it, doing nothing (strict); (b) omit it | **(b)**, recorded as a known difference. An inert tap target on mobile reads as a bug, and the item offers no behaviour. Choose (a) if strict visual parity is preferred. |
| **OQ-J4** | Home stats and upcoming hearings follow the Docket's active filters (a quirk). | Replicate or decouple | **Replicate** (website behaviour) |
| **OQ-J5** | Bookmark storage | (a) Device-local through the existing `SecureStorageService`, the same key for every account on the device (= per browser); (b) scoped per `user_id` | **(a)** (parity, no new dependency) |
| **OQ-J6** | The website's missing error handling: docket load failure leaves "Loading…"; a sections error shows "No sections found"; a bookmark 404 renders "§ undefined"; the Workspace has no loading state. | (a) Replicate exactly; (b) the Lawyer X-3/X-4 precedent: add a spinner or Retry where the page shows nothing or garbage, and keep the website's text everywhere it has text | **(b)**, with each difference listed |
| **OQ-J7** | Live verification needs Flask running, plus **writes**: a new Mongo user (the ZZ judge, and a 2nd for the ownership test) and `case_docket` rows. | Approve the probe and live suite with ZZ records only, and say whether records are kept or deleted afterwards | Approve. Delete the docket rows; keep the ZZ users (as Lawyer did) |
| **OQ-J8** | **The backend drift X-1…X-3** (evidence now police-only; claim 409; hearing past-date) affects existing Police and Lawyer behaviour. | (a) A separate maintenance task after Judge; (b) before Judge; (c) ignore | **(a)**. Not Judge scope. It does not block Judge. |
| **OQ-J9** | GJ-1 (date round-trip): if the probe shows `timestamp`, a past entry cannot be edited (marked completed) on the website either. | Replicate or adapt | **Replicate**, after the probe confirms it |

**Hard stop.** This document is analysis only. No Judge code has been written, and no application, website, backend or database file was modified. Implementation starts only after explicit approval of D1–D7 and answers to OQ-J1…OQ-J9.

---

## §8 Implementation record (2026-10-11)

**Approval:** the owner's Phase-2 brief (2026-10-11). Where it left a D7 open question unsettled, the least-change option was taken. Each is listed under "Decisions" below.

### Decisions on OQ-J1…J9

| OQ | Decision | Why |
|---|---|---|
| J1 sign-out | Kept the sign-out the app already gave judges: an app-bar icon with the existing "Sign out?" confirmation | The website has none, and a phone has no URL bar. This keeps the existing `splash_screen_test` sign-out test unchanged. |
| J2 name | "Welcome back, Judge." and a "J" avatar, literally | The website reads `session['name']`, which is never set |
| J3 Orders & Drafts | Shown in the drawer; a tap only closes the drawer | Brief Phase 10: "preserve the navigation behavior", "do not invent" |
| J4 filter coupling | Replicated: Home stats and upcoming hearings follow the Docket filters | Website behaviour |
| J5 bookmarks | Device-local, using the existing `SecureStorageService` under the page's key `nyayaai_judge_bookmarks`. No new dependency. | The website stores them in `localStorage`; no server endpoint exists |
| J6 error UI | A Retry state where the page shows nothing or hangs on "Loading…"; the website's text is used wherever it has text | Brief Phases 6–9 |
| J7 live | Run with ZZ records only (results below) | — |
| J8 X-1…X-3 drift | Not touched | Out of Judge scope |
| J9 GJ-1 | Replicated (compare raw strings, as the page does) | It could not be confirmed live (see §9) |

### Knowing differences from the page

| # | Difference | Why |
|---|---|---|
| JX-1 | Save in the hearing form is disabled while a request is in flight | Brief Phase 7 ("prevent duplicate submissions"). The page allows a double submit. |
| JX-2 | Retry or error states for docket, workspace, acts and sections loads; a snackbar when an edit-fetch, delete or bookmark-open fails | The page shows nothing, hangs on "Loading…", or shows "§ undefined" |
| JX-3 | Workspace FIR details: a network failure shows the error with Retry; any server refusal shows the page's "No linked FIR record found…" | The page shows that sentence for every failure |
| JX-4 | The FIR autocomplete shows "Loading FIR records…" while loading, and a note if the list failed | The page shows nothing |
| JX-5 | Mobile layout changes: a 7-column table becomes cards; the modals become bottom sheets; the act list folds once an act is chosen; the workspace detail replaces the card list (back closes it); `datetime-local` becomes a date picker then a time picker (minute precision) | Phone width |
| JX-6 | The Workspace detail re-renders from the freshly loaded list | The page keeps showing a stale panel |

### Files

**Changed outside `lib/features/judge/`:**
- `lib/features/dashboard/presentation/screens/role_home_screen.dart`: judge branch → `JudgeShell`; the judge "COMING NEXT" list is removed.
- `lib/core/constants/api_endpoints.dart`: additive constants `judgeDocket`, `judgeDocketFiltered`, `judgeDocketEntry`, `judgePrecedents`, `openBareAct`.
- `test/widget/features/splash_screen_test.dart`: a fake judge repository override. "signing in moves from the form to home" now asserts `JudgeShell` and "Welcome back, Judge." instead of the placeholder's name and ID.
- `test/widget/features/fir_route_guard_test.dart`: a fake judge repository override.

**New:**
- `lib/features/judge/**` (13 files)
- `test/helpers/fake_judge_repository.dart`, `test/helpers/pump_judge_app.dart`
- `test/unit/features/judge_test.dart` (16 tests)
- `test/widget/features/judge_portal_test.dart` (34 tests)
- `test_live/judge_live_test.dart`

**Unchanged:** router and routes, `pubspec.yaml`, all Police, Citizen and Lawyer `lib/` code. The Lawyer widgets and the legal/FIR data layers are imported, not modified.

### Offline verification
- `flutter analyze`: no issues.
- `flutter test`: **634/634** (the 584 baseline + 50 new).

## §9 Live integration run (2026-10-11)

**Setup:**
- `website/app.py` at HEAD `14ef68e`, run unmodified.
- `flutter test test_live/judge_live_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:5000`
- Afterwards, `md5sum -c` confirmed that every website source file and `IndiaLaw.db` was unchanged.

**Blocker: the Supabase project is unreachable.** `SUPABASE_URL` → `uafjhimjuyfqkqfnadei.supabase.co` returns **NXDOMAIN** (`nslookup`), while public DNS and Groq work from the same machine. Every Supabase-backed route returns HTTP 500 (`httpx.ConnectError: Name or service not known` in the Flask log):
- `GET/POST/PUT/DELETE /judge/docket*`
- `GET /api/fir-records`
- `GET /api/fir-records/<no>`

This also breaks Police FIR filing and history, Lawyer My Cases, and Citizen client-status in this environment. It is an environment or backend fact, not a Flutter defect, and was not worked around.

| Area | Live result |
|---|---|
| J-1..J-3 | ✅ Two ZZ judges registered (JUD IDs) and signed in; `/api/me` role judge |
| Authorization | ✅ Signed-out `/judge/docket` → 403 → the app's "judge session has ended"; signed-out research → "Unauthorized" |
| J-10 past date | ✅ 400 "Hearing date cannot be in the past." (validated before the DB call) |
| J-9..J-15 docket CRUD, duplicate, conflict, ownership, filters, FIR list/detail | ⛔ **BLOCKED**: HTTP 500 (Supabase NXDOMAIN). GJ-1 (how `hearing_date` is stored) is **still UNVERIFIED**. |
| J-16, J-18 | ✅ `/api/acts` = the 8 acts; IPC: 575 sections, 39 pages of 15; section detail OK |
| J-17 | ✅ The route answers. India Code was unreachable from the server, so it returned **503** (the site's "could not reach" page), not 302. |
| J-21 | ✅ "anticipatory bail" → current law BNSS 482; 3 precedents; 3 principles; 2 statutory provisions; **Groq synthesis present**; AI notice present. "section 302 ipc" → IPC 302 (Historical) and the "Authority could not be verified" notice. Off-topic → the "does not appear to be" notice; synthesis null. |
| J-20 bookmarks | Device-local by design; widget-tested only |

**Records created:**
- Mongo users `zz.flutter.judge.1791670862673@example.com` (JUDZZ1670862673) and `zz.flutter.judge2.1791670862673@example.com` (JUDZZB1670862673). **Left in place**: the app offers no supported way to delete an account.
- **No `case_docket` rows** were created (every insert returned 500).

**Not done:** emulator or device walk-through.

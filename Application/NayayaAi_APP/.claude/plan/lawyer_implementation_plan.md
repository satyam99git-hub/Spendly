# Lawyer-side Flutter implementation plan (website parity)

**Source of truth:** `website/templates/lawyer_dashboard.html` + `website/app.py`.
**Rule 0:** no change to the website, Flask, the DB or templates.
**Directive (2026-09-28):** reproduce the website exactly; ask only where the source cannot decide.

Spec: `.claude/spec/lawyer_D1-D7.md`. Decisions and deviations are in its §8.

## Architecture
- `LawyerRemoteDataSource(dio)` → `LawyerRepositoryImpl` → `lawyerRepositoryProvider`.
- `FutureProvider.autoDispose` for lists, including `.family` per FIR for the workspace tabs.
- Screens are `ConsumerStatefulWidget`s holding the page's transient messages.
- `LawyerShell` = Drawer + `IndexedStack` of five sections, as the page's sidebar and hidden sections. Case Workspace is a section, so the router is untouched.
- The reply handling in the data source copies each JS function: `res.ok` checked or not, `res.json()` first, and "non-list JSON → empty list".

## Steps (all done 2026-09-28)
1. Data layer, models, verbatim content and prompts (`lawyer_content.dart`)
2. Shell + Home
3. My Cases
4. Case Workspace: Overview, status, share, AI Summary, Documents, Hearings, Deadlines, Drafts
5. Legal Assistant
6. All Drafts
7. Profile
8. Role branch
9. Tests

## Progress log
**2026-09-28:**
- Steps 1–9 are done.
- `flutter analyze` is clean.
- `flutter test`: 584/584.

**Open items:**
1. Live run against Flask with a test `LAW` account and a `ZZFLUTTER` test FIR only. Never claim a real FIR: E2 overwrites `assigned_lawyer_id`.
2. Run the manual script on an emulator or device:
   - sign up as lawyer → claim → status → share;
   - check that the citizen sees it in My Case Status;
   - hearing → deadline → draft → summary/assistant (expect LL-2) → profile/photo;
   - sign out.

**2026-09-28, live run:**
- `test_live/lawyer_live_test.dart`: 25/25 against unmodified Flask.
- LL-1/LL-2/LL-3 were observed and documented, not fixed (spec §9).
- The test records were left in place by owner decision.
- Remaining: the on-device walk-through.

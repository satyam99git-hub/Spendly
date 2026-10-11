# Citizen-side Flutter implementation plan (website parity)

## Context
The Flutter app (`Application/NayayaAi_APP/flutter_app`) has a working Police console, but a citizen who signs in sees only a non-interactive "COMING NEXT" list (`features/dashboard/presentation/screens/role_home_screen.dart:102-124`).

The owner's directive:
- Reproduce the website's Citizen experience (`website/templates/citizen_dashboard.html` + `missing_persons_fragment.html`) feature-for-feature, natively in Flutter.
- Call the **same existing endpoints**.
- Change **nothing** in the website, backend, Flask routes, DB logic or templates.
- Invent nothing.

The audit (D1–D4) and the parity spec (P-1…P-20, limitations L1–L9, decisions D-1…D-5) are done. The owner asked to store the spec in `.claude/spec/` and the plan in `.claude/plan/`, then implement.

Recorded decisions:
- **D-1:** phone is optional; if given it must be exactly 10 digits.
- **D-2:** Ambulance shows and dials 108.
- **D-3:** shared auth screens get behaviour-only changes (confirm password, strength meter, existing-email message), no wording changes.
- **D-4a:** citizens sign out immediately, with no confirmation.
- Working assumptions: the P-17 detail screen is allowed, the landing page is not reproduced, and `url_launcher` is added (it is already in the pub cache as 6.3.2).

## Step 0 — File housekeeping (first action after approval)
- Copy `docs/audit/D5P_citizen_parity_spec.md` to `Application/NayayaAi_APP/.claude/spec/citizen_parity_spec.md`.
  - Update its P-13 row to say that track uses a new citizen data source that reuses `ComplaintResponse.fromJson`. This keeps the website's error text without touching the Police data source.
- Copy D1–D4 to `.claude/spec/` as well, so the spec folder holds the full source of truth. The `docs/audit/` originals stay in place.
- Write this plan to `Application/NayayaAi_APP/.claude/plan/citizen_implementation_plan.md`.

## Architecture (follows existing patterns exactly)
- **Riverpod layering:** `RemoteDataSource(dio)` → `RepositoryImpl` → `Provider`, then `AutoDisposeNotifier` controllers. This is the pattern in `features/legal/presentation/controllers/legal_providers.dart` and `legal_query_controllers.dart`.
- **Errors:** all errors become `Failure` (`core/error/failure.dart`). Citizen data sources map errors to the **website's exact strings** (from spec §3):
  - network → the website's network text;
  - HTTP error with a JSON `error`/`answer` → that server text;
  - anything else → the website fallback.
- **New feature folder:** `lib/features/citizen/`, laid out as `data/{datasources,models,repositories}`, `domain/{entities,repositories}`, `presentation/{controllers,screens,widgets}`. It holds the shell and all citizen-only screens. Existing entities and widgets are imported from other features **unchanged**:
  - `Complaint`, `ComplaintResponse.fromJson`, `ComplaintStatus` (complaints)
  - `MissingPersonRepository` via `missingPersonRepositoryProvider`, `missingPersonsProvider`, `PersonPhoto` (missing_persons)
  - `evidenceFilePickerProvider`, `EvidenceSource` (evidence)
  - shared widgets: `AppTextField`, `AppTextArea`, `PrimaryButton`, `SecondaryButton`, `FormBanner`, `StateMessage`; theme tokens `AppSpacing`, `AppRadius`, `AppColors`.
- **Static website content** goes in one constants file, `features/citizen/domain/entities/citizen_content.dart`, transcribed verbatim with CD line references, following the precedent of `legal_reference.dart`. It holds:
  - emergency cards (with 108 per D-2) and the home strip
  - safety tips
  - the 6 rights topics and 3 quick-action questions
  - timeline steps and descriptions
  - all headings, labels, placeholders and messages

## Files

### Modified (existing)
- `pubspec.yaml`: add `url_launcher: ^6.3.2`.
- `android/app/src/main/AndroidManifest.xml`: add a `<queries><intent>` for `android.intent.action.DIAL` with `tel` scheme, so dialling works on Android 11+.
- `lib/routes/app_routes.dart`:
  - add `citizenPrefix = '/citizen'`, `citizenMissingPerson = '/citizen/missing-persons/:personId'` + name, and `citizenPrefixes`.
  - Police prefixes are untouched.
- `lib/routes/app_router.dart`:
  - add redirect step 6: any path under `citizenPrefixes` with `role != citizen` → `/home`.
  - add the citizen detail `GoRoute`.
  - Police steps are unchanged.
- `lib/features/dashboard/presentation/screens/role_home_screen.dart`: `if (user.role == UserRole.citizen) return const CitizenShell();`. Remove the citizen entries from `_plannedFor`; that case returns `[]` as unreachable, the same as police.
- **Auth (D-3, AUTH-1):**
  - `features/authentication/domain/repositories/auth_repository.dart` + `data/repositories/auth_repository_impl.dart` + `presentation/controllers/auth_controller.dart`: `signup` returns `SignupResult({uniqueId, message})` instead of `String`. `SignupResponse` already parses `message`.
  - `features/authentication/presentation/screens/signup_screen.dart`:
    - add a **Confirm password** `PasswordField` validated with the existing `Validators.confirmPassword`, which already has the text "Passwords do not match";
    - add the non-blocking **4-bar strength meter** (new `shared/widgets/inputs/password_strength_meter.dart`; rules: len≥6, len≥10, upper+digit, special; weak/medium/strong);
    - when `uniqueId` is empty, the success dialog shows the server `message` with no ID block, instead of "Account created".
    - Headings and labels stay unchanged.
  - `test/helpers/fake_auth_repository.dart` + the affected signup tests: adapt to `SignupResult`.

### New (all under `lib/features/citizen/`)
| Spec | Files | Endpoint (existing, unchanged) |
|---|---|---|
| P-5 shell, P-9 logout | `presentation/screens/citizen_shell.dart` | `GET /logout` via `AuthController.logout()` |
| P-6/7/8 home | `presentation/screens/citizen_home_screen.dart`, `presentation/widgets/emergency_dial_button.dart` | — (`tel:` via url_launcher) |
| P-10 emergency | `presentation/screens/emergency_contacts_screen.dart` | — |
| P-11/12 file complaint | `data/datasources/citizen_complaint_remote_data_source.dart` (`file`, `track`), `data/models/citizen_complaint_models.dart` (`ComplaintSubmission.toJson`, `ComplaintReceipt.fromJson`), `data/repositories/…`, `presentation/controllers/complaint_form_controller.dart`, `presentation/screens/file_complaint_screen.dart` | `POST /api/complaint` |
| P-13 track | `presentation/controllers/track_complaint_controller.dart`, `presentation/screens/track_complaint_screen.dart`, `presentation/widgets/complaint_timeline.dart` | `GET /api/complaint/<id>` (parsed with the existing `ComplaintResponse.fromJson`) |
| P-14 rights | `data/datasources/rights_chat_remote_data_source.dart` (returns `answer` for **any** status whose body has `answer`; otherwise throws), repository, `presentation/controllers/rights_chat_controller.dart` (a message list; a busy "Thinking…" entry), `presentation/screens/rights_chat_screen.dart`, `presentation/widgets/rights_answer_text.dart` (formatAnswer: `**bold**`, `-`/`•` bullets, newlines, via `Text.rich`) | `POST /api/rights-chat` |
| P-15 case status | `data/datasources/case_status_remote_data_source.dart`, `data/models/case_client_status.dart`, repository, controller, `presentation/screens/case_status_screen.dart` (the `formatRelativeTime` port lives in the model file) | `GET /api/case/<fir>/client-status` |
| P-16/17/18 missing persons | `presentation/screens/citizen_missing_persons_screen.dart`, `presentation/screens/citizen_missing_person_detail_screen.dart`, `presentation/widgets/citizen_sighting_sheet.dart` (website labels; camera/gallery only; allowed extensions jpg/jpeg/png/gif/webp; the result panel follows the website's match/no-match behaviour and auto-closes after 2 s on a match, then invalidates `missingPersonsProvider`) | `GET /get_missing_persons`, `POST /report_sighting/<id>` via the existing `MissingPersonRepository` |

### Shell behaviour (mirrors `showSection`)
- An `IndexedStack` holds the 7 sections, in website order: Home, File a Complaint, Track Complaint, My Case Status, Know Your Rights, Missing Persons, Emergency Contacts. Keeping them in a stack preserves in-page state, as the website's DOM does.
- A Drawer lists the same 7 entries plus a footer "Sign Out"; its header reads "NyayaAI / Citizen Portal".
- AppBar: "NyayaAI", a "Citizen" chip and a sign-out icon.
- Selecting Missing Persons re-fetches the list (`ref.invalidate(missingPersonsProvider)`), as `loadMissingPersons()` does on every show.
- Home quick actions call `rightsChatController.ask(preset)` and then switch to the Rights section.
- "Track My Complaint →" switches to Track without pre-filling the ID.
- Sign-out is immediate.

## Implementation order
One commit-sized step each. Run `flutter analyze` after every step.
1. Step 0 housekeeping, then `pubspec`/manifest, then `citizen_content.dart`.
2. Routing + `CitizenShell` skeleton + Home + Emergency (P-4…P-10).
3. File complaint + success (P-11, P-12).
4. Track complaint + timeline (P-13).
5. Rights chat (P-14).
6. Case status (P-15).
7. Missing persons list, detail and sighting (P-16…P-18).
8. Signup changes (P-1, D-3, AUTH-1).
9. Tests, then parity audit, then update the spec matrix statuses.

## Tests (follow `test/helpers/pump_*_app.dart` + `fake_*_repository.dart`)
- New fakes: `fake_citizen_complaint_repository.dart`, `fake_rights_chat_repository.dart`, `fake_case_status_repository.dart`. Reuse `FakeMissingPersonRepository` and `FakeEvidenceFilePicker`.
- New helper `test/helpers/pump_citizen_app.dart`.
- Unit tests:
  - request JSON keys match the website payloads exactly;
  - complaint validation messages (name letters/spaces, phone 10 digits, required fields);
  - the `formatRelativeTime` port;
  - the strength-meter rules;
  - timeline index for known and unknown statuses;
  - the rights data source returns `answer` on a 400.
- Widget tests: each section renders the website's exact strings; success/error/empty/loading states; the role guard sends police away from `/citizen/...` and a citizen away from `/fir`.
- Existing 453 tests must still pass. Signup tests are updated only for `SignupResult`.

## Verification
1. `flutter analyze` is clean; `flutter test` passes (the full offline suite).
2. **Live end-to-end** against the real backend, which is not modified:
   - start MongoDB and `website/venv/bin/python app.py`;
   - check the log for `[MissingPersons] face_recognition_helper loaded.` (L4);
   - run the app on the emulator (default `10.0.2.2`) or via `adb reverse`.
3. Manual script:
   - register a citizen, confirm the `CIT###` dialog, and sign in to the Citizen shell;
   - file a complaint and get a tracking ID;
   - track it and see Pending with the timeline;
   - as police in a second session, set Under Review with a note, then re-track as the citizen: the status, timeline and officer notes update;
   - ask a preset rights question;
   - look up a nonexistent FIR in Case Status and get the amber error;
   - open Missing Persons and report a sighting with a photo;
   - check that emergency cards open the dialler;
   - sign out, which is immediate.
   - Also run a Police regression spot-check: login → FIR tab → complaints inbox shows the citizen's complaint.
4. The final parity audit (the 14-question checklist per feature) is recorded in `.claude/spec/citizen_parity_spec.md`, and the matrix statuses move from Pending to Complete only when every check passes. Limitations stay listed.

---

## Progress log

**2026-09-20: implementation steps 1–9 done.**
- `flutter analyze` is clean.
- `flutter test`: 515/515 passed.
- `test_live/citizen_live_test.dart` against the real backend: 12/12 passed.

Full status and the per-feature parity audit are in `.claude/spec/citizen_parity_spec.md` §7.

**Open items:**
1. On-device or emulator run of the manual script above. This is the last check before features move to Complete.
2. Owner confirmation of the working assumptions D-4b (P-17 detail page), D-4c (no landing page) and D-5 (`url_launcher`).
3. The live test left marked records in the shared DB (`CIT014` user, complaint `CMP-1967E48B`, sighting `SG_47076DE998F5` on real case `MP_6CBFDFF92A3A`). Delete them only on the owner's instruction.

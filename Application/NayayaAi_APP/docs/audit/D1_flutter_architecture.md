# D1 — Flutter Architecture Report

**Scope:** `Application/NayayaAi_APP/flutter_app/` (the Flutter project root; `pubspec.yaml` `name: nayaya_app`, version `2.4.0+1`).
**Method:** every statement below comes from reading the source file cited. Paths are relative to `flutter_app/` unless they start with `website/`.
**Audit date:** 2026-09-20.

> **Key architectural fact.** The Flutter app has **no backend of its own**. `Application/NayayaAi_APP/backend/` holds only `.gitkeep` files (zero `.py` files), and `database/schema/*.sql` is not referenced by any Dart file or by the Flask server. At runtime the app talks only to the website's Flask server, `website/app.py` (plus the blueprints `website/missing_person.py` and `website/main/judge_routes.py`). Data lives in three stores behind that server:
> - **MongoDB** `NyayaAI_DB`: `users`, `evidence_files` (`website/app.py:315-317`, `:1693-1694`)
> - **SQLite** `website/IndiaLaw.db`: `citizen_complaints`, `missing_persons`, `missing_person_sightings`, and the 8 law-act tables (`app.py:538-566`, `missing_person.py:67-107`)
> - **Supabase**: table `firs`, storage bucket `firs` for FIR PDFs, and the lawyer/judge tables (`website/main/storage_service.py`)
>
> `website/main/{auth,general,fir,evidence,legal}_routes.py` exist but are **never registered**. Only `judge_bp` (`app.py:93`) and `missing_person_bp` (`app.py:333`) are registered, so those five files are dead code.

---

## 1. Project Structure

### `lib/` tree

| Path | Purpose (verified) |
|---|---|
| `lib/main.dart` | Entry point. Calls `bootstrap()`. |
| `lib/bootstrap.dart` | Locks portrait orientation, sets edge-to-edge UI, builds `DioClient` asynchronously, and wraps the app in `ProviderScope` with `dioClientProvider.overrideWithValue(...)`. |
| `lib/app.dart` | `NayayaApp`: `MaterialApp.router` with `AppTheme.light` / `AppTheme.dark`, `ThemeMode.system`, `routerConfig: appRouterProvider`. |
| `lib/core/config/` | `app_config.dart`: base URL from `--dart-define=API_BASE_URL`, timeouts, splash hold, session-restore timeout. |
| `lib/core/constants/` | `api_endpoints.dart` (every server path the app calls), `api_headers.dart` (`X-NyayaAI-Client` header), `storage_keys.dart` (secure-storage keys). |
| `lib/core/di/` | `providers.dart`: the app-wide singletons `dioClientProvider` (override-only) and `secureStorageProvider`. |
| `lib/core/enums/` | `user_role.dart` (`citizen/police/lawyer/judge/admin`, wire values, ID prefixes, `hasPoliceAccess`), `start_destination.dart` (enum; no references found outside its own file). |
| `lib/core/error/` | `failure.dart` (sealed `Failure` hierarchy), `error_mapper.dart` (maps `DioException` to `Failure`). |
| `lib/core/network/` | `dio_client.dart` (Dio + cookie jar + status interceptor), `interceptors/logging_interceptor.dart`. |
| `lib/core/storage/` | `secure_storage_service.dart`: a `FlutterSecureStorage` wrapper that never throws. |
| `lib/core/utils/` | `validators.dart`, `server_time.dart` (parses server timestamps), `form_dates.dart`, `fir_number.dart`, `fir_pdf.dart`. |
| `lib/core/extensions/`, `core/services/`, `core/usecases/` | **Empty** (`.gitkeep` only). |
| `lib/features/authentication/` | Login, signup, session restore, logout. It has data, domain and presentation layers. |
| `lib/features/dashboard/` | `RoleHomeScreen` (branches on role), `PoliceDashboardScreen` (4-tab console), `dashboard_cards.dart`. `data/` and `domain/` are empty. |
| `lib/features/fir/` | FIR registration wizard (FORM IF-1), AI section suggestions, FIR history, record viewer, PDF download. |
| `lib/features/complaints/` | Police inbox for citizen complaints, complaint detail, respond/escalate/link-FIR actions, filters. |
| `lib/features/evidence/` | PIN-gated evidence locker: list, add (camera/gallery/file), detail. |
| `lib/features/legal/` | Law library, section detail/compare, Ask-Law (RAG), outcome finder, static glossary/BNS reference. |
| `lib/features/missing_persons/` | Case list, register a case, case detail with sightings, report a sighting, mark found. |
| `lib/features/splash/` | `SplashScreen` plus brand animation widgets. `data/` and `domain/` are empty. |
| `lib/features/notifications/`, `features/profile/`, `features/settings/` | **Empty scaffolds**. Every sub-folder contains only `.gitkeep`. |
| `lib/routes/` | `app_router.dart` (GoRouter + auth/role redirect), `app_routes.dart` (paths and names), `transitions/fade_through_route.dart`. |
| `lib/shared/widgets/` | Cross-feature widgets (see §5). `cards/`, `dialogs/`, `layout/` and `loaders/` are empty. |
| `lib/shared/mixins/`, `shared/models/`, `shared/providers/` | **Empty**. |
| `lib/theme/` | `app_colors.dart`, `app_dimensions.dart` (`AppSpacing`, `AppRadius`, `AppSizes`), `app_typography.dart`, `app_theme.dart`. `components/` is empty. |

Other top-level folders:
- `test/`: unit, widget and golden tests, with fake repositories in `test/helpers/fake_*_repository.dart`.
- `test_live/`: tests that hit a real server and write `ZZFLUTTER*` records.
- `android/`: `network_security_config.xml` allows cleartext only to `127.0.0.1`, `localhost` and `10.0.2.2`.
- `tool/`: Python scripts for icon generation.
- `assets/images/logo/emblem.png`: the only bundled asset.

### `pubspec.yaml` dependencies

| Package | Version | Why it is used (verified in code) |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | All state management. `Provider`, `NotifierProvider`, `FutureProvider`, and `.family`/`.autoDispose` variants appear in every `presentation/controllers/*_providers.dart`. |
| `dio` | ^5.7.0 | HTTP client (`core/network/dio_client.dart`). Interceptors handle cookies, logging and error mapping. Also used for multipart uploads (evidence, missing persons) and `dio.download` (FIR PDF). |
| `dio_cookie_manager` | ^3.1.1 | `CookieManager(jar)` interceptor. It attaches the Flask `session` cookie. |
| `cookie_jar` | ^4.0.8 (lock 4.0.9) | `PersistCookieJar(ignoreExpires: true, storage: FileStorage(...))` keeps the session across restarts. |
| `go_router` | ^14.6.2 | Declarative routing plus the auth/role `redirect` (`routes/app_router.dart`). |
| `flutter_secure_storage` | ^9.2.2 | Caches the profile (`nyayaai_cached_user`) and the in-progress FIR draft (`nyayaai_fir_draft`). |
| `path_provider` | ^2.1.5 | Directory for the cookie jar (`<docs>/.cookies`) and for downloaded FIR PDFs (`<docs>/fir_pdfs`). |
| `image_picker` | ^1.1.2 | Camera and gallery capture for evidence, missing-person photos and sighting photos. |
| `file_picker` | ^10.0.0 | Non-image evidence files (PDF, audio, documents). Version floor pinned for compileSdk 36. |
| `open_filex` | ^4.7.0 | Opens a downloaded FIR PDF in the device viewer (`fir/data/datasources/fir_pdf_store.dart`). |
| `flutter_test` (dev) | sdk | Unit, widget and golden tests. |
| `flutter_lints` (dev) | ^4.0.0 | Lint rules (`analysis_options.yaml`). |

Explicitly **not** added (commented in `pubspec.yaml:91-96`): `shared_preferences`, `local_auth`, `google_sign_in`, `flutter_local_notifications`, `package_info_plus`.

---

## 2. Architecture Pattern

| Aspect | Finding |
|---|---|
| **State management** | **Riverpod 2 (`flutter_riverpod`) using `Notifier`/`AsyncValue`.** No code generation (`riverpod_generator` is absent). Examples: `authControllerProvider = NotifierProvider<AuthController, AuthState>` (`features/authentication/presentation/controllers/auth_controller.dart`), `complaintActionControllerProvider = NotifierProvider.autoDispose.family<...>` (`complaint_action_controller.dart`). Lists are exposed through `FutureProvider`s such as `complaintsProvider`. |
| **Dependency injection** | Riverpod providers only. Each feature wires `RemoteDataSource(ref.watch(dioClientProvider).dio)` → `RepositoryImpl` → controller. The only app-wide providers are in `core/di/providers.dart`. |
| **Navigation / routing** | **GoRouter 14** (`routes/app_router.dart`). One top-level `redirect` enforces, in order: (1) hold on splash while `AuthStatus.unknown`; (2) stay put while `authenticating`; (3) signed out → `/login` (`/signup` is allowed); (4) signed in on splash/auth → `/home`; (5) any path starting with `AppRoutes.policePrefixes` (`/fir`, `/evidence`, `/complaints`, `/law`, `/missing-persons`) → `/home` unless `role.hasPoliceAccess`. Refresh is driven by `_AuthRefreshNotifier`, which fires on status change only. |
| **Folder organisation** | **Feature-first, Clean Architecture inside each feature**: `features/<name>/{data/{datasources,models,repositories}, domain/{entities,repositories}, presentation/{controllers,screens,widgets}}`. `domain/usecases/` folders exist but are empty. Controllers call repositories directly. |
| **Role handling** | `/home` → `RoleHomeScreen` branches on role (`features/dashboard/presentation/screens/role_home_screen.dart`). Police/admin get `PoliceDashboardScreen`. Citizen, lawyer and judge get `_RoleHomeList`: an identity card plus a non-interactive **"COMING NEXT"** list. For citizens that list is "File a complaint", "Track a complaint", "Emergency contacts" and "Missing persons" (`role_home_screen.dart:102-124`). **No Citizen feature is implemented.** |

---

## 3. API Layer

| Aspect | Finding |
|---|---|
| **Client** | `DioClient.create()` (`core/network/dio_client.dart`) builds one `Dio` with `BaseOptions(baseUrl: AppConfig.baseUrl, connectTimeout 20s, receiveTimeout 30s, sendTimeout 30s, contentType: json, responseType: json, headers: {X-NyayaAI-Client: nyayaai-flutter}, validateStatus: (_) => true)`. |
| **Base URL** | `AppConfig.baseUrl` (`core/config/app_config.dart`) uses `String.fromEnvironment('API_BASE_URL')`, falling back to `http://10.0.2.2:5000` on Android and `http://127.0.0.1:5000` elsewhere. It is compiled in at build time. |
| **Interceptors (in order)** | 1. `CookieManager(PersistCookieJar)`. 2. `LoggingInterceptor`: debug builds only; logs method, path, status and elapsed time; **bodies are never logged**. 3. An inline `InterceptorsWrapper.onResponse` that turns any status outside 200-399 into `DioException.badResponse` *after* the body is parsed, so the server's message is kept. |
| **Auth mechanism** | **Flask signed session cookie, not bearer tokens.** `POST /login` sets `session` (`app.py:2088-2094`: `user_id`, `role`, `unique_id`, `fullname`; `session.permanent=True`; `PERMANENT_SESSION_LIFETIME=8h`, `app.py:99`). The cookie is sent back automatically by the jar. There is no refresh token; after 8 h `/api/me` returns `logged_in:false`. |
| **Token storage** | The cookie is stored as a file under `getApplicationDocumentsDirectory()/.cookies` (**app-private storage, not encrypted**). The profile cache (`role`, `unique_id`, `fullname`, `email`) is in `flutter_secure_storage` with `encryptedSharedPreferences: true`. |
| **Cookie `Secure` flag** | The server sets `SESSION_COOKIE_SECURE=True` (`app.py:97`). `cookie_jar-4.0.9` `DefaultCookieJar._check` sends any non-expired cookie whatever its `Secure` flag, so the session works over the `http://` dev URLs. A browser would behave differently; that is not verified here. |
| **CSRF header** | `X-NyayaAI-Client` is sent on every request. The server's `require_same_origin` (`app.py:165-199`) accepts it instead of `Origin`. It is applied only to `/login`, `/signup` and `/api/suggest-sections`. |
| **Session restore** | `AuthController.build()` → `_restore()` → `AuthRepositoryImpl.restoreSession()` → `GET /api/me` (`missing_person.py:116-133`). If the server is unreachable, the user is treated as signed out and the cookie is kept. `logged_in:false` clears the cookie and the cache. The server role overrides the cached role. |
| **Error handling** | Each data source wraps calls in `try { … } catch (e) { throw ErrorMapper.map(e, context: …) }`. `ErrorMapper` (`core/error/error_mapper.dart`) maps: timeouts, connection errors and `SocketException` → `NetworkFailure`; 5xx → `ServerFailure`; 400/403/404 → `ValidationFailure(serverMessage)`; 401 → `AuthFailure`; anything else → `UnknownFailure`. `extractMessage` reads the `error`, `message` or `detail` keys, and ignores HTML bodies and strings longer than 200 characters. The missing-persons data source also turns `{success:false,error}` into `ValidationFailure`. **It reads only the top-level string, so array payloads such as `details: [...]` from `/generate_fir` are dropped** (see D2 FIR-1). |
| **Response parsing** | Hand-written defensive `fromJson` (no `json_serializable`). Missing or odd types are coerced to `''` or `null` (for example `ComplaintResponse._text`, `FirRecordResponse`). Each data source has an `_asMap` guard for non-object bodies. |

---

## 4. Models

Every model is hand-written. The "Source" column names the endpoint and store that fills it.

| Model / entity (file) | Fields | Source |
|---|---|---|
| `AuthUser` (`authentication/domain/entities/auth_user.dart`) | `role: UserRole, uniqueId, fullName?, email?, userId?` | `POST /login` + locally cached name/email + `GET /api/me` |
| `LoginRequest` / `LoginResponse` (`authentication/data/models/auth_models.dart`) | req `{email,password}`; resp `role, unique_id, message?, redirect?` | `POST /login` → Mongo `users` |
| `SignupRequest` / `SignupResponse` (same file) | req `{fullname,email,password,role,unique_id?}`; resp `unique_id, message?` | `POST /signup` → Mongo `users` |
| `SessionResponse` (same file) | `logged_in, role?, user_id?` | `GET /api/me` (Flask session) |
| `CachedUser` (same file) | `role, unique_id, fullname?, email?` | secure storage `nyayaai_cached_user` |
| `Complaint` (`complaints/domain/entities/complaint.dart`) via `ComplaintResponse.fromJson` | `trackingId, fullName, phone, incidentDescription, incidentDate, location, statusRaw, categoryRaw, isCognizableRaw, firNo, officerNotes, createdAt, updatedAt` | `GET /api/complaints/all`, `GET /api/complaint/<id>` → SQLite `citizen_complaints` |
| `ComplaintUpdate` (`complaints/data/models/complaint_models.dart`) | `status, fir_no, officer_notes` | `PATCH /api/complaints/<id>` |
| `ComplaintStatus`, `ComplaintCategory`, `ComplaintFilter`, `ComplaintNote`, `EscalationDesk` (complaints/domain/entities) | enum and helper value types (`Pending / Under Review / FIR Filed / Closed`, category buckets, filter state, note-line formatting, 5 escalation desks) | client-side; the status and category strings mirror `app.py:669` and `complaint_categorizer.py` |
| `FirDraft` (`fir/domain/entities/fir_draft.dart`) | the 27 FORM IF-1 fields plus `sections: List<ActSection>`; derived `year`, `occurrenceDay`, `actSectionsWire` | client-side draft, persisted to secure storage `nyayaai_fir_draft` |
| `FirSubmission` (`fir/data/models/fir_models.dart`) | 27 snake_case keys (`fir_no, dist, ps, year, fir_date, act_sections, …, statement`) | `POST /generate_fir` |
| `FirReceipt` | `firNo, firId, actSections, pdfFile, pdfUrl, createdAt, status, message` | `POST /generate_fir` response |
| `FirRecord` | all 27 IF-1 fields + `firId, pdfFile, pdfUrl, createdAt, status` | `GET /api/fir-records[/<no>]` → **Supabase `firs`** |
| `SectionSuggestions` / `SectionSuggestion` (`fir/domain/entities/section_suggestion.dart`) | `suggestions[{act, section, title, reason, confidence}], source, note, message` | `POST /api/suggest-sections` (Groq + keyword fallback) |
| `ActSection`, `FirProofOutcome` (fir/domain/entities) | act+section pair; proof-attachment outcome | client-side |
| `EvidenceItem` (`evidence/domain/entities/evidence_item.dart`) | `firNo, filename, category, uploadedAt` | `GET /get-all-evidence`, `GET /api/evidence?fir_no=`, `POST /upload-evidence` → Mongo `evidence_files` |
| `EvidenceFile`, `EvidenceCategory` | local picked file (`path`, `name`); category derived from extension or server `file_type` | client-side |
| `LegalSection`, `LegalSectionPage` (`legal/domain/entities/legal_section.dart`) | `act, section, title, description`; page `{act,page,limit,pages,total,results}` | `/api/sections/<act>`, `/api/section-detail/...`, `/api/search-sections` → SQLite act tables |
| `OutcomeFinding` (`legal/domain/entities/outcome_finding.dart`) | `act, section, title, description, punishment, bns_equivalent, sentencing_range, cognizable, bailable, outcome_note, score` | `POST /api/predict-outcome` → `results` (`website/case.py` over `case.csv`) |
| `LegalTerm`, BNS mapping (`legal/domain/entities/legal_reference.dart`) | glossary term/definition; old section → new code | **hard-coded constants** transcribed from `website/templates/index.html` JS objects (no endpoint exists; the file says so) |
| `MissingPerson` (`missing_persons/domain/entities/missing_person.dart`) | `person_id, name, age, gender, description, photo_url, last_seen_location, last_seen_date, created_at, status` | `GET /get_missing_persons` → SQLite `missing_persons` |
| `Sighting`, `SightingResult` | `sighting_id, photo_url, location, sighting_date, face_match_score, is_confirmed, uploaded_at`; result `{sighting_id, face_match_score, is_match, details, message}` | `GET /get_sightings/<id>`, `POST /report_sighting/<id>` → SQLite `missing_person_sightings` |
| `ConfirmedMatch` | `person_id, name, missing_person_photo, confidence, location, sighting_date, uploaded_at, sighting_photo, sightings[]` | `GET /get_confirmed_matches` |
| `MissingPersonDraft` | `name, photoPath, photoName, age, gender, description, lastSeenLocation, lastSeenDate` | `POST /upload_missing_person` (multipart) |

---

## 5. Shared / Reusable Components

**In `lib/shared/widgets/`, usable by any role:**

| Widget | File | Use |
|---|---|---|
| `PrimaryButton` / `SecondaryButton` | `buttons/primary_button.dart`, `secondary_button.dart` | Filled and outlined actions. `PrimaryButton(isLoading:)` shows a spinner. |
| `AppTextField` | `inputs/app_text_field.dart` | Labelled field with validator, formatters, autofill and error text. |
| `AppTextArea` | `inputs/app_text_area.dart` | Multi-line narrative input. |
| `PasswordField` | `inputs/password_field.dart` | Password input with a visibility toggle. |
| `AppPickerField` + `OptionPickerSheet` | `inputs/app_picker_field.dart`, `option_picker_sheet.dart` | Tap-to-pick field with a searchable bottom sheet. |
| `TextEntryDialog` | `inputs/text_entry_dialog.dart` | Single-value prompt dialog. |
| `FormBanner` | `feedback/form_banner.dart` | Inline error/notice banner above a form. |
| `StateMessage` | `feedback/state_message.dart` | Icon + headline + sentence for empty, error and no-match states. |
| `JusticeCrest` | `images/justice_crest.dart` | Brand emblem. |

**In feature folders but reusable for Citizen work:**
- `IdentityCard`, `ActionCard`, `PlannedFeatureTile`, `SectionHeading`, `confirmSignOut()`: `features/dashboard/presentation/widgets/dashboard_cards.dart`.
- `EvidenceFilePicker` / `EvidenceSource` (camera, gallery, file): `features/evidence/data/datasources/evidence_file_picker.dart`.
- `PersonPhoto` (renders a server photo path with `AppConfig.baseUrl`): `features/missing_persons/presentation/widgets/person_photo.dart`.
- `ReportSightingSheet`: `features/missing_persons/presentation/widgets/report_sighting_sheet.dart`.
- `SheetScaffold`, `ComplaintStatusChip`, `ComplaintCategoryChip`: `features/complaints/presentation/widgets/`.
- `ServerTime` (parses RFC 1123, Python `str(datetime)`, ISO 8601 and SQLite formats): `core/utils/server_time.dart`.
- `FormDates`: `core/utils/form_dates.dart`.
- Theme tokens: `AppColors` (navy, saffron…), `AppSpacing`, `AppRadius`, `AppSizes`, `AppTypography`.

---

## 6. Environment / Config

| Item | Finding |
|---|---|
| `.env` in Flutter | **None.** Configuration comes only from `--dart-define=API_BASE_URL` (`core/config/app_config.dart`). |
| Secrets in Flutter source | **None found.** The `X-NyayaAI-Client` value (`nyayaai-flutter`) is documented as non-secret (`api_headers.dart`). The evidence PIN is **not** in Dart; it is sent to `POST /verify-locker-access`. |
| Hard-coded URLs in Flutter | ⚠️ **Risk (dev-only):** the fallback base URLs `http://10.0.2.2:5000` and `http://127.0.0.1:5000` are cleartext. They are mitigated by `android/app/src/main/res/xml/network_security_config.xml` (cleartext only to loopback and emulator hosts). A production build **must** pass an `https://` `API_BASE_URL`; nothing in code enforces that. |
| Cookie at rest | ⚠️ The session cookie is stored unencrypted in app-private files (`<docs>/.cookies`). This is acceptable on a non-rooted device and should be noted for the threat model. |

**Security notes on the backend the app depends on.** These are not Flutter code, but they affect every Flutter role:

| # | Location | Risk |
|---|---|---|
| S1 | `website/app.py:91` `app.secret_key = "nyaya_ai_ultra_secure_key"` | 🔴 **Critical.** The Flask session-signing key is hard-coded and in source. Anyone with the source can forge a `session` cookie with any `role` (police, admin…) and `user_id`, which defeats every server-side role check the app relies on. |
| S2 | `website/app.py:2137` PIN `"secure@123"` | 🟠 Hard-coded evidence-locker PIN. It is also printed in `Application/NayayaAi_APP/HOW_TO_START.md` §6. |
| S3 | `website/.env` (GROQ, OpenRouter, Google/GitHub OAuth, Supabase URL/KEY) | 🟠 It is untracked now (`.gitignore`, commit `44dbb2a` "Stop tracking .env file") but **was committed earlier** (git history `a19c525`, `80f7cf8`). Treat those keys as exposed and rotate them. Values are not reproduced here. |
| S4 | `website/app.py:2597` `app.run(debug=True, port=5000)` | 🟠 The Werkzeug debugger is enabled. It binds to `127.0.0.1` by default; `HOW_TO_START.md` §2 says "0.0.0.0", which does not match the code. |
| S5 | `website/app.py:124-127` `ALLOWED_ORIGINS` contains the placeholder `https://yourdomain.com` | 🟡 Configuration placeholder. |
| S6 | Many endpoints have **no session check**: `/generate_fir`, `/api/fir-records*`, `/upload-evidence`, `/api/evidence`, `/get-all-evidence`, `/evidence-file/*`, `/api/complaints/all`, `PATCH /api/complaints/<id>`, `/api/complaint` (POST), `/api/complaint/<id>` (GET) | 🔴 Role gating is client-side only for these. Relevant to Citizen work: a citizen session, or no session, can call the police complaint endpoints. See D4/D5. |

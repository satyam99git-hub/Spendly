# Feature 1 — Authentication

**Status:** Complete. Verified against the live Flask server and its existing MongoDB user collection.
**Scope built:** F0 (app foundation) + F1 (sign up / sign in / session).
**Excluded by instruction:** Google and GitHub OAuth (F2).

---

## What it does

| Capability | Endpoint | Notes |
|---|---|---|
| Sign in | `POST /login` | Email + password, all four roles through one form |
| Register | `POST /signup` | Role-aware; enforces the server's unique-ID prefix rules |
| Sign out | `GET /logout` | Clears the session server-side *and* locally |
| Session restore | `GET /api/me` | Silent re-auth on cold start from the stored cookie |

Authentication runs against the **existing** `NyayaAI_DB.users` collection — the same accounts the website
uses. No new user store, no migration, no seed data.

---

## The three decisions that shaped the implementation

### 1. The session is a cookie, not a token

`POST /login` replies with `Set-Cookie: session=<signed>; HttpOnly; Path=/`. There is no JWT, no refresh
token, no `Authorization` header anywhere in the server. So the session *is* the cookie, and persisting it
is what makes stay-signed-in work.

**The flag that matters:** the cookie carries no `Expires` and no `Max-Age`, which by spec makes it a
*session cookie* — one a jar may discard when the process ends, and `PersistCookieJar` does exactly that
by default. It is therefore constructed with **`ignoreExpires: true`** in `core/network/dio_client.dart`.
Without that flag sign-in works and every cold start silently lands back on the login screen.

The `TokenStore`-shaped seam is `DioClient.clearSession()`. If a JWT backend arrives later, that method and
`AuthRemoteDataSource` change; no controller, screen or route does.

### 2. Sign-in validates presence, not password strength

`Validators.password` deliberately enforces **no minimum length** at sign-in. The server has never applied a
password policy, so accounts already in the database have passwords shorter than any floor the app might
invent — a client-side minimum would lock those users out of an app whose whole job is to accept their
existing credentials, and the server would never even be asked. Registration applies its own 8-character
floor (`Validators.signupPassword`), which affects only accounts created through the app.

### 3. Registration does not sign you in

`POST /signup` establishes no session — it registers the account and returns, setting no cookie. This is
verified by a live test (`2. registration does NOT establish a session`). Rather than paper over it with a
silent second request, the app shows the assigned unique ID — which a citizen has no other way to learn —
and hands off to sign-in with the email carried over.

---

## Server rules reproduced exactly

| Rule | Where enforced client-side |
|---|---|
| Roles are `citizen`, `police`, `lawyer`, `judge` (`admin` rejected at signup) | `UserRole.registerable` |
| Police / lawyer / judge must supply a unique ID | `UserRole.requiresUserSuppliedId` |
| That ID must start with `POL` / `LAW` / `JUD` | `Validators.uniqueId` |
| IDs are uppercased before comparison | Input formatter + `SignupRequest.toJson` |
| Citizens get a server-generated `CIT###` | ID field hidden; key omitted from the request body |
| `officer` counts as police | `UserRole.fromWire` |

The unique-ID validator deliberately checks **only** the prefix and a sane length. Real IDs in the database
range from `POL1` to `POL001` to `POL-101` to `POL9999`; imposing a stricter shape would reject IDs the
server accepts. There is a test pinning those four real values as valid.

Server error messages (`Email already registered`, `Unique ID for police must start with POL`, …) are passed
through **verbatim** — they are already written for humans, and rewording them client-side would mean
maintaining a second copy of rules that live on the server.

---

## Architecture

```
lib/
├── main.dart                      → bootstrap()
├── bootstrap.dart                 async startup; builds DioClient, overrides its provider
├── app.dart                       MaterialApp.router
│
├── core/
│   ├── config/app_config.dart     base URL (--dart-define), timeouts, splash hold
│   ├── constants/                 api_endpoints.dart, storage_keys.dart
│   ├── di/providers.dart          dioClientProvider (override-only), secureStorageProvider
│   ├── enums/user_role.dart       roles + prefix rules + fail-closed parsing
│   ├── error/                     failure.dart (sealed), error_mapper.dart
│   ├── network/                   dio_client.dart, interceptors/logging_interceptor.dart
│   ├── storage/                   secure_storage_service.dart
│   └── utils/validators.dart
│
├── routes/                        app_routes.dart, app_router.dart (auth redirect)
│
└── features/
    ├── authentication/
    │   ├── data/
    │   │   ├── datasources/auth_remote_data_source.dart
    │   │   ├── models/auth_models.dart
    │   │   └── repositories/auth_repository_impl.dart
    │   ├── domain/
    │   │   ├── entities/auth_user.dart
    │   │   └── repositories/auth_repository.dart
    │   └── presentation/
    │       ├── controllers/       auth_controller.dart, auth_state.dart
    │       ├── screens/           login_screen.dart, signup_screen.dart
    │       └── widgets/           auth_header, auth_divider, auth_form_banner,
    │                              role_selector, station_footer
    ├── dashboard/presentation/screens/role_home_screen.dart
    └── splash/presentation/screens/splash_screen.dart
```

**Note on `domain/usecases/`:** not created. Each of the four operations is a single repository call with no
orchestration, so a use-case class per method would be a pass-through layer that adds a file and hides
nothing. Add them when an operation grows real logic.

---

## Routes

| Path | Name | Screen | Guard |
|---|---|---|---|
| `/` | `splash` | `SplashScreen` | Held here while the session resolves |
| `/login` | `login` | `LoginScreen` | Signed-out only |
| `/signup` | `signup` | `SignupScreen` | Signed-out only |
| `/home` | `home` | `RoleHomeScreen` | Signed-in only |

These are the **app's** routes and owe nothing to the website's URLs. The login response carries the server's
own `redirect` (`/citizen-dashboard`); it is parsed but deliberately unused — the app derives its landing
screen from the role.

**The redirect's four cases** (`routes/app_router.dart`):
1. `isResolving` → hold on splash. Redirecting now would flash sign-in on every cold start.
2. `isBusy` → stay put. Bouncing off a form mid-submit tears down the screen about to render the failure.
3. Signed out → allow `/login` and `/signup`, redirect everything else to `/login`.
4. Signed in on splash or an auth screen → `/home`.

**Screens never navigate on sign-in or sign-out.** The controller flips the auth state and the redirect
moves the user. Two mechanisms racing for the same transition is how a screen ends up popped from under
itself.

---

## Models ↔ API

| Dart | Wire |
|---|---|
| `LoginRequest` | `{email, password}` |
| `LoginResponse` | `{message, role, unique_id, redirect}` |
| `SignupRequest` | `{fullname, email, password, role, unique_id?}` |
| `SignupResponse` | `{message, unique_id, role}` |
| `SessionResponse` | `{logged_in, role, user_id}` |
| `CachedUser` | local only — secure storage |

`AuthUser` is assembled from more than one source, because no single response has the whole picture: `role`
and `unique_id` come from `/login`, the email from what the user typed, `user_id` from `/api/me`. The name,
email and unique ID are cached locally; **the role always comes from the most recent server response**, so a
role changed server-side takes effect on the next launch rather than persisting until sign-out.

---

## Configuration

```bash
# Android emulator (the default if unset)
flutter run

# Physical device — needs the host's LAN address
flutter run --dart-define=API_BASE_URL=http://192.168.1.7:5000
```

`AppConfig.defaultBaseUrl` falls back to `http://10.0.2.2:5000` on Android — the emulator's alias for the
host's loopback. A physical handset can reach neither that nor `127.0.0.1`; startup logs a warning in debug
builds when the fallback is in play, so "connection refused" points at the missing define rather than
looking like a server outage.

---

## Dependencies added

| Package | Why |
|---|---|
| `dio` | Interceptors, which is what makes the cookie and error layers possible |
| `dio_cookie_manager` + `cookie_jar` | Flask session cookie, persisted across launches |
| `go_router` | Declarative routing + the auth redirect |
| `flutter_secure_storage` | Cached profile (Keystore / Keychain) |
| `path_provider` | Directory for the cookie jar |

---

## Tests — 73 passing, analyzer clean

```
test/
├── unit/auth_contract_test.dart          33 — payloads captured from the live server
├── widget/features/login_screen_test.dart      15
├── widget/features/signup_screen_test.dart     17
├── widget/features/splash_screen_test.dart      6 — startup + sign-in + sign-out routing
└── golden/                                      6 — regenerated for the new screens

test_live/auth_live_test.dart                    9 — outside test/, never in a default run
```

```bash
flutter analyze                                    # no issues
flutter test                                       # 73 pass (unit + widget + golden)
flutter test --tags golden --update-goldens        # after an intentional design change
```

### The live suite

Proves the parts a fake cannot: that the paths exist, that the JSON shapes match, and that the session
cookie is issued, replayed on a later request, and invalidated by sign-out.

```bash
# 1. start the website, from the repo root
venv/bin/python app.py
# 2. then, from flutter_app/
flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

**It writes to the database.** Registration is the only way to get an account whose password is known, so it
creates one under a `zz.flutter.live.*@example.com` address. The server has no delete-account route, so
remove it afterwards:

```bash
venv/bin/python -c "from pymongo import MongoClient; \
  print(MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB']['users'] \
    .delete_many({'email': {'\$regex': '^zz\\.'}}).deleted_count)"
```

---

## Deliberate omissions

| Not built | Why |
|---|---|
| Forgot password | The server has no password-reset endpoint. A link that explains it is not connected is a placeholder. |
| Biometric unlock | Not a website feature, and `local_auth` cannot verify a credential the app never holds — the password is never stored. Revisit as a re-unlock for an existing session. |
| Google / GitHub OAuth | Excluded by instruction. Also needs backend work: the web flow is a server-side redirect, which on mobile requires a native SDK plus a token-exchange endpoint. |
| `domain/usecases/` | Would be four pass-through classes. See the architecture note. |

The previous login screen's biometric and forgot-password affordances were **removed**, not disabled — a
control that reports "not connected in this build" is exactly the placeholder the brief rules out.

---

## Known issues in the server (not fixed — the website is read-only)

1. **No role check on the police console.** `home()` verifies only that `user_id` is in the session, never
   that the role is `police`.
2. **Auth endpoints are unauthenticated.** `/generate_fir`, `/api/fir-records`, `/upload-evidence`,
   `/api/complaints/all` and `PATCH /api/complaints/<id>` have no session check at all. Only the
   missing-persons blueprint gates on `_is_police()`.
3. **The evidence locker PIN is hardcoded** as `secure@123` in `app.py`. The app asks the server for it now
   rather than holding a second copy — see `features/03-evidence-locker.md`.
4. **`CSRFProtect` is imported but never instantiated** — CSRF protection is inactive. What does exist is
   `require_same_origin` on `/login` and `/signup`; see below.

The app enforces roles client-side, which is cosmetic against 2. The real fix belongs on a server.

---

## The 403 that made sign-in impossible

`/login` and `/signup` are wrapped in `require_same_origin`, which rejected any state-changing request that
carried no `Origin` or `Referer`. A browser attaches `Origin` to every POST, including a plain form
submission, so the website was fine. **Dio is not a browser and sends neither**, so both endpoints answered

```
403 {"error": "Request rejected."}
```

and the app could never leave its sign-in screen. Two things were wrong at once: even had the app sent an
`Origin`, `ALLOWED_ORIGINS` held only `https://yourdomain.com` and `http://127.0.0.1:5000` — not the
emulator's `http://10.0.2.2:5000`.

**The fix is a header.** The client sets `X-NyayaAI-Client` on every request (see `ApiHeaders`), and
`require_same_origin` lets a request through when it carries either a trusted origin or that header.

Trusting a custom header is not a hole, and this is worth being clear about. A cross-origin page cannot set
one without triggering a CORS preflight, and this server answers no preflight and returns no
`Access-Control-Allow-Headers` — so the browser refuses to send the real request. The header is therefore
proof the caller is not a hostile page, which is exactly what `Origin` was being asked to prove. The
browser path is untouched: a POST with no header and no origin, or with a foreign one, is still 403.

It is set on every request rather than on the two that need it, because the server is free to guard more
endpoints later and a client that only sometimes identifies itself would fail one endpoint at a time.

`ALLOWED_ORIGINS` was widened at the same time (`10.0.2.2:5000`, `localhost:5000`, plus anything in
`APP_ALLOWED_ORIGINS`), so a browser build of the app works too.

## Rate limits are per IP, and a station is one IP

`/signup` and `/login` are rate-limited by `get_remote_address`. The original ceilings — 5 signups an hour and
10 sign-ins per 15 minutes — were sized as though one address meant one person. A police station reaches the
server from one public address, so the second shift signing in after the first simply got HTTP 429 with no
explanation. The live test suite hit it within three runs.

Raised to 60 and 100 respectively, and made configurable per deployment through `SIGNUP_RATE_LIMIT` and
`LOGIN_RATE_LIMIT`. Brute-force protection never rested there anyway: `MAX_FAILED_ATTEMPTS` locks a single
account for `LOCKOUT_SECONDS` after five wrong passwords, which is per-account and unaffected by how many
people share the address.

## The session cookie is `Secure`, and the app talks HTTP

`SESSION_COOKIE_SECURE=True`, so by the cookie spec the jar should refuse to send the cookie back over
`http://`. It works only because `cookie_jar`'s `_check` short-circuits on `!_isExpired` when the jar is built
with `ignoreExpires: true`, which `DioClient` does for an unrelated reason.

That is load-bearing by accident. Removing `ignoreExpires` — which the class doc already warns against for
its own reason — would silently kill every session on a non-TLS deployment. The real fix is TLS in front of
the server.

---

## What the next feature inherits

Working, ready to build on: routing with an auth guard, a Dio client that carries the session, `Failure`
mapping with server messages preserved, secure storage, `AuthUser` + role available anywhere via
`authControllerProvider`, and the theme/shared-widget set.

`RoleHomeScreen` is the signed-in shell. Its per-role lists are **non-interactive by design** — a tappable
card opening an empty page is worse than an honest list. Each becomes a real destination as its feature
lands, at which point the screen is replaced by the per-role dashboards.

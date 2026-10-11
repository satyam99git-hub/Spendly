# NyayaAI — Flutter app

Mobile client for the NyayaAI legal-services platform. Built independently of the website, which serves
only as a specification: features and business rules were learned from it, none of its code was reused, and
nothing in it was modified.

## Status

| Feature | State |
|---|---|
| **F0 — App foundation** | Done — routing, networking, DI, errors, storage, theme |
| **F1 — Authentication** | Done — sign in, register, sign out, session restore |
| **F8 — FIR registration** | Done — FORM IF-1: 27 entries across four steps and a review page, draft autosave, AI section suggestion |
| **Police dashboard** | Done — tabbed console (FIR · Complaints · Evidence) for police and admin |
| **F9 — FIR history & viewer** | Done — search past FIRs, read one in FORM IF-1 order, download its PDF |
| **F10 — Evidence locker** | Done — PIN gate, list by FIR, upload, file detail |
| **F11 — Citizen complaints** | Done — inbox with stage/date/text filters, respond, escalate, convert to FIR |
| F2 — Social login | Excluded for now (needs backend work) |
| F3–F7, F12+ | Not started — see `../docs/FEATURE_INVENTORY.md` |

Feature documentation lives in `../docs/features/`.

## Running it

The app talks to the Flask website's API. Start that first, from the repo root:

```bash
venv/bin/python app.py     # serves on :5000, needs MongoDB up
```

Then:

```bash
flutter pub get

# Android emulator — 10.0.2.2 is its alias for the host's loopback
flutter run

# Physical device — needs the host's LAN address
flutter run --dart-define=API_BASE_URL=http://192.168.1.7:5000
```

Sign in with any account already in `NyayaAI_DB.users`, or register a new one.

## Checks

```bash
flutter analyze                              # must be clean
flutter test                                 # 301 unit + widget + golden
flutter test --tags golden --update-goldens  # after an intentional design change
```

The `live` suite hits a real server and is excluded by default — see
`../docs/features/01-authentication.md` for how to run it and how to clean up after it. The FIR and evidence
suites write files to disk as well as rows to Mongo; the cleanup for both is in
`../docs/features/03-evidence-locker.md`.

## The evidence locker's PIN

`secure@123`, checked by the server via `POST /verify-locker-access` — the same string the website's console
takes. It protects an unattended handset and nothing else: every evidence endpoint is unauthenticated
server-side. See `../docs/features/03-evidence-locker.md`, "The PIN".

## Layout

```
lib/
├── core/        config, constants, DI, enums, error, network, storage, utils
├── routes/      GoRouter + the auth redirect
├── shared/      widgets used by more than one feature
├── theme/       colours, typography, dimensions, ThemeData
└── features/    <feature>/{data,domain,presentation}
```

Each feature owns its own data, domain and presentation layers. `core/` holds only what more than one
feature needs; a helper used once belongs with its feature.

## Branding

One source file, `assets/images/logo/Logo.png` — the designed NyayaAI lockup. Every icon in the app is
generated from it:

```bash
python3 tool/generate_launcher_icons.py    # needs Pillow
flutter test --tags golden --update-goldens
```

**Do not hand-edit the generated files.** They are `assets/images/logo/emblem.png` and everything under
`android/app/src/main/res/mipmap-*/` and `res/drawable-*dpi/`, and the next run overwrites all of them.
`tool/measure_logo.py` re-derives the crop and colour constants if the artwork is ever redrawn.

Three icons come out of it, and they are deliberately not the same picture:

| | What it is | Why |
|---|---|---|
| Legacy `ic_launcher.png` | the full lockup, wordmark included | nothing masks it, so it shows as drawn |
| Adaptive foreground | the emblem alone, at 78% of the safe zone | launchers mask to a circle/squircle/teardrop, any of which would cut the wordmark in half |
| Monochrome | the emblem's alpha channel | Android 13 themed icons; the system supplies the colour |

The emblem is keyed to transparency against the logo's own navy, so it composites onto the crest chip with
no halo. It is white-on-dark by design and is only ever drawn on navy.

The native launch screen (`res/drawable*/launch_background.xml`) paints the same emblem on the same navy the
Flutter splash uses, so the handover is invisible. It shipped as the template's white, which flashed on
every launch. `@color/launch_background` must stay in step with `AppColors.navy` / `navyDeep`.

## Conventions

- **State:** Riverpod. No `setState` for anything but local widget concerns (focus, obscure-text toggles).
- **Errors:** the data layer throws `Failure`; nothing above it ever sees a `DioException`.
- **Navigation:** screens do not navigate on auth changes — the router's redirect does.
- **Colours:** read from `Theme.of(context)`. Only `theme/` references `AppColors` directly, so light and
  dark stay in step.
- **Comments:** explain *why*. The what is already in the code.

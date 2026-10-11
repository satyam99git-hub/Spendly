# Feature 10 — Police Dashboard & Evidence Locker

**Status:** Complete.
**Scope built:** the police console's shell, and the locker behind it.
**Flow:** Sign in as police → dashboard → **Evidence** tab → PIN gate → list → Add → Detail.

---

## What it does

| Capability | Endpoint | Notes |
|---|---|---|
| Open the locker | `POST /verify-locker-access` | The same check the website makes. See "The PIN" below |
| List everything in it | `GET /get-all-evidence` | `{"<fir_no>": ["a.jpg", …]}` — filenames only, no metadata |
| Narrow it | — | Search over FIR number and filename, and chips per kind of file. Both client-side; there is no server-side search |
| One FIR's files, with metadata | `GET /api/evidence?fir_no=` | adds `file_type`, `file_url`, `uploaded_at` |
| Add a file | `POST /upload-evidence` | multipart `{fir_no, file}`; rejected unless the FIR exists |
| Show the file | `GET /evidence-file/<fir>/<name>` | served straight off disk, no session check |
| Record a look | `POST /api/evidence/log-access` | a stub server-side; the app sends anyway |

Runs against the **existing** `NyayaAI_DB.evidence_files` collection and `static/uploads/evidence/<fir_no>/`.

---

## The dashboard

Police and admin now land on a tabbed console instead of the role list. Everyone else keeps the list — police
is the only role with more than one built feature, and the only one that needed a shell.

Two tabs, **FIR** and **Evidence**, and they are two surfaces at the same level rather than a menu with two
entries. Registering an FIR and filing what belongs to one are not steps in a sequence and neither is
subordinate to the other: evidence arrives days after the FIR, and an officer at a counter switches between
them several times an hour. A menu screen would put a push-and-pop between every switch.

The body is an `IndexedStack`, not a rebuild. Otherwise the locker's PIN would be re-asked on every trip to
the FIR tab, and the search box would forget what was typed into it.

The padlock in the app bar appears only on the Evidence tab, and only when the locker is open. A padlock that
is always visible and usually does nothing is a padlock nobody reads.

---

## The PIN

**This is not a security control, and the code says so out loud.**

The PIN goes to **`POST /verify-locker-access`**, which is the same check the website's console makes.

It used to be compared in Dart against a constant of the app's own, `INDIA@123`, while the server compared
against `secure@123`. That was the bug: the handset and the console were two doors onto one locker that opened
to two different strings, so an officer given the station PIN by a colleague working on the website could not
get in on the phone. Whatever the PIN is, there is now one of it.

Asking the server bought parity, not safety. `/upload-evidence`, `/api/evidence`, `/get-all-evidence` and
`/evidence-file/...` have **no session check of any kind** — anyone who can reach the server can read or write
the locker without ever seeing a PIN. The gate is still only for what it always was: stopping a phone left
unlocked on a desk from showing a complainant's evidence to whoever picks it up, in a screen an officer
reaches by mis-tapping a tab.

**Failing closed.** A PIN the server never answered is not a wrong PIN, and the two must not read the same.
An unreachable server leaves the locker shut and says it could not ask — reporting "Wrong PIN" would send an
officer to the station in-charge over a dropped connection, and opening anyway would make the gate a
decoration a flight-mode toggle removes. The rejected value is cleared from the box only when the server
actually rejected it; a PIN that never left the handset is still the officer's best guess.

The gate's own copy says as much — *"This PIN keeps the locker closed on an unattended handset. It is not a
substitute for signing out."* A gate that overstates itself is one people trust with more than it can hold.

**The real fix is a session check on those four routes, server-side.** Until then this is a curtain.

Details that follow from that framing:

- The lock state is **in memory only** — never written to storage — so the locker relocks on every cold start.
- It is **invalidated on sign-out**, wired in `app_router.dart` where the rest of the auth-driven resets live.
  Without it, the next person to sign in on a shared station handset would find the locker already open.
  There is a test.
- The gate is a **state, not a route**. A pushed PIN screen can be popped, deep-linked around, or left behind
  by a back gesture that reveals the list underneath it. The list is simply not built while the lock is on —
  and nothing is fetched either.
- The PIN is compared **exactly** — not trimmed, not case-folded. Quietly accepting `india@123 ` teaches a
  value that anything comparing strictly will reject.
- A wrong PIN clears the box and re-focuses it. Leaving the rejected value there means the next attempt starts
  with select-all-and-delete, which on a phone is three fiddly taps.
- From the second failure the message names the count. On a shared handset, two failures in a row usually
  means the PIN was changed and nobody said so, and a count is the difference between trying a third time and
  going to ask.

Rate limiting is **not** implemented. It belongs with a real server-side gate, where it can outlive an app
restart; a client-side cooldown is defeated by force-quitting.

---

## The decisions that shaped it

### 1. The list is grouped by FIR, and searched client-side

Evidence is never "a file" to an officer, it is "what we have on FIR 41/2026". A flat chronological list would
be shorter to build and would put two files from the same case twenty rows apart.

Search filters across both the FIR number and the filename, on the list already in memory. There is no
server-side search — `/get-all-evidence` takes no query — and adding a debounce and a spinner for a
client-side `contains` would be pure ceremony.

### 2. The app duplicates the server's extension table, on purpose

`/get-all-evidence` returns bare filenames. `/api/evidence` returns a `file_type` — and that field is a
*category* the server derives from the extension (`image` / `video` / `audio` / `pdf` / `other`), not a MIME
type, despite the Mongo column of the same name holding a MIME type.

So the list screen has to categorise on its own, and `EvidenceCategory.fromExtension` is a deliberate copy of
`api_get_evidence`'s table. The two must stay in step: a file the app calls `other` and the server calls
`image` gets a document icon on the list and a photo on the detail page. There is a unit test pinning the
whole table, and it is case-insensitive because Android cameras write `.JPG` about as often as `.jpg`.

When the server *does* send a `file_type`, it wins — and an unrecognised value falls back to the extension
rather than to `other`, so a sixth category added server-side does not flatten every row to a generic icon.

### 3. A file is addressed by `(fir_no, filename)`, because that is all there is

The server has no id for a piece of evidence. It keys on the pair and de-duplicates on it, so the pair *is*
the identity — which is why the detail route is `/evidence/item/:firNo/:filename` rather than an id, and why
the screen refetches from `GET /api/evidence?fir_no=` on open rather than being handed an object.

That also means it survives the process death a camera excursion makes likely, and it is how the screen gets
the timestamp the list could not carry.

### 4. "Not known here" is not "never recorded"

Items from `/get-all-evidence` have an empty `uploadedAt` because that payload has no timestamps in it. The
list shows no timestamp at all rather than a blank line where one should be; the detail screen, which does
have the metadata, says *Not recorded* only when the server genuinely sent nothing.

### 5. The filename to trust is the server's

`secure_filename` rewrites what it is given — `scene 1.jpg` is stored as `scene_1.jpg`. An app that assumed
its own name would build a detail route to a file that is not there, so the upload response's `file` is what
the confirmation shows and what the list is refreshed against.

The server also **overwrites** a file of the same name in the same FIR folder without saying so, and inserts
no second row. That is why the upload is never retried automatically, and why the detail screen has a "no
longer in the locker" state instead of assuming a link built from one list still resolves against another.

### 6. Three sources, not one attach button

Camera, gallery and file browser are three different physical acts, and the officer knows which one they are
about to perform before they tap anything. Collapsing them into a single picker costs a round of "no, the
other one" every time.

`image_picker` handles the first two — `pickMedia` rather than `pickImage`, so a phone video of the scene is
one tap and not a second menu item nobody finds. `file_picker` handles the third, and without it "Add
evidence" would silently mean "add a photo" for a locker the server categorises into five kinds.

A dismissed picker is a dismissal, never an error, and it does not throw away a file already chosen.

### 7. The access log is fire-and-forget

`POST /api/evidence/log-access` is a stub: the handler acknowledges and discards. The app calls it anyway,
never awaited before the file is shown, and the data source swallows its failures by contract — a locker that
refuses to open because its audit log is down is a locker that gets worked around. When the handler is given a
body to write, every client is already sending one.

### 8. No cache, and nothing polls

The locker's whole point is that what an officer sees is what the station holds. A cached list would show a
file that has since been replaced, or hide one a colleague uploaded a minute ago.

`allEvidenceProvider` is invalidated after every upload from this device — the only thing that changes it from
here — and a colleague's upload is picked up by pull-to-refresh. Nothing reloads on a timer, because a locker
that reloads itself is a locker that reloads while someone is reading it.

---

## Architecture

```
lib/
├── core/constants/api_endpoints.dart      + allEvidence, evidenceForFir, uploadEvidence,
│                                            evidenceFile, logEvidenceAccess
├── routes/                                + /evidence/add, /evidence/item/:firNo/:filename
│                                            + AppRoutes.policePrefixes
│                                            + the sign-out relock
│
├── features/dashboard/presentation/
│   ├── screens/police_dashboard_screen.dart   NEW — the tabbed console
│   ├── screens/role_home_screen.dart          now branches: police → the console
│   └── widgets/dashboard_cards.dart           NEW — IdentityCard, ActionCard,
│                                              PlannedFeatureTile, confirmSignOut
│
└── features/evidence/
    ├── data/
    │   ├── datasources/evidence_remote_data_source.dart
    │   ├── datasources/evidence_file_picker.dart   the plugin seam + EvidenceSource
    │   ├── models/evidence_models.dart
    │   └── repositories/evidence_repository_impl.dart
    ├── domain/
    │   ├── entities/                          evidence_category, evidence_item, evidence_file
    │   └── repositories/evidence_repository.dart
    └── presentation/
        ├── controllers/                       evidence_providers, evidence_lock_controller,
        │                                       evidence_upload_controller
        ├── screens/                           evidence_locker_screen, evidence_add_screen,
        │                                       evidence_detail_screen
        └── widgets/                           evidence_pin_gate, evidence_list_view,
                                               evidence_tile, evidence_keys
```

**Why `dashboard_cards.dart` exists.** The identity card, the action card and the planned-feature tile were
private to `role_home_screen.dart` until the police console grew tabs of its own. Two screens showing the same
identity card in two shapes is how a product starts looking like two products.

**Why the file picker is behind an interface.** `image_picker` and `file_picker` both need a platform channel,
which a widget test has none of. `EvidenceFilePicker` is what lets the upload controller be driven with a
scripted file.

**Why `EvidenceFile` is not `XFile` or `dart:io`'s `File`.** Either would put the plugin, or the filesystem, in
the signature of everything that touches an upload.

**The one cross-feature wire.** Sign-out relocks the locker, and that lives in `app_router.dart`: the locker
must not import the auth controller to learn it should relock, and the auth controller has no business knowing
a locker exists.

**The one cross-feature import**, added with F9: `EvidenceAddScreen` imports `showFirPicker` from the FIR
feature. Evidence is filed *against* an FIR, so the dependency runs that way and only that way — the FIR
feature knows nothing about a locker. The shared piece that is genuinely neither feature's, how an FIR number
is written on screen, went to `core/utils/fir_number.dart` instead: the locker labels its groups and the
history labels its rows, and two copies of that rule is how the same record reads `FIR 41/2026` on one screen
and `FIR FIR 41/2026` on the next.

---

## Routes

| Path | Name | Screen | Guard |
|---|---|---|---|
| `/evidence/add` | `evidenceAdd` | `EvidenceAddScreen` | police / admin |
| `/evidence/item/:firNo/:filename` | `evidenceDetail` | `EvidenceDetailScreen` | police / admin |

The locker's list and its PIN gate have **no routes** — they are the Evidence tab's two states, inside
`/home`.

The role guard is now one loop over `AppRoutes.policePrefixes` (`/fir`, `/evidence`), so adding a police
feature means adding its prefix and nothing else. As with the FIR routes, it is a UI guard only: every
evidence endpoint is unauthenticated server-side.

---

## Android

Two things the build needs, and both fail quietly if forgotten:

- **`<queries>` for `android.media.action.IMAGE_CAPTURE`.** Android 11 hid other packages from an app unless
  it declares what it intends to launch. Without it, `image_picker`'s camera path resolves no activity and
  returns null — indistinguishable, in the app, from the officer cancelling. The button does nothing, on
  exactly the devices most likely to be in use.
- **`file_picker: ^10.0.0`, not 8.x.** 8.x pins its Android module to `compileSdk 34`, and
  `flutter_plugin_android_lifecycle` (pulled in by `image_picker`) requires 36. Together they fail
  `assembleDebug` with *"requires libraries … to compile against version 36 or later"*. The constraint is a
  build requirement, not a preference.

Gallery and file picking need no manifest entry — both go through the system photo picker and the Storage
Access Framework.

---

## Tests

```
test/
├── unit/features/evidence_test.dart             the wire contract + the extension table
├── widget/features/evidence_locker_test.dart    gate → list → add → detail
├── widget/features/fir_route_guard_test.dart    + /evidence deep links, + sign-out relocks
└── golden/police_console_golden_test.dart       + the gate, + the populated list

test_live/evidence_live_test.dart                outside test/, never in a default run
```

```bash
flutter analyze     # no issues
flutter test        # 226 pass
```

### The live suite

Three things only a real server can settle, and each has burned somebody:

1. **The multipart body actually arrives.** `DioClient` sets a JSON content type for every other request in
   the app. Sent with that header, a multipart body reaches Flask as an empty `request.files` and the handler
   answers *"Missing FIR or file"* — a message that names neither of the two things that were, in fact, sent.
   `EvidenceRemoteDataSource.upload` overrides `contentType` per-request; only a live run proves it.
2. **The FIR must exist first.** The probe files an FIR before it can upload anything, which is the dependency
   in miniature.
3. **`file_type` is a category, not a MIME type.**

```bash
venv/bin/python app.py
flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

**It writes to the database and to disk**, and nothing has a delete route:

```bash
venv/bin/python -c "from pymongo import MongoClient; \
  db = MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB']; \
  print(db['fir_records'].delete_many({'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count, \
        db['evidence_files'].delete_many({'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count)"
rm -rf static/uploads/evidence/ZZFLUTTER*
rm -f generated_firs/FIR_ZZFLUTTER*.pdf
```

---

## One bug fixed after the fact

Both `EvidenceAddScreen` and `EvidenceDetailScreen` shipped with a bare `Scaffold`. The theme's
`scaffoldBackgroundColor` is navy — the auth screens are built on it — so those two pages rendered their
labels as dark text on navy: *"FIR number"*, *"File"* and the note under them were effectively invisible on a
handset. Every other screen in the app paints `colorScheme.surface` itself and none of these two are
snapshotted, so nothing caught it.

Found while adding the FIR picker, by rendering the Add screen to look at it. Both now set the background
explicitly. If a screen is added here, it does the same.

---

## Deliberate omissions

| Not built | Why |
|---|---|
| Playing video or audio, rendering a PDF | Each needs its own player or viewer package. Images preview in place; everything else is shown as a described file. A button that opens a black rectangle is worse than one that is honestly absent. |
| Downloading a file to the handset | Needs a save-file flow and storage permissions, and nothing in the locker's job requires a second copy on the phone. |
| Deleting or replacing evidence | The server has no delete route, and its upload silently overwrites — an app-level "replace" would look like a control the officer has and the server does not honour. |
| Multi-file upload | The endpoint takes one file per request. A queue of them is a progress UI and a partial-failure story; one at a time is honest about what the server does. |
| ~~Uploading against an FIR picked from a list~~ | **Built after F9.** The number is still typed by default — an officer at the counter has it in front of them, and the only endpoint that lists FIRs returns every column of every one. A *Choose from history* affordance inside the field opens the record list, and it fetches only when opened, so typing costs nothing. A sheet that fails to load leaves the typed path untouched. See `04-fir-history.md`. |
| Real access logging | The server's handler discards the body. The app sends one anyway — see decision 7. |
| Rate-limiting the PIN | Belongs with a server-side gate; a client-side cooldown is defeated by force-quitting. |

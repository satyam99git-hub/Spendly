# Feature 9 — FIR History & Viewer

**Status:** Complete.
**Scope built:** reading police records back — the list, one record in FORM IF-1 order, and the generated PDF.
**Flow:** Sign in as police → **FIR** tab → *FIR history* → search → a record → *Download the PDF*.

---

## What it does

| Capability | Endpoint | Notes |
|---|---|---|
| List every FIR on record | `GET /api/fir-records` | the whole collection, no paging, no query, no sort |
| Search it | — | client-side, on the list already in memory |
| Read one record | `GET /api/fir-records/<fir_no>` | 404 `{error: "FIR record <no> not found"}` |
| Download its PDF | `GET /fir/download/<fir_no>` | 404 when the file is not on *this* server |
| Open the PDF | — | `open_filex` hands it to the handset's viewer |

Runs against the **existing** `NyayaAI_DB.fir_records` collection and the server's `generated_firs/` folder —
the same documents `POST /generate_fir` writes, which the app has been filing since F8.

---

## The decisions that shaped it

### 1. The app renders the record; it does not open the server's page

The server already has `/fir/view/<fir_no>`, which renders the same document as HTML. Opening it in a browser
would have been a two-line feature.

It is not what an officer needs. That page is desktop-width and unstyled for a phone, it leaves the app so
back-navigation lands somewhere else, and it prints every column — including the eighteen a short-format FIR
leaves blank, which reads as a defective record rather than a brief one.

Rendering from the JSON also means the viewer behaves like the rest of the app: failures arrive as `Failure`s
with a sentence, a missing record says so, and nothing depends on a browser being installed.

### 2. `FirRecord` has all 27 entries although `FirDraft` has nine

They are not the same document at two times. `FirDraft` is what this app *asks an officer for* — the nine
entries nobody else can supply, deliberately short because the officer is standing at a counter with a
complainant in front of them.

`FirRecord` is what the database *returns*, and the app is not the only thing that writes to it. An FIR filed
from the website's console carries a passport block, a father's name, a GD reference and a delay reason. A
viewer that modelled only the nine would open that record and silently drop two thirds of a statutory
document. **Reading a record is a different job from writing one: showing less than was filed is a defect in a
way that asking for less is not.**

There is a unit test holding the two key sets against each other — every key `FirSubmission` writes is read
back by `FirRecordResponse`, under the same server spelling. A pair that drifts apart shows up in the viewer
as a permanently blank entry, which looks exactly like an FIR filed incomplete.

### 3. Blank entries are hidden, and said once at the bottom

A short-format FIR leaves eighteen of the twenty-seven empty. The viewer skips them, drops a whole block when
every entry in it is blank, and states *"Entries left blank at the station are not shown"* once in the footer
rather than nineteen times up the page.

The narrative is the exception: an empty statement is shown as *"No statement was recorded with this FIR"*,
because every other entry can be reconstructed from the station register and that one cannot.

### 4. `created_at` arrives in two different spellings

The same Mongo `datetime` reaches the client two ways:

| Handler | Shape | Why |
|---|---|---|
| `GET /api/fir-records` | `Sat, 09 Aug 2026 02:31:00 GMT` | `jsonify` serialises a `datetime` as an RFC 1123 HTTP date |
| `POST /generate_fir` | `2026-08-09 02:31:00.345678` | that handler calls `str(...)` on it by hand |

`core/utils/server_time.dart` reads both. A viewer that understood one would show a filing date on some
screens and a raw string on others, **for the same record**.

Both are UTC, and the app **says UTC rather than converting**. Every FIR in the database is timestamped that
way and the website's console shows it that way; quietly rendering the handset's local time would make the app
disagree with the desk about when a statutory record was created — by five and a half hours, in India.

The `str(datetime)` form carries no zone, so `DateTime.tryParse` reads it as *local*. It is rebuilt as UTC
rather than trusted, which is the difference between a correct timestamp and one that has not happened yet.

### 5. Newest first, by when the server stored it

`GET /api/fir-records` returns the collection in insertion order and takes no `sort`, so `FirRepositoryImpl`
is the only place an order can be imposed at all.

Ordering is by `created_at`, not by the FIR date on the form. The two differ on a back-dated filing, and an
officer scanning for *"the one I filed this morning"* is asking about the former.

Records whose timestamp is missing or unreadable sort to the **bottom**. An unparseable value is not evidence
of recency, and floating one to the head of the list would make it the first thing seen every time. Ties break
on the FIR number descending, so the order is stable between two calls instead of following whatever Mongo
happened to return.

### 6. Search is client-side, and does not read the narrative

The endpoint takes no query, no page and no sort — it answers with the entire collection or with nothing. So
there is no version of this screen that asks the server a narrower question; the only choice is whether
filtering happens in the app or not at all.

It searches the FIR number, the complainant, the district, the station, the sections and the place. **Not the
statement**: a hit inside a five-hundred-word narrative puts a row on screen with nothing visible to explain
why it is there, and "theft" matches half a station's records.

The honest limit: a station with tens of thousands of FIRs will feel this, because every open pulls every
record. The fix is a paged, searchable endpoint server-side — not a smarter client — and until that exists the
app should not pretend otherwise by paging a list it has already downloaded.

### 7. The list row shows no part of the complaint

Four things: the number, who reported it and where, what it was filed under, and when it was recorded. A
truncated first line of a statement is the part of a complaint least likely to identify it, and on a shared
handset it puts the details of a case on screen for whoever is standing nearby.

### 8. Download means fetch, save, and open — not "open the URL"

`url_launcher` on `/fir/download/<no>` would have added no dependency at all. It was rejected: that hands the
fetch to the browser, so the **common** 404 — a record whose PDF lives on another machine — surfaces as a raw
JSON blob in a browser tab, and the app never learns whether the download worked.

Instead Dio streams it to app-private storage and `open_filex` hands it to whatever reads PDFs on the handset.
Three steps that fail differently, which is why they are three:

| Step | Fails when | Reported as |
|---|---|---|
| choose a path | the device is full or the directory is unwritable | a failure |
| fetch the bytes | no PDF on this server, or the server is unreachable | a failure, with the reason |
| open the file | nothing installed reads PDFs | **not** a failure — *"Saved as FIR_41_2026.pdf, but this handset has no app that opens PDFs."* |

The middle column is the point. *Downloaded but unopenable* is not a failed download, and reporting it as one
sends an officer to try again over a station connection when what they need is a viewer.

The file goes to the app's documents directory, **not** the device's Downloads folder. Writing there needs
`MediaStore` on Android 10+ or a storage permission below it, and the prompt an officer would see asks to
*"access photos and files on your device"* — a large thing to ask for a copy of a record they can already
read on screen. The trade is real: the file is not browsable in a file manager afterwards.

### 9. The Download button is always offered

Even when the record names no PDF. Whether the file is still there is not a question the record can answer —
the column is a claim written at filing time, and the object behind it lives in a Supabase bucket the app
never talks to — so the button asks, and a 404 comes back as a sentence explaining that, rather than as a
button that was never there and never said why.

**Two columns, one PDF.** PDF storage moved to Supabase and the column moved with it: the server writes
`pdf_url` now and used to write `pdf_file`, a filename under its own `generated_firs/`. Records from both eras
are in the same collection and the same history list. The app had only been taught `pdf_file`, so every FIR
filed since the move reported no PDF at all — the row was hidden on the record screen and on the receipt.
`FirPdf.label` reads whichever column the record has and reduces a URL to its last path segment, because a
hundred-character Supabase URL on a record screen tells an officer nothing they can act on.

The download itself was never affected: it goes through `GET /fir/download/<fir_no>`, which 302s to the
bucket, and Dio follows the redirect.

### 10. The viewer re-reads the record; it is not handed one

Addressed by `/fir/record/:firNo`, so it rebuilds itself from its URL after a process death and shows what the
server holds *now* rather than what the list happened to download an hour ago. The same decision the evidence
detail screen makes, for the same reasons.

### 11. Read-only, and permanently so from the app's side

The server has **no route that updates an FIR**. `/generate_fir` only inserts, and rejects a number it already
holds. A record is corrected at the station, on the paper trail, which is what the law expects of a statutory
document — so the viewer says so in its footer instead of offering an Edit that nothing would honour.

### 12. Filing an FIR invalidates the history

`FirFormController.submit` invalidates `firHistoryProvider` on success, so the receipt screen's *Done* leads
to a history that already contains the FIR just filed. Invalidated rather than appended to: the server owns
the stored document — it mints `fir_id` and `created_at` — so re-reading is the only way the list shows what
was actually filed rather than what was sent.

Nothing polls. A colleague's FIR is picked up by pull-to-refresh, for the same reason the locker does not
reload itself on a timer.

---

## Two server bugs this feature runs into

Neither is fixed here — both are in `app.py` — but the app is written knowing about them.

1. ~~**An FIR number containing `/` cannot be filed at all.**~~ **Fixed.** `generate_fir` wrote
   `os.path.join(PDF_FOLDER, f"FIR_{fir_no}.pdf")` unsanitised, so `41/2026` — how most stations number FIRs
   — became a path through a directory that did not exist; the PDF write threw and the whole filing answered
   500 *"Failed to save FIR to database"*, after the duplicate check but before the insert. The generated
   file is now named through `secure_filename`; the number itself is still stored verbatim in `fir_no`.
2. ~~**The record and download routes could not match a slash.**~~ **Fixed.** Werkzeug's default converter
   stops at `/`, so `GET /api/fir-records/41%2F2026` and `/fir/download/41%2F2026` 404'd before reaching a
   handler — a plain Flask 404 page rather than the JSON one the app knows how to read. Both, plus
   `/fir/view`, `/get-evidence` and `/evidence-file`, now use `<path:fir_no>`. Evidence folders are named
   through a `fir_dirname` helper for the same reason, so a slashed number does not nest one directory inside
   another; every existing folder resolves to the name it already has.

The app also still has **no server-side authorisation** on any of these routes, exactly as noted in F8 and
F10: `/api/fir-records` returns every FIR in the station's database to anyone who can reach the port. The
police-only guard in `app_router.dart` is a UI guard. **The real fix is a session check server-side.**

---

## Architecture

```
lib/
├── core/
│   ├── constants/api_endpoints.dart        + firRecords, firRecord, firDownload
│   ├── utils/server_time.dart              NEW — the two spellings of created_at
│   └── utils/fir_number.dart               NEW — how an FIR number is labelled,
│                                            shared with the evidence locker
│
├── routes/                                 + /fir/history, /fir/record/:firNo
│
├── shared/widgets/feedback/state_message.dart   NEW — empty / error / no-match, one shape
│
├── features/dashboard/…/police_dashboard_screen.dart
│                                           FIR tab gains a second action card
│
└── features/fir/
    ├── data/
    │   ├── datasources/fir_remote_data_source.dart  + history, record, downloadPdf
    │   ├── datasources/fir_pdf_store.dart           NEW — where a PDF goes, what opens it
    │   ├── models/fir_models.dart                   + FirRecordResponse
    │   └── repositories/fir_repository_impl.dart    + the newest-first ordering
    ├── domain/
    │   ├── entities/fir_record.dart                 NEW — all 27 entries + server metadata
    │   └── repositories/fir_repository.dart         + the read side
    └── presentation/
        ├── controllers/fir_providers.dart           NEW — the feature's wiring, moved
        ├── controllers/fir_history_providers.dart   NEW — the list and one record
        ├── controllers/fir_download_controller.dart NEW — fetch → save → open
        ├── screens/fir_history_screen.dart          NEW
        ├── screens/fir_record_screen.dart           NEW — the FORM IF-1 viewer
        ├── widgets/fir_record_tile.dart             NEW — a row, reused by the sheet
        ├── widgets/fir_picker_sheet.dart            NEW — showFirPicker, for the locker
        └── widgets/fir_history_keys.dart            NEW
```

**Why `fir_providers.dart` exists.** `firRepositoryProvider` lived in `fir_form_controller.dart` while the
form was its only reader. Leaving it there would have meant the history providers importing the form's
controller to reach the repository, and the form's controller importing the history providers to invalidate
the list after filing — a cycle between two files with nothing to say to each other. The controller re-exports
it, so every existing import still resolves.

**Why `FirPdfStore` is behind an interface.** Both halves of it need a platform channel — `path_provider` for
the directory, an Android intent to open the file — and a widget test has neither. It is the same seam as
`EvidenceFilePicker` in the locker.

**Why the history list is a pushed route and not a third tab.** Filing an FIR and filing evidence are things
an officer switches between several times an hour, which is what makes those two tabs. Reading past records is
something they go and do, come back from, and do not want the console rearranged for.

---

## Routes

| Path | Name | Screen | Guard |
|---|---|---|---|
| `/fir/history` | `firHistory` | `FirHistoryScreen` | police / admin |
| `/fir/record/:firNo` | `firRecord` | `FirRecordScreen` | police / admin |

Both fall under the existing `/fir` prefix, so the role guard needed no change — which is what
`AppRoutes.policePrefixes` is for.

---

## Android

`open_filex` needs nothing in the manifest: it ships its own `FileProvider`, and the file it opens is in
app-private storage, so there is no permission and no `<queries>` entry to add. A handset with no PDF viewer
is handled in the app, not by the build.

---

## Tests

```
test/
├── unit/features/fir_history_test.dart          ServerTime, the wire contract, the ordering,
│                                                 the download 404 — against a stub adapter
├── widget/features/fir_history_screen_test.dart  list → search → record → download
├── widget/features/evidence_locker_test.dart     + choosing the FIR from history
└── golden/police_console_golden_test.dart        + the record viewer

test_live/fir_live_test.dart                      + the FIR history group
```

```bash
flutter analyze     # no issues
flutter test        # 226 pass
```

The unit suite drives `FirRepositoryImpl` through a real `FirRemoteDataSource` over a stubbed
`HttpClientAdapter`, so the ordering, the row-skipping and both 404s are asserted against the *server's
replies* rather than against a fake repository.

One thing worth knowing before writing more of these: a widget test runs in a fake-async zone, so a real
`dart:io` future never completes. `FakeFirRepository.downloadPdf` writes its placeholder **synchronously** —
an async write there hangs the download controller mid-flight and the button's spinner never stops.

### The live suite

Three things only a real server can settle:

1. **`created_at` really does arrive as an HTTP date** from the list endpoint. The whole ordering rests on
   parsing it, and the test fails with the raw string when `ServerTime` does not recognise a shape.
2. **The PDF that downloads is a PDF.** A 200 carrying an HTML error page would also write a file; the probe
   checks the `%PDF` magic bytes.
3. **The 404s carry what the app claims they do**, for both an unknown record and a missing PDF.

```bash
venv/bin/python app.py
flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

It files an FIR to read back, and nothing has a delete route — see the cleanup in
`docs/features/03-evidence-locker.md`.

---

## Deliberate omissions

| Not built | Why |
|---|---|
| Rendering the PDF in the app | Needs a PDF widget package to duplicate a page the app already renders better from JSON. The download exists for the file an officer has to *keep* or send, not to read. |
| Sharing the PDF | The viewer the file opens in has a share action of its own. A second one in the app would need `share_plus` to do the same thing one tap earlier. |
| Editing or deleting a record | The server has no route for either, and an FIR is corrected on the paper trail. A control the server would not honour is worse than none. |
| Filters beyond the search box — by station, by date, by section | Every one of them is a client-side pass over a list that is already fully downloaded. Worth adding when the endpoint can answer them; adding them now hides how much this screen fetches. |
| Paging | Same reason. The collection arrives whole; pretending otherwise in the UI would be theatre. |
| Saving to the device's Downloads folder | Needs `MediaStore` or a storage permission whose prompt asks for far more than this feature deserves — see decision 8. |
| Opening the evidence filed against a record | The link is worth having in both directions, but it belongs to whichever feature is touched next — see below. |

---

## What it unblocked, and what it did not

**Built on top of it, in the same pass:** the evidence locker's Add screen no longer asks the officer to type
an FIR number blind. `showFirPicker` — the history list's rows in a bottom sheet — fills the field from
records, and the locker's one cross-feature import is that function.

Typing stays the primary path and the sheet fetches only when opened. An officer at the counter has the number
in front of them, and making them wait for every record in the station to download before entering four
characters would be a picker charging rent. A sheet that fails to load says so and leaves the typed value
alone; the server checks the number either way.

**Still not addressed:** the endpoint. Everything above is a client-side arrangement around
`GET /api/fir-records` answering with the whole collection, and the sheet inherits that cost the first time it
is opened. A paged, searchable, authenticated endpoint remains the fix.

```
flutter test        # 226 pass
```

# Feature 8 — FIR Registration (FORM IF-1)

**Status:** Complete. Verified against the live Flask server, including a per-column round-trip of all 27
statutory entries.
**Scope built:** the police console's flagship — filing an FIR from a handset.
**Flow:** Police dashboard → FIR tab → New FIR → four steps → review → File → Receipt.

FORM IF-1 in full: **27 entries across four steps, then a review page**. Twenty-five are collected on the
form and two are derived, so the record a handset files has the same shape as one filed at a desk.

---

## What it does

| Capability | Endpoint | Notes |
|---|---|---|
| File an FIR | `POST /generate_fir` | 27-entry FORM IF-1 payload; server writes the record and generates a PDF |
| District picker | `GET /api/districts` | 31 states/UTs, sorted server-side |
| Station picker | `GET /api/police-stations/<district>` | Cascades off the district |
| Act picker | `GET /api/acts` | The eight act codes the section tables are keyed by |
| Suggest sections | `POST /api/suggest-sections` | Reads the narrative and proposes sections with a reason each — see `08-section-suggestions.md` |

Runs against the **existing** `NyayaAI_DB.fir_records` collection — the same records the website's console
writes. No new store, no migration, no parallel numbering.

---

## Why four steps and not one page

Twenty-five entries on one scroll is eight screens of form. An officer loses their place in it, and worse,
cannot tell what is left — the only way to find out is to keep scrolling. The wizard's four steps are the
**paper form's own groupings**, so an officer working from IF-1 finds each entry where they expect it:

| Step | Entries | Collects | Required |
|---|---|---|---|
| 1 · Registration | 1–3 | FIR number, district, police station, FIR date, acts & sections | first four |
| 2 · Occurrence | 4–7 | occurrence date/time, information received date/time, GD entry no., type of information, place of occurrence | none |
| 3 · Complainant | 7 | name, father/husband, DOB, nationality, passport block, occupation, address | name only |
| 4 · The complaint | 8–12 | accused, reasons for delay, property particulars, what happened, attachments | narrative only |
| Review | — | nothing — it prints what will be filed, with an Edit link per group | — |

Each step's header says `Step 2 of 4`, and the bar above it fills as they are passed, so "how much is left"
is answerable without scrolling. The review is deliberately **not** counted as a fifth step — it collects
nothing, and `FirFormStep.review.number` answers 0 for that reason.

The required entries are checked **per step**, on Next, so a missing FIR number is raised on the page that
can fix it rather than four pages later. Nothing on step 2 is required at all, so an officer who has none of
it presses Next straight through.

### Filing is only possible from the review

`submit()` is reachable from one screen, and it is the one that prints the whole record back. An FIR is a
statutory document that cannot be edited after it is written — the server has no update route — so the last
thing between an officer and that is a page showing exactly what is about to be stored, with an Edit link
beside each group that jumps back to the step that owns it.

### The record

`FirSubmission` sends **all 27 keys**, every time. Twenty-five come off the form; `year` and
`occurrence_day` are derived (see decision 4). An entry the officer left blank is sent as an empty string
rather than omitted — the handler builds a fixed-shape document and reads each key with `data.get(key, "")`,
so the two are equivalent to it, but the document it writes is the one the website's console, the generated
PDF and F9's history all read back, and a record filed from a phone should be indistinguishable in shape from
one filed at a desk.

There is a live test pinning every one of the 27 columns. An empty column is exactly what a misspelt key
produces, so a test that checked only the entries it expected to be filled would pass while the record
quietly lost its shape.

---

## The decisions that shaped it

### 1. Six of the 27 entries are required, and all six are the app's own rule

`POST /generate_fir` accepts a payload of empty strings and files it. Its **only** rejection is a duplicate
FIR number. So every requirement the form imposes is the app's judgement, and each one is a thing standing
between an officer and a registered FIR — which is why the list is short and stops where it does.

An FIR missing its complainant or its narrative is not a lighter record, it is an unusable one, and the officer
is the only person positioned to notice before it is stored.

The six are the FIR number, district, police station and FIR date on step 1; the complainant's name on step
3; and the narrative on step 4. Every other entry is one an officer may genuinely not have. An informant who
walks in at midnight unsure which day the theft happened, with no passport and no idea who the accused is, is
still entitled to have the complaint registered: an offence does not stop being cognisable because a column
is blank. A wizard that demanded all 27 is a wizard officers learn to fill with placeholder text.

Acts and sections are the one that looks required and is not — see below.

### 2. Sections are optional, because the server fills them in

When `act_sections` arrives empty, the handler runs the narrative through `analyze_complaint_for_sections`
and files the record under what it suggests. The website's own field is optional for exactly that reason,
with the same note under it.

This form used to require at least one pair, and that made the app the stricter of two clients onto one
collection: an officer who could file at the desk could not file the same complaint on the handset until they
had gone and looked the sections up. The field is optional now, and says under its label that leaving it
blank hands the job to the server.

Nothing is filed unseen. The receipt reads `act_sections` back off the response rather than echoing what was
sent, so what the server chose is on the screen the officer is handed the FIR number from.

**And it no longer has to be a surprise.** *Suggest acts and sections*, under the narrative on step 4, asks
the server what it would choose and shows the answer — a reason and a confidence per section — before the FIR
is filed. It is the same decision `/generate_fir` was already making silently, moved one screen earlier and
made rejectable. See `08-section-suggestions.md`.

The pairs are built one at a time through a sheet, and the app owns the join — `IPC Section 379, CRPC Section
41`, exactly the spelling the website produces. Typing that string by hand on a phone is how a record ends up
un-findable by the query that needs it, and nobody notices for months.

### 3. Proof files are picked here and filed after the record exists

The website's form has a proof picker at the bottom and uploads what is in it the line after `/generate_fir`
answers — `uploadProofsForFIR(data.fir_no)` in `script.js`. This form does the same, and it had to: there is
no order of operations that gets a photograph into the locker first, because `/upload-evidence` checks
`fir_exists(fir_no)` and refuses anything else.

Without it, an officer at a scene had to file the FIR, remember the number, leave the form, open the locker
and type the number back in before they could attach the photograph they had already taken.

The files are held in memory on `FirFormState` and are deliberately **not** part of the autosaved draft.
Everything in the draft is text that survives a day in the keystore; a picked file is a path into a cache
directory the OS is free to empty, and restoring a draft that claimed three photographs it could no longer
open would be worse than restoring one that claimed none.

**A failed upload does not fail the filing.** The record is written by the time the uploads run, so reporting
"filing failed" would be false and retrying it would put a second FIR in the register. The receipt says what
happened to each file instead, and points at the locker for whatever did not go up — see `FirProofOutcome`.
They go one at a time, matching the website's own loop: a station handset on a rural link uploading four
photographs at once gets four timeouts instead of two files.

### 4. Two entries are derived, not asked

| Entry | Derived from | Why |
|---|---|---|
| `year` | the FIR date | Left independent, the two diverge the first time a December filing is registered in January — and two entries disagreeing inside one record is the kind of defect raised in court. It is not offered as a field, because there is nothing to edit it *to* that would not be wrong. |
| `occurrence_day` | the occurrence date | IF-1 asks for both; they cannot disagree |

Nothing else is pre-filled. The FIR date is seeded to today because an FIR is registered when it is written —
that is a fact, not a guess.

### 5. Nothing is flagged before it is attempted

A form that marks every required box the moment it opens looks broken, and trains people to ignore red.
Errors appear on the first refused **Next**, all at once, beside the boxes on that step that caused them —
which is the whole reason the check is per-step rather than saved for the review. An officer told on step 4
that something on step 1 is missing has to go and find it; an officer told on step 1 fixes it while they are
looking at it.

Neither Next nor File is ever disabled. A greyed-out button gives an officer nothing to press and no reason
why; pressing it and being shown the two entries that are missing is the shorter path to a filed FIR.

### 6. The draft survives everything except filing

Losing a part-written FIR to a backgrounded app that Android then killed is the one failure this feature
cannot recover from. The draft autosaves to **secure** storage (it holds a complainant's name and the
narrative before the server has either), debounced a second so a burst of typing is one write, and flushed
when the screen goes away.

It is deleted the moment the FIR is filed, so a record can never be offered back as unfinished work.

**The autosave only writes when something has been typed.** The form seeds itself with today's FIR date, so it
is never quite `isEmpty` — without a dirty flag, opening the form and backing straight out would leave a
"draft" nobody wrote, and the next visit would greet the officer with *picked up where you left off* over a
blank page. Discarding one and leaving would do the same, immediately after the officer asked for it to be
gone. There is a test for both.

`firFormControllerProvider` is deliberately **not** `autoDispose`: an officer who leaves to check the station
register comes back to the form as they left it.

`FirDraft.fromJson` reads `place_address` as a fallback for `place_of_occurrence`, so a draft written by an
earlier build restores rather than losing its address, and any key it does not recognise is ignored instead
of throwing.

### 7. Submission is never retried automatically

The FIR number is the one entry that can fail at the very end, and a timeout is ambiguous — the record may
have been written before the connection dropped. A silent retry would either file a duplicate or come back
with "already exists" against an FIR the officer *did* successfully file. So the failure stays on the form
with the server's own wording, and the next attempt is a deliberate one.

The File button is a spinner while in flight, which is what makes "one press files one FIR" true; there is a
test for the double-tap.

### 8. A failed lookup does not block filing

Registering an FIR is a legal duty with a clock on it. The district list is a convenience. When a lookup
fails, the field becomes a typed entry with the failure's own message and a Retry beside it — an app that
refuses to file because it could not fetch 31 strings has confused its reference data for the record.

A typed value is no less acceptable to the server than a picked one: `/api/police-stations/<district>`
synthesises `"<district> PS"` for anything it does not recognise, and there is a live test pinning that.

---

## Architecture

```
lib/
├── core/
│   ├── constants/api_endpoints.dart      generateFir, districts, policeStations, acts
│   ├── constants/storage_keys.dart       firDraft
│   └── utils/form_dates.dart             wire (yyyy-MM-dd / HH:mm) ↔ display
│
├── routes/                               /fir/new, /fir/success, behind the police guard
│
├── shared/widgets/
│   ├── feedback/form_banner.dart
│   └── inputs/                           app_text_area, app_picker_field,
│                                         option_picker_sheet, text_entry_dialog
│
└── features/fir/
    ├── data/
    │   ├── datasources/fir_remote_data_source.dart
    │   ├── models/fir_models.dart            FirSubmission (27 keys), FirReceiptResponse
    │   └── repositories/fir_repository_impl.dart
    ├── domain/
    │   ├── entities/                         act_section, fir_draft, fir_receipt
    │   └── repositories/fir_repository.dart
    └── presentation/
        ├── controllers/                      fir_form_controller, fir_form_state,
        │                                     fir_lookup_providers,
        │                                     section_suggestion_controller
        ├── screens/                          fir_form_screen, fir_success_screen
        └── widgets/                          act_sections_field, fir_field_controllers,
                                              fir_field_keys, fir_lookup_field, form_pickers,
                                              suggest_sections_sheet,
                                              steps/ (registration, occurrence, complainant,
                                                      complaint, review, step_scaffold)
```

**Where the step lives.** `FirFormState.step`, moved by `FirFormController.next()`, `back()` and
`goTo(step)` — the last is what the review's Edit links call. There is no `furthest` and no `canJumpTo`: the
only ways forward are Next, which validates, and an Edit link from the review, which can only be reached by
having passed all four already.

**Where the form's state lives.** One immutable `FirDraft` in `FirFormController`. The screen owns the
`TextEditingController`s (a text box needs one) but every keystroke lands in the draft on the same frame, so
there is never a second version of an entry to reconcile.

**Where the wire mapping lives.** `data/models/fir_models.dart`, not on the entity. The server's column
names are its own and are not tidy (`dist`, `ps`, `gdr_entry_no`, `dob`); the domain owes them nothing. The
draft's *own* `toJson` — the autosave shape — stays on the entity and is deliberately different: the
draft stores what the officer typed, while the submission derives the year and the day of occurrence on top
of it.

---

## Routes

| Path | Name | Screen | Guard |
|---|---|---|---|
| `/fir/new` | `firNew` | `FirFormScreen` | police / admin |
| `/fir/success` | `firSuccess` | `FirSuccessScreen` | police / admin, **and** an FIR must have just been filed |

The role guard is one loop over `AppRoutes.policePrefixes` in the router's redirect rather than a check inside
each screen, so a new route under `/fir` cannot ship ungated and no FIR screen has to render a "you may not be
here" state.

**It is a UI guard, not a security control.** `/generate_fir` has no session check at all — see
`01-authentication.md`, "Known issues in the server". It protects the officer from a dead end, not the record
from a citizen. The real fix is server-side.

The success route redirects to `/home` when there is no receipt, so a cold launch onto that URL — a restored
task, a deep link — does not show an empty congratulations.

---

## Models ↔ API

| Dart | Wire |
|---|---|
| `FirSubmission` | the 27 keys `POST /generate_fir` reads |
| `FirReceiptResponse` | the stored document + `{formatted_fir, message, pdf_url}` — and `pdf_file` behind it, for records filed before PDF storage moved to Supabase. See `FirPdf` |
| `FirDraft.toJson` | local only — secure storage, the entries the form collects |

`FirReceipt` keeps only what the client could not already know: the ID the server minted, the sections it
filed, the PDF it wrote, and when.

Three keys are composed rather than copied — `act_sections` (joined pairs), `year` (derived from the FIR
date), and `occurrence_day` (derived from the occurrence date).

---

## Tests

```
test/
├── unit/features/fir_form_test.dart          wire contract, required entries, autosave, dates
├── unit/features/fir_suggestions_test.dart   the suggestion wire shape
├── widget/features/fir_form_screen_test.dart the wizard, end to end
├── widget/features/fir_suggest_sections_test.dart  the suggestion sheet
├── widget/features/fir_route_guard_test.dart who can reach it, against the REAL app router
└── golden/police_console_golden_test.dart    form (light + dark), receipt

test_live/fir_live_test.dart                  outside test/, never in a default run
```

```bash
flutter analyze                                    # no issues
flutter test                                       # 453 pass
flutter test --tags golden --update-goldens        # after an intentional design change
```

Every control on the form carries a `Key` (`FirFieldKeys`) so a test can name an entry the way the form does,
instead of reaching for "the fourth TextField".

Every date in the goldens is fixed, including the seeded FIR date on the empty form — a golden that moves with
the calendar is a golden that fails every morning.

### The live suite

Proves what a fake cannot: that the keys the app sends land in the columns it thinks they do.

```bash
# 1. start the website, from the repo root
venv/bin/python app.py
# 2. then, from flutter_app/
flutter test test_live/ --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

**It writes to the database**, under a `ZZFLUTTER<timestamp>` FIR number, and there is no delete route:

```bash
venv/bin/python -c "from pymongo import MongoClient; \
  print(MongoClient('mongodb://127.0.0.1:27017/')['NyayaAI_DB']['fir_records'] \
    .delete_many({'fir_no': {'\$regex': '^ZZFLUTTER'}}).deleted_count)"
rm -f generated_firs/FIR_ZZFLUTTER*.pdf
```

---

## Deliberate omissions

| Not built | Why |
|---|---|
| Downloading or viewing the generated PDF | The server writes one and the app knows its filename, but fetching and rendering it is FIR History (F9). A button that opens nothing is worse than its absence. |
| Section search / browse while picking | The act picker is live; the section number is typed. F12's library now exists and could back a browser here, but reaching it mid-filing means leaving a half-written draft, and *Suggest acts and sections* covers the case it was wanted for. |
| Jumping to any step from the step bar | The bar reports progress; it is not a control. Forward has to go through Next so a step's required entries are checked, and the review's Edit links already cover going back to one group. |
| Attaching evidence during filing | Evidence uploads are rejected server-side unless the FIR already exists, so they cannot happen in the same pass. See `03-evidence-locker.md`. |
| Editing a filed FIR | The server has no update route. |
| Offline queue | "Filed" has to mean the server said so; only it can accept or reject an FIR number. |
| Sharing the FIR number | Needs `share_plus`. Selectable text covers the immediate need. |

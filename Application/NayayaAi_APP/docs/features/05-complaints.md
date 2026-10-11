# Feature 11 — Citizen Complaints

The police inbox: every complaint a citizen has filed, filtered down to the ones
that need an officer now, opened, answered, escalated, or turned into an FIR.

Built on `citizen_complaints`, a SQLite table the Flask app creates at start-up —
not on Mongo, where the FIRs live. Four endpoints, three of which this app uses.

## What it does

- **Inbox** — the whole table, newest arrival first, as the third tab of the
  police console.
- **Filters** — a stage (All · Active · Pending · Under review · FIR filed ·
  Closed), a date window (Any time · Today · Yesterday · Last 7 days · Last 30
  days · a custom range), and a search box over the tracking ID, the name, the
  phone, the place, the FIR number, the narrative and the notes.
- **Detail** — the citizen's account, read-only, and everything the station has
  written, as a trail.
- **Respond** — an officer's note plus where the complaint now stands, in one
  write.
- **Escalate** — a fixed destination and a required reason, recorded on the
  complaint and marked under review.
- **Register an FIR** — seeds the FIR form from the complaint and links the two
  when `/generate_fir` accepts the record.

Police and admin only, by the router's prefix guard — which is a UI guard, not a
security control. See "What the server does not do", below.

## The server's contract

| Route | Used | Notes |
|---|---|---|
| `GET /api/complaints/all` | yes | The whole table. No query, no page, no filter. `ORDER BY created_at DESC`. The only route that returns `phone`. Also carries `category` and `is_cognizable`. |
| `GET /api/complaint/<id>` | fallback only | One complaint, **without `phone`** — the handler's SELECT omits the column. |
| `PATCH /api/complaints/<id>` | yes | Writes `status`, `fir_no`, `officer_notes`. Validates the status against four literals. |
| `POST /api/complaint` | **no** | Filing is a citizen's action on the citizen dashboard. This app is a police console. |

`created_at` and `updated_at` are SQLite's `CURRENT_TIMESTAMP` —
`2026-08-09 02:31:00`, UTC, no zone marker — which `ServerTime` already reads,
because it is the same spelling `POST /generate_fir` replies with.

## The decisions that shaped it

### 1. The PATCH is not a patch, and every write compensates for it

The handler runs

```sql
UPDATE citizen_complaints
SET status = ?, fir_no = ?, officer_notes = ?, updated_at = CURRENT_TIMESTAMP
WHERE tracking_id = ?
```

with each value read as `data.get(key)`. A body carrying only `status` therefore
stores **NULL** over the FIR number and over every note on the complaint. Closing
a complaint would delete the reasoning that led to closing it.

So `ComplaintUpdate` has no constructor that omits a field, `ComplaintRepository.update`
takes the whole current complaint rather than just the edit, and
`ComplaintRepositoryImpl.update` composes the full triple from it. There is a
unit test that fails if a caller ever sends fewer than three columns.

### 2. `officer_notes` is treated as an append-only ledger

One free-text column, no history table. Every action stamps and signs a new entry
and puts it on the end:

```
[9 Aug 2026, 02:31 UTC · SI K. Deshmukh] Rang the complainant, took a statement.
[9 Aug 2026, 04:02 UTC · SI K. Deshmukh] Escalated to Cyber Cell. Reason: the money left through a payments app.
```

It is a convention, not a constraint — the website's console can still overwrite
the column — but it costs nothing and it is the only place the station's
reasoning about a complaint survives. Newest last, because a trail is read
forwards.

The stamp is built by handing `ServerTime` a string in the shape it already
parses, so a note and the timestamps printed beside it can never drift apart.

### 3. The four statuses are the server's, not a design

`valid_statuses = ['Pending', 'Under Review', 'FIR Filed', 'Closed']`, compared
literally, HTTP 400 otherwise. There is no "Assigned", no "Rejected", and — the
one that matters — no "Escalated".

An unrecognised value in the column parses to `null` rather than falling back to
Pending: nothing but this PATCH is supposed to write it, so an unreadable value
means the row was edited outside the application, and reporting it as Pending
would put a complaint somebody had already dealt with back at the top of the
inbox. The chip prints the stored word, and the row stays in "Active" because
nobody can prove it has been handled.

### 4. Escalation is a note and a status, and the sheet says so

There is no assignee column and no notification of any kind. Escalating writes a
fixed-wording note and moves the complaint to Under Review; nothing is sent
anywhere, and whoever reads the inbox is the routing. The sheet's subtitle says
that in as many words.

An escalation control that let an officer believe a message had left the building
would be worse than not having one — the complaint would sit unread by exactly
the person it was escalated to, with the escalating officer confident they had
handed it over.

The destination is a fixed list (`EscalationDesk`) rather than a text box for one
reason: the note is the only searchable trace, and six officers will spell the
same desk five ways. The reason is required by the app, because an escalation
with no reason hands the next desk a complaint and no idea why they have it.

### 5. "Register an FIR" is two writes separated by an unbounded gap

The officer converts a complaint, then spends ten minutes choosing sections, backs
out to check the station register, comes back, and files — or never files at all.
The link can only be written when `/generate_fir` answers, because until then
there is no FIR number and the one being typed may still be rejected as a
duplicate.

So the connection is a listener that outlives both screens.
`ComplaintFirLinkController` seeds the FIR form, remembers the tracking ID, and
watches `firFormControllerProvider` for a receipt. It reaches *into* the FIR
feature and never the other way round: the FIR feature knows nothing about
complaints, which keeps a statutory record's code free of an inbox's concerns.

What carries over is what a citizen can supply and an officer would otherwise
re-type — the complainant, the narrative, the place, and the incident date **only
when it parses as a date**, because `incident_date` is free text and the FIR's
occurrence date is a `yyyy-MM-dd` column that the year and the weekday are both
derived from.

What does not carry over is the FIR number, the district, the police station and
the acts and sections. Pre-filling a charge from a citizen's description would be
the app making a charging decision.

If the app dies between filing and linking, the link is lost — the FIR is safe on
the server, and the complaint stays as it was. The officer attaches the number by
hand from the respond sheet, which is why that sheet has an FIR-number box.

### 6. The detail screen resolves out of the list, not out of the single endpoint

`GET /api/complaint/<id>` does not select `phone`, and an officer opening a
complaint is usually about to ring the person who filed it. The list has every
column, is already in memory, and is invalidated by every write — so resolving
out of it also means the detail screen refreshes itself the moment a response is
saved, with no second fetch and no chance of the two screens disagreeing.

The direct endpoint is still the fallback, for a deep link or a return from
process death.

### 7. Every filter is client-side, and the days are UTC

`GET /api/complaints/all` takes no query, no page and no filter, so the choice is
only whether the narrowing happens in the app or not at all. Same call FIR
history makes, same honest limit: a district with tens of thousands of complaints
will feel every open of the tab, and the fix is a filtered endpoint server-side
rather than a cleverer client.

The date windows cut on **UTC** calendar days, because every timestamp the app
shows is labelled UTC. Filtering on the handset's local midnight instead would
mean a complaint whose row reads `9 Aug 2026, 19:00 UTC` appearing under "Today"
on the 10th in India — a list that contradicts the dates printed in it. The
filter sheet says the days are UTC.

A complaint whose timestamp is missing or unreadable is **excluded** while a date
filter is on, and shown under "Any time". Letting it through every window would
put the same row in Today and in Yesterday and make both counts lie.

### 8. The stage is on the screen; the date is behind a button

Switching between Active and All is what triage *is* — an officer does it several
times in a sitting — so the stages are chips, always visible, which also means a
filter left on from yesterday cannot hide behind an icon and make an inbox look
empty. A date range is chosen once and then worked within, needs six options and
a calendar, and lives in a sheet behind a button that shows the current choice
when one is set.

`ComplaintStage.open` ("Active") is the shortcut the server's vocabulary does not
have: Pending, Under review, and anything unreadable.

### 9. The row carries what the complaint is about

The description gets two lines and the largest type in the row, because it is the
only field that distinguishes one complaint from another and it is what the
search box matches on. The tracking ID is set small and last — nobody recognises
`CMP-3F91A2C7`, but it gets read out on the phone.

### 10. The server's triage of the narrative is on the row

`complaint_categorizer.py` derives a `category` and an `is_cognizable` flag from the description by keyword
match at filing time, and stores both. **The citizen is never asked** — which is the point: somebody who has
just been robbed should not have to know whether that is "Theft / Robbery" or "Financial Fraud / Cheating"
before the station will read their complaint.

The website's board has shown these since it had them — a coloured pill per category, a ⚠️ on the cognizable
ones, and columns to group by. The app read neither, so an officer moving between the console and the handset
saw a triage decision on one screen and not the other.

The chip carries the one distinction that changes what an officer does next — **can an FIR be filed on
this?** — rather than the website's ten colours. The palette has four, each already meaning something; ten
categories cannot be given ten of four, and inventing six more leaves a rainbow where every hue is a wrong
guess away from meaning something it does not. So cognizable is drawn in the alert colour with the website's
own ⚠️, everything else is muted, and the label carries which of the ten it is. The tooltip is the website's
sentence verbatim.

It is **advisory, and nothing in the app enforces it**. It is what a keyword matcher concluded from the words
a distressed person happened to use; an officer who reads the narrative and disagrees registers the FIR
anyway.

The filter offers the seven crime categories individually, collapses the three "we could not tell" buckets
into one — exactly as the website's board does — and adds **FIR possible** at the top, which is the question
an officer actually asks the inbox and would otherwise take seven taps to answer. Rows with no category at
all, and rows whose category the app has never heard of, fall into the same bucket as the unclassifiable
ones: a complaint nobody has classified is precisely the one that needs reading, and the only filter that
would surface it is that one.

`is_cognizable` arrives as SQLite's 0/1 and is read as null when absent — "the row never said" and "the row
said no" are different facts, and only one of them is a triage decision.

### 11. Four counts above the filters, and a badge on the tab

The console has the same four across the top of its complaints panel — total,
pending, under review, FIR filed — and a pending count on its sidebar. Both
answer the question an officer asks on arriving at the desk: *how much of this is
mine, and how much has been dealt with?* Four integers answer it; a chart would
take three times the height to say it less precisely, on the screen where
vertical space is the list.

**They count the whole table, not the filtered view**, and they read
`complaintsProvider` themselves rather than taking a list from the inbox — which
watches the *filtered* provider, so a list handed down would have made the
numbers move with the filter. That is exactly what they must not do: the count
under the list already says "12 of 48" for what a filter is showing, and a header
that also moved would be the same number said twice. Filtering to Pending still
shows that eleven others are under review.

Each tile is a filter, and tapping the selected one clears back to All. A row of
numbers an officer cannot act on is a row they stop reading.

The tab badge reads whatever the inbox has already fetched and **does not fetch**
— a badge that pulled the whole table on every cold start, for a tab the officer
may not open, would be a request nobody asked for. It shows nothing while the
list is loading or failed: a badge is an invitation, and one the app is not sure
about is better left unsaid than shown as a zero.

### 12. The board, turned on its side

The console has a board view: eight columns, one per category, complaints as
cards inside them, toggled from the table. It is the right shape for a desktop,
where all eight are visible at once and the comparison between columns *is* the
information.

Eight columns on a 390-point screen are not eight columns; they are one column
and a horizontal scrollbar, and a board nobody can see across has none of the
advantage a board has. So the same grouping is drawn vertically: every category
that has complaints, in the board's own order, each headed with its name and a
count. One axis to scroll, the same division.

Categories with nothing in them are omitted, where the website draws all eight.
On a desktop an empty column is information — "no homicides this week" — and
costs nothing. On a phone it is a heading the officer scrolls past to reach the
complaints.

### 13. The count says "12 of 48", not "12"

A filtered list that prints only its own length looks like a station with twelve
complaints. The denominator is what makes a filter honest.

### 14. An empty write is refused

The respond sheet will not save when the status, the FIR number and the note are
all unchanged. An empty write still stamps `updated_at`, and "created ≠ updated"
is the signal the inbox uses to show a complaint has been dealt with.

### 15. The citizen's account is read-only, permanently

Their name, phone and words are theirs. There is no server route that would let
the app rewrite them and it should not acquire one — if the account is wrong, the
correction belongs in the officer's notes, attributed to the officer who made it.

## What the server does not do

- **No session check on any complaints route.** `/api/complaints/all`, the PATCH
  and the tracking endpoint are all unauthenticated, exactly like `/generate_fir`
  and every evidence route. The police-prefix guard in `app_router.dart` protects
  the officer from a dead end, not the record from a citizen. The real fix is
  server-side; see `01-authentication.md`, "Known issues in the server".
- **No filtering, paging or sorting parameters.** See decision 7.
- **No assignee, no routing, no notification.** See decision 4.
- **`ORDER BY created_at DESC` is a string sort** over a TEXT column. It holds for
  the timestamps the default writes and stops holding the moment a row arrives in
  another spelling — a seed script, a restored backup. The app sorts on the parsed
  instant anyway; it costs nothing on a list already in memory.

## Architecture

```
lib/features/complaints/
├── domain/
│   ├── entities/
│   │   ├── complaint.dart            the row, and everything derived from it
│   │   ├── complaint_status.dart     the server's four literals
│   │   ├── complaint_filter.dart     stage + date + query, and `apply`
│   │   ├── complaint_note.dart       composing and reading the trail
│   │   └── escalation_desk.dart      the five destinations
│   └── repositories/complaint_repository.dart
├── data/
│   ├── models/complaint_models.dart          both response shapes, and the body
│   ├── datasources/complaint_remote_data_source.dart
│   └── repositories/complaint_repository_impl.dart
└── presentation/
    ├── controllers/
    │   ├── complaint_providers.dart          DI, the inbox, one complaint
    │   ├── complaint_filter_controller.dart  the filter, the clock, the filtered list
    │   ├── complaint_write.dart              the one PATCH, and who signs it
    │   ├── complaint_action_controller.dart  respond, escalate
    │   └── complaint_fir_link_controller.dart the conversion, across screens
    ├── widgets/                              tile, chip, filter bar, three sheets
    └── screens/
        ├── complaints_inbox_screen.dart
        └── complaint_detail_screen.dart
```

`ComplaintFilter.apply` is pure — a function of the filter, the list and the
clock — which is what lets every filtering rule be unit-tested without building a
widget. The clock comes from `complaintClockProvider` so nothing in the feature
calls `DateTime.now()` on its own.

`complaintAuthorProvider` is the feature's only dependency on authentication: it
is the name notes are signed with, and it is the seam tests override rather than
standing up a session.

## Routes

| Path | Name | Screen |
|---|---|---|
| — | — | `ComplaintsInboxScreen`, the console's Complaints tab |
| `/complaints/:trackingId` | `complaintDetail` | `ComplaintDetailScreen` |

The inbox has no route of its own, for the same reason the evidence locker's list
has none: it is a queue an officer works between complaints, and it has to keep
its filter and its scroll position. `/complaints` is in `AppRoutes.policePrefixes`,
so the detail route is gated with the rest.

## Tests

75 — 44 unit, 31 widget.

```bash
flutter test test/unit/features/complaints_test.dart
flutter test test/widget/features/complaints_test.dart
```

`test/unit/features/complaints_test.dart` covers the server contract (both
response shapes, NULL columns, the three-key body), the filter rules against a
pinned clock, the note ledger, and the repository — including a `_FakeServer`
Dio adapter that proves the PATCH carries the columns it was not asked to change.

`test/widget/features/complaints_test.dart` drives the inbox, both sheets and the
conversion, ending with the one that matters most: filing an FIR seeded from a
complaint links the two, appends to the trail, and does not touch a complaint
nobody converted.

Helpers: `test/helpers/complaints.dart` (fixtures),
`fake_complaint_repository.dart`, `pump_complaints_app.dart`.

### Cleaning up after a live run

There is no live suite for this feature yet. If one is added, remember that
complaints live in SQLite rather than Mongo:

```bash
sqlite3 <DB_PATH> "DELETE FROM citizen_complaints WHERE tracking_id LIKE 'CMP-TEST%';"
```

## Deliberate omissions

- **Filing a complaint.** `POST /api/complaint` is a citizen's action. An officer
  handed a complaint in person registers an FIR, which is a heavier document with
  its own route.
- **Deleting or archiving.** The server has no route, and a complaint that can be
  deleted from a phone is a complaint that will be.
- **Editing the citizen's account.** See decision 12.
- **Attaching evidence to a complaint.** The locker is keyed on FIR numbers and
  `/upload-evidence` rejects an FIR that does not exist. Evidence attaches after
  the complaint becomes an FIR.
- **A golden test.** The inbox and the detail screen are not pinned by images
  yet; the console golden covers the FIR and evidence tabs only.

## What it unblocked, and what it did not

The complaints inbox is the first surface in the app where an officer *changes*
something a citizen filed, which is what made the append-only note convention and
the read-modify-write around the PATCH necessary. Both are reusable the next time
a feature has to write to a column somebody else also writes to.

It did not unblock assignment, notification or supervision. All three need
columns the table does not have, and adding them is a server change rather than
an app one.

# Features 6 & 7 — Missing Persons

**Status:** Complete on the police side. The sighting flow works for any signed-in role, but there is no
citizen dashboard to reach it from yet.
**Flow:** Sign in as police → **FIR** tab → Missing persons → Register / open a case → Report a sighting.

---

## What it does

| Capability | Endpoint | Permissions |
|---|---|---|
| Open cases, newest first | `GET /get_missing_persons` | anyone |
| Register a case | `POST /upload_missing_person` | **police only, enforced** |
| Report a sighting | `POST /report_sighting/<person_id>` | any signed-in role |
| Every sighting on a case | `GET /get_sightings/<person_id>` | **police only, enforced** |
| Confirmed face matches | `GET /get_confirmed_matches` | **police only, enforced** |
| Mark Found / Closed | `POST /update_missing_person_status/<person_id>` | **police only, enforced** |

Runs against the **existing** SQLite `missing_persons` and `missing_person_sightings` tables, and
`static/uploads/missing_persons/` and `static/uploads/sightings/`.

---

## The only endpoints in this app whose police check actually works

`/generate_fir`, the whole evidence locker and every complaints route have no session check at all — the
app's police gate on those protects the officer from a dead end, not the record from a citizen.

These four are different. They call `_is_police()` and answer **403 `{"success": false, "error": "Police
login required."}`**. So a 403 here is a real refusal the app has to be able to render, and it is not a state
the router's guard can make unreachable: a session can lapse while the screen is open.

That shapes two things. The data source reads the `{success, ...}` envelope on the way past and lifts the
server's own sentence out of it — a **200 whose body says `success: false` is a real shape here**, so the
status alone is not enough. And the confirmed-matches panel on the register renders *nothing* when it fails
rather than a banner: the register below it has no session check and still loads, and a red bar over a list
that works would be reporting a problem with a panel that is not why the officer opened the screen.

## The photograph is the feature

Every other field is optional server-side; even the name is only checked for being non-empty. The photograph
is what a sighting is compared against, and the server runs a face detector over it and **refuses the whole
registration** when it finds none, deleting the upload on the way out.

So the photograph is first on the form, it is large, it is shown from disk the moment it is picked, and the
refusal is put on screen **in the server's own words**. *"No face detected in the photo. Please upload a clear
frontal image."* tells an officer photographing a printed poster exactly what to do next. *"Registration
failed"* sends them to ring the station.

The Register button is disabled until a photograph is chosen — the one place in this app where greying out
says more than pressing would, because the note above it states the reason.

## Confirmed matches sit above the register, not on a tab

A confirmed match is the only thing on the screen that is asking for something. The register is reference —
thirty faces an officer scrolls when somebody walks in with a lead — and a match is a person the comparison
believes has been seen, which is work that has arrived and is waiting.

On a tab it would be work nobody looks at until they think to. At the top of the list it is the first thing
on the screen an officer opens for any reason at all, and it collapses to nothing when there are none.

**Both photographs are on the card, always.** The comparison runs at a tolerance of 0.55, which is loose
enough that an officer has to be able to look at the two faces and disagree. A card that showed only a score
would be asking them to take a number's word for whether a missing child has been found.

## One number, two spellings on the wire

The server sends the match confidence two ways:

- `GET /get_sightings` → `face_match_score`, the **raw 0–1** figure;
- `GET /get_confirmed_matches` → `confidence` and each `score`, **already multiplied by 100** and rounded.

A client that read either as the other would report a 72% match as 0.72% or as 7,200%. Both are normalised to
0–100 in the models, and there is a unit test for each direction.

`is_confirmed` is read from the server rather than re-derived from the score. The threshold is the server's to
change, and a client that computed its own would start disagreeing with the website the day it did.

## Near misses are kept

The sighting list holds everything reported, not only what matched. A 48% match on a blurred photograph from
the right neighbourhood is worth an officer's eye, and a list that hid it would be hiding the one lead there
was. The confirmed ones are outlined and flagged; the rest are plain.

## Marking a case found is a one-way door

`/get_missing_persons` returns only cases still marked `Missing`, and **no endpoint returns one that is
not**. A case marked Found leaves the app for good — it cannot be listed, opened or reopened from here.

So it is confirmed, and the dialog says that rather than "are you sure?": *"Nothing in the app can reopen it —
that has to be done on the website."*

The detail screen resolves its case out of the list already in memory, the same arrangement the complaint
detail screen uses and for the same reason: there is no single-record endpoint. A case that is not in the
list has been marked found or closed since it was read — by a colleague, or by this officer on another device
— and the screen says so instead of showing an error.

---

## Where it lives

A pushed route from the FIR tab rather than a fifth tab. Registering a missing person and reviewing the
sightings that come back is something an officer goes and does and comes back from, like FIR history — not
something they switch between while working a counter.

`/missing-persons`, `/missing-persons/new` and `/missing-persons/:personId`, all behind the police guard.
The `new` route is declared **before** `:personId`: GoRouter matches children in declaration order, and a
`:personId` sibling declared first would swallow `/missing-persons/new` and open a case whose ID is the word
"new".

## Known issues in the server

- **A resolved case is unreachable.** There is no endpoint that returns a case whose status is not `Missing`,
  so the app cannot show a history of found cases however much it might want one.
- **A grouped sighting carries no ID.** `/get_confirmed_matches` does not select `sighting_id`, so an
  individual confirmed sighting cannot be addressed.
- **Face recognition may be in demo mode.** `face_recognition`/`dlib` are optional; without them the server
  logs `Running in DEMO mode` at startup and the comparison is not a real one. Nothing in the response says
  which mode produced a score.

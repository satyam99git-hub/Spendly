# Suggested acts and sections

`POST /api/suggest-sections` · `flutter_app/lib/features/fir/…/suggest_sections_sheet.dart`

## What it does

Under the narrative on the FIR form there is now a **Suggest acts and sections**
button. It reads what the officer has written, and answers with up to five acts
and sections, each carrying one line saying which fact in the narrative triggers
it and how confident the server is. The officer ticks the ones that fit and taps
Add; those become chips on the form's sections field. Nothing else happens.

## Why, when the server was already doing this

It was, and that is the point. `/generate_fir` has always run
`analyze_complaint_for_sections` over the narrative whenever the sections field
arrives empty, and filed the record under whatever it found. What it never did
was **say so**. The officer learned which sections had been chosen by reading
them off the receipt, after the FIR was registered, with no way to disagree.

So this is not a new decision being handed to a model. It is the same decision,
moved one screen earlier and made rejectable:

| | Before | Now |
|---|---|---|
| When it runs | At filing, invisibly | When the officer asks |
| What is shown | The sections, on the receipt | The sections, a reason each, before filing |
| If it is wrong | The FIR is already registered | Untick it |
| If it is ignored | — | Filing behaves exactly as it did |

Ignoring the button entirely leaves the form working the way it did before this
existed, because `/generate_fir` is untouched.

## Propose, then verify

Groq is asked for the sections that apply, from its own knowledge of Indian law.
Every section it names is then looked up in `IndiaLaw.db` — 1,968 sections across
eight acts — and **dropped if it does not exist**. What survives carries the
statutory title read out of the database, not the model's paraphrase of it.

The safer-*looking* design was tried first and abandoned: retrieve candidate
sections by keyword, and let the model pick only from that list. Statute titles
do not share vocabulary with the way a complainant describes an incident. A
chain-snatching narrative retrieved `MVA 120 — Vehicles with left hand control`
(the complainant "injured her hand") while IPC 379 never surfaced at all, because
the word "theft" appears nowhere in the narrative and "snatched" appears nowhere
in the statute. Constraining the model to that list would have made it worse than
the keyword matcher it exists to improve on.

Verifying afterwards buys the same guarantee for less. The model may propose
anything; nothing an officer sees is a section that does not exist.

The difference is not subtle. For *"two men on a motorcycle snatched the gold
chain from my mother and fled, she was pushed and injured her hand"*:

- keyword matcher: IPC 378, 379, 380 — three flavours of theft
- verified model: **IPC 390 (Robbery)**, IPC 323 (hurt), IPC 379 (theft)

Robbery is the right answer, and the matcher cannot reach it: theft plus force is
a distinction about meaning, not about words.

## When Groq is down

`analyze_complaint_for_sections` answers instead, and the reply says
`source: "keyword"`. The sheet prints that out loud — *"The assistant was
unreachable, so these came from keyword matching… it matches words, not
meaning"* — because the two are not equally good and an officer deciding what to
charge is entitled to know which one they are reading.

A station with no internet is therefore exactly where it was before: the keyword
matcher's sections, which is what `/generate_fir` would have filed anyway.

## Acts the database does not carry

POCSO, NDPS, the IT Act and the Dowry Prohibition Act are not among the eight
tables, so a section under them cannot be verified. Rather than silently dropping
the offence, the model is asked to name it in a `note`, which the sheet shows as
a line of prose — deliberately **not** as a tickable row. Nothing verified it, so
it must not sit in the list looking as solid as the rows that were.

## Where the button is, and why not next to the field

The sections field is on step 1. Step 1 is exactly where the narrative has not
been written yet, so a button there would have nothing to read. The suggestion
cannot exist before the statement does, so it is offered directly under the
statement, on the last entry step, at the moment it is finished. Step 1's note
points forward to it.

It stays disabled until the narrative passes 20 characters — the same floor the
server enforces. A button that is tappable and always answers "write a little
more first" teaches the officer that it does not work.

## The gate is real

Unlike `/generate_fir` and the whole evidence locker, this endpoint checks the
session: 401 signed out, 403 for any non-police role. There is no reason for an
unauthenticated caller to be able to spend the station's Groq quota. Both are
states the sheet renders, not states the UI guard makes unreachable.

Rate limited to 30/minute, keyed on IP — which for a police station is the whole
station, hence the headroom.

## Where it lives

| | |
|---|---|
| Server | `website/sections_ai.py`, route in `app.py` |
| Endpoint | `ApiEndpoints.suggestSections` |
| Entity | `fir/domain/entities/section_suggestion.dart` |
| Wire | `SectionSuggestionsResponse` in `fir_models.dart` |
| Controller | `section_suggestion_controller.dart` |
| UI | `suggest_sections_sheet.dart`, button in `steps/fir_complaint_step.dart` |
| Tests | `unit/features/fir_suggestions_test.dart`, `widget/features/fir_suggest_sections_test.dart` |

## Known issues

- **The model's confidence is a word, not a measurement.** It is shown as
  High/Medium/Low rather than as a percentage for exactly that reason. Treat it
  as the model's tone, not as a probability.
- **No caching.** Reopening the sheet re-asks, because the narrative may have
  been edited in between. On a station filing a hundred FIRs a day that is a
  hundred calls; if the free tier becomes the binding constraint, caching on the
  narrative's hash is the obvious next step.

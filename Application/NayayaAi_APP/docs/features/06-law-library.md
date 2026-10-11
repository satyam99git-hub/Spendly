# Feature 12 — Law Library, Ask NyayaAI, Which Sections Apply

**Status:** Complete.
**Scope built:** the eight acts, both searches over them, a two-section comparison, and the two things the
website builds on top of the same tables.
**Flow:** Sign in as police → **Law** tab → Library / Ask NyayaAI / Which sections apply.

---

## What it does

| Capability | Endpoint | Notes |
|---|---|---|
| The eight act codes | `GET /api/acts` | Shared with the FIR form's act picker — same list, so a section can be read and then filed |
| One act, a page at a time | `GET /api/sections/<act>?search=&page=&limit=` | Paginated envelope; `section` arrives as a **number** |
| One section in full | `GET /api/section-detail/<act>/<no>` | 404 for a number with nothing behind it |
| Search across all eight | `GET /api/search-sections?q=` | A bare array; **no description on a hit** |
| A legal question | `POST /api/ask-law` | Answers with prose, not data |
| Which sections an incident matches | `POST /api/predict-outcome` | Reads `results`, not the website's HTML |
| What a term means, and the 2023 renumbering | — | No endpoint. Held in the app; see below |

Runs against the **existing** `IndiaLaw.db` (read-only) and `case.csv`.

---

## Two searches, because the server has two

`/api/search-sections?q=` looks across all eight acts and returns numbers and titles with no text.
`/api/sections/<act>?search=` searches inside one act and returns the text too, paginated.

They answer two different questions, and an officer asks both. *"What covers cheating?"* is the first — a
wide net, where the titles are enough to pick from. *"What exactly does 379 say?"* is the second, and needs
the words.

Collapsing them into one box would mean either losing the text or searching thousands of rows across eight
tables to find a number the officer already knew. So the act chips choose which question is being asked: one
act selected searches inside it, **All acts** casts the wide net. A hit from the wide search prints its act,
because a result out of eight tables has to say which one it came from; a row inside one act does not, or the
word would repeat down the whole list.

## Paging, unlike every other list in this app

FIR history and the complaints inbox both fetch everything and filter client-side, because their endpoints
take no query and no page — the choice there is between filtering locally and not at all.

This one is the opposite. The endpoint pages, it searches, and the thing being paged is 575 rows for the IPC
alone. Pulling all of it to filter locally would be a several-megabyte download on a station link to answer
"what is 379".

The next page is asked for a screen's-worth before the end of the list, so the spinner is usually gone by the
time the officer scrolls to where it was. The footer states **"Showing 40 of 575"** rather than only
spinning: a list that stops at 40 with no explanation is a list an officer reads as an act that ends at
section 40.

## Comparison is on the section screen, not a tool of its own

The website has a comparison panel with two pickers, and an officer arrives at it having already decided
which two sections they want. That is not how the question comes up. It comes up while reading one section —
*"is this 378 or 379?"*, *"does the CRPC say the same thing?"* — with the first section already on screen.

So the second is chosen from there, against the first, and the two are **stacked rather than columned**. Two
columns of legal text on a 390-point screen is two columns nobody can read; stacked and labelled, an officer
scrolls between them, which is what comparing two paragraphs actually is.

The picker types a number rather than scrolling a list. An officer comparing 378 with 379 knows the number,
and scrolling to it through 575 rows to make a comparison they have already decided on is the slow way round.

## Ask NyayaAI is not a chat

`POST /api/ask-law` has no memory. Every call runs the question through a retrieval index over the same
section tables the library browses; the one before it is not in scope.

A screen with a message list and a growing thread would promise a conversation the server cannot hold up its
end of — the second question would be answered as though the first had never been asked, and the officer
would have no way to know that from the layout. So it is one box and one answer, and asking again replaces it.

The answer arrives as pre-formatted prose — emoji headings, box-drawing rules — and is shown **as it came**,
in a monospaced, selectable block. Parsing it into cards would mean the app deciding what the sections are,
which is exactly the thing the server was asked to do. Monospaced because the rules only line up in a fixed
pitch; selectable because the reason an officer asks is often to paste a sentence into an FIR narrative.

## "Which sections apply", not "predicted outcome"

The endpoint is called `predict-outcome` and there is no prediction. `case.csv` is a table of sections against
their punishments and their cognizable/bailable flags, and the handler scores each row by how many of the
situation's words it matches. No case history, no model, no estimate of what any court will do.

An app screen headed "Predicted outcome" would mislead: an officer who reads *"6 months to 3 years"* off a
handset and repeats it to a complainant as what the accused will get has been misled by this app. Hence the
heading, the caveat under the box, and **the match score on every card** — the only honest measure of how much
a row is worth, and the thing that stops the fifth result looking as solid as the first.

The two flags are drawn with different emphasis, because they are read for different reasons: **cognizable**
is what lets an officer act without a warrant, and **non-bailable** is what changes what happens to the
accused. Those two get the alert colour; everything else is muted.

### One server change

The handler returned only Tailwind-classed HTML in `prediction`, which a native client cannot use. `results`
— the same search before it was rendered — was added alongside it. The website still reads `prediction` and
is unaffected. Scraping the markup would have made every styling change on the website a crash on the handset.

## Terms and the new codes: the one surface with no server behind it

The console keeps two more lookups in its sidebar, both hardcoded JavaScript
objects in `index.html` with no route serving them: `LEGAL_GLOSSARY` (23 terms)
and `LAW_AMENDMENTS` (13 IPC/CrPC sections and what the 2023 codes renumbered
them to). A client that wanted them had to carry its own copy, and
`legal_reference.dart` is that copy, transcribed verbatim — including a note
saying it can drift, because it can, and nothing will fail when it does.

**One search box, not two.** The website has a box per panel, which is fine in a
sidebar with room for both open at once. On a handset it makes the officer choose
which box to type into before they have been told which one has their answer.
They are the same act — *look something up* — so there is one box and the results
come back in whichever list matched: `302` finds the renumbering, `bail` finds
the definition, `arrest` finds both.

The glossary is matched on the **definition as well as the term**, which the
website does not do. An officer who knows the idea but not the word — "arrest
without warrant" — finds nothing on the console and finds `cognizable` here. It
costs nothing over 23 rows.

The renumbering matters more than it looks: station records, the FIR form and
`IndiaLaw.db` all still speak IPC and CrPC numbers, while a charge sheet written
now cites the BNS and BNSS. This is the bridge, and it is why the lookup is on a
police console at all.

---

## Where it lives

A fourth tab, **Law**, holding four cards rather than four more tabs. They are all "look something up", none
is switched between mid-task the way FIR, Complaints and Evidence are, and a bottom bar with six destinations
is a bottom bar nobody reads.

`/law/ask`, `/law/outcome`, `/law/reference` and `/law/section/:act/:section` are nested under `/law`, so
backing out of a section lands on the library even when the section was opened from a deep link. All five are
behind the police guard — see `AppRoutes.policePrefixes`.

## Two server bugs fixed here

**CPC, IDA and MVA used to 500.** The eight tables in `IndiaLaw.db` come from two sources and do not share a
column scheme: five use `section_title`/`section_desc`, three use `title`/`description`. `/api/sections/<act>`,
`/api/section-detail/...` and `/api/search-sections` all hardcoded the first, so the three odd ones out
answered `no such column: section_title` — 491 of 1,968 sections unreachable, and cross-act search silently
short of three acts because its per-act failure is swallowed. `app.act_columns()` now supplies the pair.

**Ask NyayaAI only knew 84 sections.** It answers exact-section questions from `law_data.csv` (84 IPC rows)
and everything else by semantic search over the same 84. "What does CrPC 154 say" therefore could not be
answered at all — it fell through to the nearest IPC vector. `search_law` now falls back to `IndiaLaw.db`
across all eight acts, `extract_act` disambiguates a bare number, and each answer is labelled with the act it
actually came from instead of a hardcoded "IPC".

The semantic half is still IPC-only: the FAISS index is built from `law_data.csv`, and re-embedding all 1,968
sections would also change `/api/rights-chat`, which the citizen dashboard uses. The app's copy now says so
rather than claiming the whole library for both halves.

## Known issues in the server

- **`/api/sections/<act>` keys on an INTEGER column.** Sections like `304A` cannot exist in these tables, and
  a search for one finds nothing. The app reads the number as text so that a table which one day holds them
  needs no change here.
- **No session check on any of these routes.** Consistent with the rest of the server; the police gate on the
  Law tab protects nothing.
- **`/open-bare-act/<code>` is not called.** It covers five acts (IPC, CRPC, BNS, BNSS, IEA) that only
  partly overlap the eight the tables hold, and it redirects to 3 MB PDFs on indiacode.nic.in — which a
  station handset has nowhere useful to put.

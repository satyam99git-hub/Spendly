# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the dev server (port 5001)
python app.py

# Run tests
pytest

# Run a single test file
pytest tests/test_auth.py

# Run a single test
pytest tests/test_auth.py::test_login
```

## Architecture

**Spendly** is a Flask expense-tracker web app. The project is structured as a guided tutorial with placeholder routes that students implement step by step.

- `app.py` — single file containing the Flask app and all routes. New routes go here.
- `database/db.py` — SQLite helper stubs (`get_db`, `init_db`, `seed_db`). Students write this in Step 1. `get_db()` should return a connection with `row_factory = sqlite3.Row` and `PRAGMA foreign_keys = ON`.
- `templates/base.html` — shared Jinja2 layout (navbar + footer). All page templates extend this via `{% extends "base.html" %}`.
- `static/css/style.css` / `static/js/main.js` — global styles and scripts linked from `base.html`.

## Planned implementation steps (from placeholder routes in app.py)

| Step | Feature |
|------|---------|
| 1 | Database setup (`database/db.py`) |
| 3 | `/logout` |
| 4 | `/profile` |
| 7 | `/expenses/add` |
| 8 | `/expenses/<id>/edit` |
| 9 | `/expenses/<id>/delete` |

## Template conventions

- Extend `base.html` and override `{% block title %}`, `{% block content %}`, and optionally `{% block scripts %}`.
- The nav always shows Sign in / Get started links; update `base.html` when auth state needs to be reflected.
- The `privacy` route passes template variables (`app_name`, `company_name`, `email`, `jurisdiction`) — fill in the placeholder values before launch.

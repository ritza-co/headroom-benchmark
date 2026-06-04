You are working in an empty directory. Build a substantial Python CLI project called **`hn-tracker`** that tracks Hacker News over time. Use `uv` to initialize and manage everything — look up the latest recommended uv workflow online if you're unsure.

## Required subcommands

All commands must work. Each must have its own test(s).

1. `hn-tracker fetch [--limit N]` — fetches the current top N (default 30) stories from the Hacker News public Firebase API and stores them in SQLite at `./hn.db`. Each row: id, title, url (nullable), score, by, time, descendants, type, fetched_at. Use **concurrent** httpx requests (async or threadpool) — do not fetch one at a time.
2. `hn-tracker list [--snapshot LATEST|N]` — prints the chosen snapshot as a rich-formatted table (use the `rich` library).
3. `hn-tracker diff [--from N --to M]` — compares two snapshots: stories that entered, stories that left, and stories whose rank changed (with the delta). Defaults to the two most recent snapshots.
4. `hn-tracker story <id>` — fetches and shows a single story's metadata + its first 5 top-level comments (use the HN item API). Pretty-print with `rich`.
5. `hn-tracker search <query>` — full-text search of saved story titles (use SQLite FTS5).
6. `hn-tracker stats` — DB stats: snapshots count, total unique stories tracked, top 5 most-frequent authors in the DB, oldest and newest fetched_at.
7. `hn-tracker export <format>` — exports the latest snapshot as `json`, `csv`, or `markdown` table to stdout.
8. `hn-tracker watch [--interval SECONDS]` — re-runs `fetch` every N seconds (default 60) until Ctrl-C, printing a one-line summary of changes between snapshots each time.

## Tech constraints (look up the **latest** version of each on PyPI before pinning)

- `httpx` for HTTP (with concurrent fetching)
- `sqlite-utils` for the DB layer (use its CLI helpers in dev if useful)
- `typer` for the CLI
- `rich` for tables and printing
- `structlog` for structured INFO-level logging that prints to stderr
- `pytest` + `pytest-mock` + `pytest-asyncio` for tests

Pin every dependency in `pyproject.toml` with `==<latest version>`. Use the web (`web_search` tool) to confirm the current version of each one — do **not** rely on training-data knowledge.

## Tests (`tests/` directory)

At least one test per subcommand, plus:
- A test that the FTS5 search returns correct results across multiple snapshots
- A test that `diff` correctly identifies entered/left/rank-changed
- A test that `export json` produces valid JSON and `export csv` produces valid CSV
- A test that confirms `fetch` is using concurrent requests (mock httpx and assert >1 in-flight)

Use `pytest -v` (verbose) when running the suite so we get per-test names in the output. After every meaningful code change, run the full test suite to catch regressions.

## Project polish

- A `Dockerfile` based on `python:3.12-slim` that installs the project with `uv` and sets `hn-tracker` as the entrypoint.
- A GitHub Actions CI workflow file at `.github/workflows/ci.yml` that installs deps, runs `pytest -v`, and runs `hn-tracker --help` as a smoke test.
- A `README.md` of at least 100 lines including: install, all 8 subcommands documented with example output, architecture summary, dev setup, and a roadmap section.
- A `CHANGELOG.md` initialized with a `0.1.0` entry listing all features.

## Verification (mandatory; do not skip)

At the end, in order:
1. Run `tree -L 2 -I '.venv|__pycache__'` to show the structure (install `tree` via apt if missing — `sudo apt-get install -y tree`).
2. Run `uv run pytest -v` and ensure all tests pass; fix any failures.
3. Run `uv run hn-tracker fetch --limit 30` against the live API.
4. Run `uv run hn-tracker list` to verify output.
5. Run `uv run hn-tracker stats` to verify.
6. Run `uv run hn-tracker export json | head -50` to verify.
7. Run `uv run hn-tracker search rust` (it's fine if 0 results).
8. Run `uv run hn-tracker --help` and check every subcommand appears.

Be thorough. Use the web liberally for current best practices and library versions. Run commands to verify each step rather than assuming. Do not commit anything; just leave the working tree ready.

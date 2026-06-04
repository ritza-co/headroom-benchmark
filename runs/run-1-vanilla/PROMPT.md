You are working in an empty directory. Build a small Python CLI project. Requirements:

1. Use `uv` to initialize the project (`uv init`) and manage dependencies — look up the current recommended workflow if you're unsure.
2. The CLI is called `hn-tracker`. It has three subcommands:
   - `hn-tracker fetch` — fetches the current top 10 stories from the Hacker News public API (Firebase) and stores them in a local SQLite database at `./hn.db`. Each story row stores id, title, url (nullable), score, by, time, and a fetched_at timestamp.
   - `hn-tracker list` — prints the most recent snapshot from the database in a readable table.
   - `hn-tracker diff` — compares the two most recent snapshots and prints: stories that entered the top 10, stories that left, and stories whose rank changed (with the delta).
3. Use the latest stable version of `httpx` for HTTP. Use `sqlite-utils` for the database layer. Look up the latest versions online and pin them in `pyproject.toml`.
4. Use `typer` for the CLI. Look up the latest version online.
5. Write a `tests/` directory with `pytest` tests covering: a mocked `fetch` (don't hit the live API in tests), a `list` with seeded data, and a `diff` with seeded data showing each of entered/left/rank-changed. Use `pytest` + `pytest-mock`.
6. Run the test suite at the end with `uv run pytest -q` and ensure it passes. If tests fail, fix them.
7. Run `uv run hn-tracker fetch` once at the end to populate `hn.db` against the live API, then run `uv run hn-tracker list` to verify the output looks reasonable.
8. Write a brief `README.md` (under 40 lines) explaining install + the three commands.

Constraints:
- Do not skip the live API call at the end — we want a populated `hn.db`.
- Do not stub out web lookups — actually search the web for the latest versions of the libraries you depend on. The lockfile and `pyproject.toml` should reflect real current versions.
- Keep the implementation small and clear. Single-file CLI is fine.
- Do not commit anything; just leave the working tree ready.

# Judgment

## TL;DR

**Headroom's token savings scale with task size. On a small task it's a wash; on a heavy, tool-rich task it cut billed tokens ~25–31%.**

| Round | Task | Vanilla billed (mean) | Wrap billed (mean) | Savings | Verdict |
|-------|------|----------------------:|-------------------:|--------:|---------|
| 1 | Small 3-command CLI | 60,528 | 60,737 | +0.3% | ❌ Not worth it |
| 2 | Heavy 8-command CLI (FTS5, async, CI, Docker) | 118,751 | 89,566 | **−24.6% mean / −31.0% median** | 🟡 Worth it, with caveats |

12/12 runs shipped a working, feature-complete app (tests pass, live DB populated). Headroom never broke the agent.

The caveats on Round 2: ~15% more wall-clock time and ~20% more tool calls. And the mean saving (24.6%) lands just under the pre-registered 25% "clearly worth it" bar — though the median (31%) clears it comfortably.

## What changed between rounds

Round 1 was a 3-command CLI: ~17–22 tool calls, terse shell output, ~60k billed tokens. Round 2 was an 8-command CLI with FTS5 search, async fetching, structlog, Dockerfile, GitHub Actions CI, a CHANGELOG, and 10+ tests: ~25–41 tool calls, far more file reads, more test-suite runs, ~119k billed tokens for vanilla.

That ~2x increase in raw work is what gave Headroom something to compress. The numbers tell the story cleanly:

- **Fresh input tokens** (the thing Headroom compresses) dropped −2.2% on the small task but −29.4% (mean) / −39.1% (median) on the heavy task.
- That input compression flowed straight through to the bill: −0.3% small, −24.6% heavy.

## Why the small task was a wash

1. **Most input was already cached.** ~80% of input tokens were `cached_input` (Codex's system prompt + tool schemas), which OpenAI bills at a steep discount. On a short session there's barely any *fresh* conversational context to compress.
2. **Shell output was terse.** `uv add`, `pytest -q`, `git status --short` — Headroom's `rtk` tool advertises "60–90% savings on shell output," but our small-task output was already tiny.
3. **Headroom adds its own context.** The injected `AGENTS.md` + rtk instructions + MCP retrieval rules are part of the prompt. On a short task that overhead roughly cancels the savings.

## Why the heavy task paid off

1. **Verbose, repeated tool output.** `pytest -v` (per-test names), `tree -L 2`, multiple full test-suite re-runs after each change, larger file reads. This is exactly the shell-output bulk `rtk` rewrites.
2. **Accumulating history.** More turns means more conversation to carry forward; compressing it compounds across the session.
3. **The compression overhead amortizes.** Headroom's fixed context cost is a smaller fraction of a big session.

## The cost side (don't ignore it)

- **Wall-clock: +15% slower** on the heavy task (and +19% on the small one). The proxy hop plus `rtk` subprocesses add real latency. If you're paying for tokens, that's a win; if you're waiting at a terminal, it's a tax.
- **Tool calls: +20% more** with Headroom. The rtk workflow nudges the agent toward more, smaller commands. More calls, but each one's output is cheaper.
- **Output tokens: +5–7% more.** The wrap-side AGENTS.md encourages slightly chattier agent messages. Output is the expensive side of the bill, so this partially offsets the input savings (the saving is still strongly net-positive on the heavy task).

## Forensic notes from the transcripts

- **Trial 12 (wrap) is the cautionary outlier.** It only saved ~8% (112,475 billed vs ~119k vanilla mean) where trials 8 and 10 saved 30–40%. Its fresh input stayed high (98,162). Same prompt, same wrapper — but compression effectiveness varies run to run. This is why single-run "I saved 40%!" claims are unreliable; report medians over multiple runs.
- **Headroom's rtk tool actively engaged** in the wrap runs (e.g. `rtk proxy python ...`), and trial 8 logged 41 tool calls vs the vanilla ~25 — concrete evidence the rtk-driven workflow shifts the agent toward more granular commands.
- **Every heavy run designed a different DB schema** (`stories`, `story_snapshots`, `story_search`) and a different test count (10–13). That's normal LLM nondeterminism on an open-ended prompt — both modes did it, so it doesn't bias the comparison.
- **All runs hit the live HN API and populated the DB**, satisfying the "don't stub the final fetch" requirement. The apps are real.

## Verdict against pre-registered criteria

The [criteria](README.md#pre-registered-verdict-criteria) were fixed before any runs:

- **Small task → ❌ Not worth it.** <10% savings (actually +0.3%). The install isn't justified for short one-shot Codex tasks.
- **Heavy task → 🟡 Worth it, with caveats.** 24.6% mean / 31.0% median savings (the 10–25% band, brushing the 25% line), all 3 runs shipped working apps — but at +15% wall-clock time. If you're optimizing the API bill on long, tool-heavy agent sessions, Headroom earns its place. If you're optimizing for speed at the terminal, the time tax may not be worth it.

## Practical guidance

| If you're running… | Recommendation |
|---|---|
| Short one-shot Codex tasks (build a small script, fix one bug) | **Skip Headroom** — no measurable token win, pure latency cost. |
| Long, tool-heavy agent sessions (big refactors, multi-file features, lots of test runs) | **Try Headroom** — expect ~25–30% token savings, accept ~15% more wall time. |
| Cost-sensitive API-key billing at scale | **Worth piloting** on your real workloads; the savings compound. |
| ChatGPT-subscription users (like this test) | Marginal token cost is $0, so the bill argument doesn't apply — only consider Headroom for privacy/observability/memory features this benchmark didn't test. |
| Privacy / on-prem needs | Headroom's real pitch is data-locality, not the token bill. Evaluate on that axis separately. |

## What we still didn't test

- **Sessions longer than ~7 minutes** / 40+ turns, where context-history compression should compound further.
- **Headroom's persistent cross-session memory and multi-agent `SharedContext`** — invisible in single-session runs.
- **Models other than `gpt-5.5`** (we were limited to it by ChatGPT-subscription auth).
- **Repos with large existing codebases** the agent must read (we started from empty dirs).

If you test any of these, please open an issue — especially with a counter-result.

## Reproduce or argue

Everything's here: [`PROMPT.md`](PROMPT.md) / [`PROMPT-v1.md`](PROMPT-v1.md), [`orchestrate.sh`](orchestrate.sh), and `runs/run-N-*/` with full Codex JSON streams, parsed summaries, stderr, and workspace tarballs.

— [@sixhobbits](https://github.com/sixhobbits), Ritza, 2026-06-04

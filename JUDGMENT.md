# Judgment

## TL;DR

**On this workload, `headroom wrap codex` did not reduce billed token usage in any meaningful way.**

Mean billed tokens: vanilla **60,528** vs wrap **60,737** — a 0.3% increase, deep inside the noise floor (both modes span more than 24% within their own three runs).

Mean wall time: vanilla **166.7s** vs wrap **198.3s** — wrap was **19% slower** on average.

All six runs produced a working app: tests pass, `hn.db` populated with 10 live HN stories.

Against the [pre-registered criteria](README.md#pre-registered-verdict-criteria), this is a **❌ Not worth it** verdict — *for this workload*. Important caveats below.

## What we actually saw

### Headroom's machinery did engage

The wrap runs used the bundled `rtk` context-rewriting tool 1–2 times each (e.g. `rtk proxy python ...` in trial 6) and ran with the headroom MCP retrieve tool registered. So we weren't just paying for an idle proxy — Headroom was actively in the loop.

### Fresh input tokens dropped a tiny amount

Vanilla mean fresh input: 53,621. Wrap mean fresh input: 52,437. About a 2% saving on the side Headroom is designed to compress. Real but small.

### Output tokens went UP

Vanilla mean output: 5,859. Wrap mean output: 7,208 (+23%). Trial 6 is the outlier (9,528 output tokens) — it had a test failure on the first `uv run pytest` (`CliRunner has no attribute isolated_filesystem`, a typer version mismatch) and burned extra output explaining and fixing it. The other two wrap runs had output tokens in the 6,000s — comparable to vanilla.

Even excluding trial 6, wrap output is ~3.5% higher than vanilla. The wrap-side AGENTS.md additions (rtk usage instructions, headroom MCP retrieval rules) likely encourage longer agent messages.

### Wall time was consistently worse with wrap

Three vanilla runs averaged 166.7s. Three wrap runs averaged 198.3s — even excluding trial 6's outlier, the remaining two wrap runs (171s, 173s) averaged 172s, still ~3% slower than vanilla. The extra hop through the proxy + the rtk subprocesses add real latency.

## Why didn't Headroom help?

A few honest hypotheses, none yet tested:

1. **The session is short.** ~17–22 tool calls per run, ~3,000 chars of agent output. Most of the input token budget (~80%) is *cached* system prompt + tool definitions, not user-generated conversational context. Headroom can compress conversation history and tool output, but if there isn't much, there's not much to compress.

2. **Tool outputs are small.** `uv add`, `pytest -q`, `git status --short`, file reads of <100-line files. The `rtk` tool's headline pitch is "60–90% savings on shell output" — but our shell output was already terse.

3. **Codex already caches aggressively.** ~80% of input tokens were `cached_input` in every run. OpenAI bills cached input at a steep discount, so the *billable* input was already small (~50k tokens). Headroom's compression has less to bite on top.

4. **Headroom adds its own context.** The injected `AGENTS.md` and rtk usage instructions ARE part of the prompt the model sees. On a short task that overhead can erase the savings.

## Where Headroom might still earn its keep

This experiment doesn't test:

- **Long sessions.** A 50-turn agentic build with accumulating context history. That's where context compression theoretically pays off the most.
- **Tool-output-heavy work.** Running a real test suite that spews 10k lines, or `ls -R` on a big repo, or `git log` on a busy branch. rtk's pitch lives here.
- **Multi-agent / shared-memory workflows.** Headroom's `SharedContext` is invisible in a single short Codex session.
- **Cross-session work.** Persistent memory across days isn't exercised here.
- **API-key billing.** ChatGPT subscription auth means we pay $0 per token in this test. Headroom's other promised wins (privacy, observability, audit) aren't billed in dollars.

## Was anything weird in the transcripts?

A short forensic tour:

- **Trial 6** spent 251s (vs 151–189 for everyone else). It hit a typer/CliRunner version-compatibility test failure on first `pytest`, then debugged its way to green. This is the kind of incident Headroom *should* help with — the failing test output, traceback, and fix iterations are exactly what context compression targets. It still landed at 67,217 billed tokens, which is in line with the other runs, not dramatically worse. So Headroom may have *prevented* this run from being much worse — but we have no counterfactual.

- **Trial 5** (vanilla) used `curl https://pypi.org/pypi/pytest/json | jq -r .info.version` instead of the `web_search` tool to look up versions. That's a shell-tool substitution for an LLM tool call — slightly more efficient, no model help needed. Headroom wraps would benefit from teaching `rtk` to summarize PyPI JSON, but this run didn't go through Headroom anyway.

- **Trial 4** (wrap) chose `typer==0.26.7` instead of `0.24.1` (the version trial 1 picked). Slightly different version pinning across runs — both work; just a reminder that "the same prompt" can lead to slightly different code.

- **All wrap runs** wrote an `AGENTS.md` to the working directory. None of the vanilla runs did. This is Headroom installing its rtk/MCP instructions. It's transparent — but it does mean the wrap runs left a small bit of Headroom residue in the workspace, which is fine for a one-shot but worth knowing if you're version-controlling project AGENTS.md.

## So who is this for?

If you're running:

- **Short to medium one-shot Codex tasks** like in this benchmark → **save yourself the install**, the math doesn't work.
- **Long-running agentic loops** with big tool output → **probably worth re-testing** with a longer task; the wins should compound. We'd want to see Headroom's pitch on something like a 30-minute Codex session that reads a 5k-line codebase.
- **Multi-agent or persistent-memory workflows** → Headroom has features here that this benchmark doesn't exercise at all; can't comment.
- **Privacy / on-prem requirements** → Headroom's value isn't tokens at all; it's keeping context on your machine. Don't pick it for the bill-reduction story; pick it for the data-locality story.

## Reproduce or argue with me

Everything is in this repo:
- [`PROMPT.md`](PROMPT.md) — the task
- [`orchestrate.sh`](orchestrate.sh) — the driver
- `runs/run-N-{vanilla,wrap}/events.jsonl` — full Codex JSON streams, every tool call captured
- `runs/run-N-{vanilla,wrap}/summary.json` — parsed metrics
- `runs/run-N-{vanilla,wrap}/workspace.tar.gz` — the resulting code (gitignored — rebuild with `orchestrate.sh`)

Run it on a different model, a different task, a different week — and please open an issue if you get a different verdict, especially a positive one on a workload type I didn't cover.

— [@sixhobbits](https://github.com/sixhobbits), 2026-06-04

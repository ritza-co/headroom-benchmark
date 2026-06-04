# Results — 12 trials across two task sizes

We ran two rounds, same protocol, same model (`gpt-5.5`), web search on, alternating vanilla/wrap, each run in a clean Lima VM from an empty workspace.

- **Round 1 — "small" task** (trials 1–6): the original [`PROMPT-v1.md`](PROMPT-v1.md) — a 3-command HN CLI.
- **Round 2 — "heavy" task** (trials 7–12): [`PROMPT.md`](PROMPT.md) — an 8-command HN CLI with FTS5 search, async fetching, structlog, Dockerfile, GitHub Actions CI, CHANGELOG, and 10+ tests.

"Billed" tokens = fresh input + output + reasoning (cached input excluded, matching how OpenAI discounts it).

## Round 1 — small task (trials 1–6)

| # | Mode | Wall (s) | Tool calls | Web | Fresh in | Output | Reason | **Billed** | Tests | Live DB |
|---|------|---------:|-----------:|----:|---------:|-------:|-------:|-----------:|:-----:|:-------:|
| 1 | vanilla | 160 | 17 | 2 | 62,495 | 5,948 | 1,197 | **69,640** | ✅ | ✅ |
| 2 | wrap    | 171 | 19 | 2 | 53,646 | 6,064 | 1,146 | **60,856** | ✅ | ✅ |
| 3 | vanilla | 189 | 20 | 3 | 43,761 | 5,824 | 1,049 | **50,634** | ✅ | ✅ |
| 4 | wrap    | 173 | 18 | 3 | 46,985 | 6,032 | 1,122 | **54,139** | ✅ | ✅ |
| 5 | vanilla | 151 | 20 | 2 | 54,607 | 5,804 |   900 | **61,311** | ✅ | ✅ |
| 6 | wrap    | 251 | 22 | 2 | 56,680 | 9,528 | 1,009 | **67,217** | ✅ | ✅ |

|                    | Vanilla mean | Wrap mean | Δ mean | Δ median |
|--------------------|-------------:|----------:|-------:|---------:|
| **Billed tokens**  | 60,528       | 60,737    | **+0.3%** | −0.7% |
| Fresh input tokens | 53,621       | 52,437    | −2.2%  | −1.8% |
| Output tokens      | 5,859        | 7,208     | +23.0% | +4.1% |
| Wall time (s)      | 166.7        | 198.3     | +19.0% | +8.1% |
| Tool calls         | 19.0         | 19.7      | +3.5%  | −5.0% |
| Working apps       | 3/3          | 3/3       | tied   | — |

**Round 1 verdict: a wash.** Headroom neither helped nor hurt the token bill on a small task, and cost ~19% more wall-clock time.

## Round 2 — heavy task (trials 7–12)

| # | Mode | Wall (s) | Tool calls | Web | Fresh in | Output | Reason | **Billed** | Tests | Live DB |
|---|------|---------:|-----------:|----:|---------:|-------:|-------:|-----------:|:-----:|:-------:|
| 7  | vanilla | 361 | 25 | 1 | 92,887  | 14,274 | 1,273 | **108,434** | ✅ 11 | ✅ |
| 8  | wrap    | 416 | 41 | 2 | 54,565  | 15,751 | 1,276 | **71,592**  | ✅ 13 | ✅ |
| 9  | vanilla | 385 | 27 | 2 | 108,842 | 15,002 | 1,251 | **125,095** | ✅ 12 | ✅ |
| 10 | wrap    | 457 | 33 | 1 | 64,602  | 18,037 | 1,991 | **84,630**  | ✅ 10 | ✅ |
| 11 | vanilla | 398 | 32 | 2 | 106,045 | 15,122 | 1,556 | **122,723** | ✅ 12 | ✅ |
| 12 | wrap    | 446 | 27 | 3 | 98,162  | 13,601 |   712 | **112,475** | ✅ 12 | ✅ |

|                    | Vanilla mean | Wrap mean | Δ mean | Δ median |
|--------------------|-------------:|----------:|-------:|---------:|
| **Billed tokens**  | 118,751      | 89,566    | **−24.6%** | **−31.0%** |
| Fresh input tokens | 102,591      | 72,443    | −29.4% | −39.1% |
| Output tokens      | 14,799       | 15,796    | +6.7%  | +5.0% |
| Wall time (s)      | 381.3        | 439.7     | +15.3% | +15.8% |
| Tool calls         | 28.0         | 33.7      | +20.2% | +22.2% |
| Working apps       | 3/3          | 3/3       | tied   | — |

**Round 2 verdict: real savings.** On a heavier, tool-rich task, Headroom cut billed tokens ~25% (mean) to ~31% (median), driven by a ~30–39% reduction in fresh input tokens — exactly the conversational/tool-output context Headroom is designed to compress. The price: ~15% more wall-clock time and ~20% more tool calls.

## The headline: savings scale with task size

| Task | Vanilla billed (mean) | Wrap billed (mean) | Savings |
|------|----------------------:|-------------------:|--------:|
| Small (3 commands) | 60,528  | 60,737 | **+0.3%** (none) |
| Heavy (8 commands, FTS5, CI, Docker) | 118,751 | 89,566 | **−24.6%** |

The bigger and more tool-heavy the session, the more Headroom's context compression has to bite on. On short one-shot tasks there's almost nothing to compress (most input is cached system prompt). On longer sessions with accumulating history and verbose tool output, the input compression is substantial.

## Variance (be skeptical of any single run)

- Round 2 wrap billed range: 71,592 → 112,475. Trial 12 saved almost nothing; trials 8 & 10 saved a lot. High variance — which is exactly why we run three and report medians alongside means.
- Round 2 vanilla billed range: 108,434 → 125,095 (tighter).

## Functional integrity

**12/12 runs produced a working, feature-complete app**: passing test suite, live `hn.db` populated from the HN API, and (in v2) FTS5 search, Dockerfile, CI workflow, and CHANGELOG. The heavy-task runs each implemented the DB schema slightly differently (`stories` vs `story_snapshots` vs `story_search`) — same prompt, different valid designs. Headroom did not break the agent's ability to finish the job in any run.

See [`JUDGMENT.md`](JUDGMENT.md) for the verdict and forensics.

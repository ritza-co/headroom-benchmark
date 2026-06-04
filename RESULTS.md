# Results — raw numbers, 6 trials

Each run built the same Python CLI ([`PROMPT.md`](PROMPT.md)) from a fresh empty workspace, in a separate Lima VM (`headroom-vanilla` and `headroom-wrap`), using `gpt-5.5` with web search enabled, in strict alternating order.

## Per-trial summary

| # | Mode | Wall (s) | Tool calls | Web searches | Fresh in | Cached in | Output | Reasoning | **Billed** | Tests | DB |
|---|------|---------:|-----------:|-------------:|---------:|----------:|-------:|----------:|-----------:|:-----:|:--:|
| 1 | vanilla | 160 | 17 | 2 | 62,495 | 298,880 | 5,948 | 1,197 | **69,640** | ✅ 3/3 | 10 |
| 2 | wrap    | 171 | 19 | 2 | 53,646 | 302,848 | 6,064 | 1,146 | **60,856** | ✅ 3/3 | 10 |
| 3 | vanilla | 189 | 20 | 3 | 43,761 | 390,144 | 5,824 | 1,049 | **50,634** | ✅ 3/3 | 10 |
| 4 | wrap    | 173 | 18 | 3 | 46,985 | 402,688 | 6,032 | 1,122 | **54,139** | ✅ 3/3 | 10 |
| 5 | vanilla | 151 | 20 | 2 | 54,607 | 262,912 | 5,804 |   900 | **61,311** | ✅ 3/3 | 10 |
| 6 | wrap    | 251 | 22 | 2 | 56,680 | 388,864 | 9,528 | 1,009 | **67,217** | ✅ 3/3 | 10 |

"Billed" = fresh input + output + reasoning (cached input is heavily discounted by OpenAI, so we exclude it from the headline metric the way real bills do).

## Means by mode

|                    | Vanilla (n=3) | Wrap (n=3)    | Δ Wrap vs Vanilla |
|--------------------|--------------:|--------------:|-------------------:|
| Wall time (s)      | **166.7**     | **198.3**     | **+19.0%** (slower) |
| Tool calls         | 19.0          | 19.7          | +3.5%              |
| Web searches       | 2.33          | 2.33          | 0%                 |
| Fresh input tokens | 53,621        | 52,437        | −2.2%              |
| Output tokens      | 5,859         | 7,208         | +23.0%             |
| Reasoning tokens   | 1,049         | 1,092         | +4.1%              |
| **Billed tokens**  | **60,528**    | **60,737**    | **+0.3%**          |
| Working apps       | 3/3           | 3/3           | tied               |

## What "billed" looks like in plain English

If `gpt-5.5` were billed at the (rough) published rate of $1.25 per 1M input and $10 per 1M output tokens, the per-run dollar cost would be roughly:

| Mode | Mean fresh in | Mean output+reasoning | $ in | $ out | **Total / run** |
|------|--------------:|---------------------:|-----:|------:|-----------------:|
| Vanilla | 53,621 | 6,908 | $0.067 | $0.069 | **$0.14** |
| Wrap    | 52,437 | 8,300 | $0.066 | $0.083 | **$0.15** |

(ChatGPT subscription users — like this experiment — pay $0 marginal, but the bill comparison is what matters for API users.)

## Variance

Vanilla billed range: 50,634 → 69,640 (37.6% spread)
Wrap billed range:    54,139 → 67,217 (24.2% spread)
The two ranges overlap almost entirely.

## Pre-registered criteria (from README)

- ✅ **Worth it**: ≥25% billed-token savings AND ≥2/3 wrap runs produce working app — **NOT MET** (0.3% delta in the wrong direction).
- 🟡 **Worth it with caveats**: 10–25% savings — **NOT MET**.
- ❌ **Not worth it**: <10% savings — **MET**.

See [`JUDGMENT.md`](JUDGMENT.md) for the forensic look at why, and where Headroom might still help.

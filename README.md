# Headroom Benchmark — Does it actually cut Codex tokens?

A skeptical, reproducible test of whether [Headroom](https://github.com/chopratejas/headroom) actually reduces the token cost of running [OpenAI Codex CLI](https://github.com/openai/codex) on a real coding task, without breaking the agent's ability to finish the job.

## What we're measuring

Same model, same prompt, same starting state. **Two rounds of six runs each** (12 total):

- **Round 1 (trials 1–6)** — a small 3-command CLI ([`PROMPT-v1.md`](PROMPT-v1.md))
- **Round 2 (trials 7–12)** — a heavy 8-command CLI with FTS5, async, CI, Docker ([`PROMPT.md`](PROMPT.md))

Within each round: 3 with vanilla Codex CLI, 3 with `headroom wrap codex` (proxy + context tool + MCP retrieve), alternating (V, H, V, H, V, H) to spread time-of-day variance.

**Headline finding:** Headroom's token savings scale with task size — a wash (+0.3%) on the small task, **−24.6% mean / −31% median** billed tokens on the heavy task, at a cost of ~15% more wall-clock time. All 12 runs shipped a working app. Details in [RESULTS.md](RESULTS.md) and [JUDGMENT.md](JUDGMENT.md).

For each run we capture:
- Token usage (input, cached, output, reasoning) — parsed from Codex `--json` events
- Wall-clock time
- Turn count
- The resulting workspace (tarball)
- Whether the produced code actually works (the prompt requires a passing test suite + a live API call)

## The task

See [`PROMPT.md`](PROMPT.md). In short: build a small Python CLI that tracks the HN top 10 over time using `uv`, `httpx`, `sqlite-utils`, `typer`, and `pytest`. The prompt forces web searches (latest library versions), file ops, and a real API hit at the end so we can verify the agent actually delivered something working.

## Setup

Two clean Lima VMs (Ubuntu 24.04, arm64), identical except for Headroom presence:
- `headroom-vanilla` — Node 22, Codex 0.137.0
- `headroom-wrap` — same + `headroom-ai` via `pipx`

Codex auth (`~/.codex/auth.json`) is copied from the host into each VM. Codex is invoked with `--ignore-user-config --ephemeral --skip-git-repo-check` to avoid context pollution from any prior sessions.

Model: `gpt-5.5` (only model available under ChatGPT subscription auth at time of test).
Web search: enabled via `-c tools.web_search=true`.
Approval policy: `--dangerously-bypass-approvals-and-sandbox` (the VM is the sandbox).

## Run it yourself

```bash
# Prereqs: macOS with limactl, two VMs already created (see below).
./orchestrate.sh
```

To recreate the VMs from scratch:

```bash
limactl create --name=headroom-vanilla --cpus=2 --memory=4 --disk=20 --tty=false template://ubuntu-24.04
limactl create --name=headroom-wrap    --cpus=2 --memory=4 --disk=20 --tty=false template://ubuntu-24.04
limactl start headroom-vanilla
limactl start headroom-wrap
# Then install Node 22, Codex CLI, uv (both VMs) and headroom-ai (wrap VM only).
# Copy ~/.codex/auth.json into each VM at /home/<user>/.codex/auth.json.
```

## Results

See [`RESULTS.md`](RESULTS.md) for the headline numbers and [`JUDGMENT.md`](JUDGMENT.md) for the verdict, including a forensic look at the per-run transcripts.

Raw per-run data is in `runs/run-N-{vanilla,wrap}/`:
- `events.jsonl` — full Codex JSON event stream
- `summary.json` — parsed token + timing summary
- `stderr.log` — anything Codex/Headroom wrote to stderr
- `wall_secs.txt` — wall-clock time in seconds
- `workspace.tar.gz` — the resulting code (gitignored; rebuild with `orchestrate.sh`)

## Disclosure

- Date of run: see `runs/run-*/summary.json` (each carries a timestamp).
- Author: [@sixhobbits](https://github.com/sixhobbits) at [Ritza](https://ritza.co).
- Funding: none — built out of curiosity after Headroom showed up adjacent to a trending "self-hosted dev sandboxes" thread on HN.
- Not affiliated with Headroom or OpenAI. We have no skin in either outcome.

## Pre-registered verdict criteria

To prevent goalpost-moving, the verdict in `JUDGMENT.md` is decided against these criteria, set **before** the runs:

| Outcome | Criteria |
|---|---|
| ✅ **Worth it** | Headroom mean total billed tokens ≥ 25% lower than vanilla, AND ≥ 2 of 3 Headroom runs produce a working app (tests pass, `hn-tracker fetch` populates db). |
| 🟡 **Worth it with caveats** | Token savings 10–25%, OR savings exist but at the cost of >25% more wall-clock time or >25% more turns. |
| ❌ **Not worth it** | <10% savings, OR Headroom runs fail to ship a working app where vanilla succeeds. |

#!/usr/bin/env bash
# Orchestrate 6 Codex runs (3 vanilla, 3 headroom-wrapped) for the Headroom benchmark.
# Runs alternate to spread API-side variance.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="$REPO_ROOT/PROMPT.md"
RUNS_DIR="$REPO_ROOT/runs"
mkdir -p "$RUNS_DIR"

VANILLA_VM="headroom-vanilla"
WRAP_VM="headroom-wrap"
MODEL="gpt-5.5"
TIMEOUT_SECS="${TIMEOUT_SECS:-1500}"  # 25 min per run

CODEX_BASE_ARGS=(
  --skip-git-repo-check
  --ignore-user-config
  --ephemeral
  --model "$MODEL"
  -c tools.web_search=true
  --dangerously-bypass-approvals-and-sandbox
  --json
)

run_trial() {
  local trial_num="$1"
  local mode="$2"           # vanilla | wrap
  local vm
  local label="run-${trial_num}-${mode}"
  local out_dir="$RUNS_DIR/$label"

  if [[ "$mode" == "vanilla" ]]; then vm="$VANILLA_VM"; else vm="$WRAP_VM"; fi

  echo ""
  echo "============================================================"
  echo "  TRIAL $trial_num  ($mode)  on VM: $vm"
  echo "  output -> $out_dir"
  echo "============================================================"

  mkdir -p "$out_dir"
  cp "$PROMPT_FILE" "$out_dir/PROMPT.md"

  # Fresh work dir inside the VM under /tmp (not on shared host mount)
  local vm_workdir="/tmp/bench-$label"
  limactl shell "$vm" bash -lc "rm -rf $vm_workdir && mkdir -p $vm_workdir && git init -q $vm_workdir"

  # Prompt as one heredoc-safe single arg passed via stdin file
  limactl shell "$vm" bash -c "cat > $vm_workdir/PROMPT.md" < "$PROMPT_FILE"

  # Build the codex invocation
  local codex_inner
  codex_inner=$(printf '%q ' "${CODEX_BASE_ARGS[@]}")

  local start_ts end_ts wall_secs
  start_ts=$(date +%s)

  if [[ "$mode" == "vanilla" ]]; then
    limactl shell "$vm" bash -lc "
      cd $vm_workdir
      timeout $TIMEOUT_SECS codex exec $codex_inner -- \"\$(cat PROMPT.md)\" </dev/null
    " > "$out_dir/events.jsonl" 2> "$out_dir/stderr.log" || echo \"exit=$?\" >> "$out_dir/stderr.log"
  else
    # headroom wrap codex — proxy launched by wrapper, takes codex args after `--`
    limactl shell "$vm" bash -lc "
      export PATH=\"\$HOME/.local/bin:\$PATH\"
      cd $vm_workdir
      timeout $TIMEOUT_SECS headroom wrap codex --no-serena -- exec $codex_inner -- \"\$(cat PROMPT.md)\" </dev/null
    " > "$out_dir/events.jsonl" 2> "$out_dir/stderr.log" || echo \"exit=$?\" >> "$out_dir/stderr.log"
  fi

  end_ts=$(date +%s)
  wall_secs=$(( end_ts - start_ts ))
  echo "$wall_secs" > "$out_dir/wall_secs.txt"

  # Pull workspace contents back as tarball
  limactl shell "$vm" bash -lc "
    cd $vm_workdir
    tar --exclude='.venv' --exclude='__pycache__' --exclude='.pytest_cache' -czf /tmp/$label.tar.gz .
  "
  limactl shell "$vm" cat /tmp/$label.tar.gz > "$out_dir/workspace.tar.gz"

  # For wrap mode: grab headroom perf summary
  if [[ "$mode" == "wrap" ]]; then
    limactl shell "$vm" bash -lc "export PATH=\"\$HOME/.local/bin:\$PATH\"; headroom perf --json 2>/dev/null || headroom perf 2>/dev/null" > "$out_dir/headroom_perf.txt" 2>&1 || true
  fi

  # Parse summary from JSONL
  python3 - <<PY > "$out_dir/summary.json"
import json, datetime
total_in = total_cached = total_out = total_reason = turns = 0
tool_calls = web_searches = agent_msgs = 0
with open("$out_dir/events.jsonl") as f:
    for line in f:
        try:
            ev = json.loads(line)
        except Exception:
            continue
        t = ev.get("type")
        if t == "turn.completed":
            turns += 1
            u = ev.get("usage", {})
            total_in += u.get("input_tokens", 0)
            total_cached += u.get("cached_input_tokens", 0)
            total_out += u.get("output_tokens", 0)
            total_reason += u.get("reasoning_output_tokens", 0)
        elif t == "item.completed":
            it = ev.get("item", {})
            it_type = it.get("type")
            if it_type == "command_execution":
                tool_calls += 1
                cmd = it.get("command", "")
                if "web_search" in cmd or "websearch" in cmd:
                    web_searches += 1
            elif it_type == "web_search":
                web_searches += 1
                tool_calls += 1
            elif it_type == "agent_message":
                agent_msgs += 1
print(json.dumps({
    "mode": "$mode",
    "trial": $trial_num,
    "timestamp_utc": datetime.datetime.utcnow().isoformat() + "Z",
    "wall_secs": $wall_secs,
    "turns": turns,
    "tool_calls": tool_calls,
    "web_searches": web_searches,
    "agent_messages": agent_msgs,
    "input_tokens": total_in,
    "cached_input_tokens": total_cached,
    "fresh_input_tokens": total_in - total_cached,
    "output_tokens": total_out,
    "reasoning_output_tokens": total_reason,
    "total_billed_tokens": (total_in - total_cached) + total_out + total_reason
}, indent=2))
PY

  echo "Trial $trial_num ($mode) done in ${wall_secs}s"
  cat "$out_dir/summary.json"
}

# Alternating order spreads time-of-day API variance fairly
ORDER=(vanilla wrap vanilla wrap vanilla wrap)

# Optionally run only specific trials:  ./orchestrate.sh 1 2   (runs only trials 1 and 2)
TRIALS=("$@")
if [[ ${#TRIALS[@]} -eq 0 ]]; then
  TRIALS=(1 2 3 4 5 6)
fi

for i in "${TRIALS[@]}"; do
  mode="${ORDER[$((i-1))]}"
  run_trial "$i" "$mode"
  # Commit after every trial so we never lose data if the next one blows up.
  cd "$REPO_ROOT"
  git add "runs/run-$i-$mode" 2>/dev/null || true
  git commit -m "Trial $i ($mode): $(cat runs/run-$i-$mode/wall_secs.txt 2>/dev/null || echo '?')s wall" --allow-empty -q || true
done

echo ""
echo "============================================================"
echo " RUN COMPLETE for trials: ${TRIALS[*]}"
echo "============================================================"
ls -la "$RUNS_DIR"

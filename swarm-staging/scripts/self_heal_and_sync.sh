#!/usr/bin/env bash
# self_heal_and_sync.sh
# Performs periodic self-healing for Infinity-X One:
#  - Launch ngrok if not running
#  - Validate local/cloud/gateway health
#  - Re-hydrate and sync memory if drift detected
# -------------------------------------------------------------

set -euo pipefail
LOG="$HOME/infinity-x-one-swarm/memory-gateway/SELF_HEAL_LOG.txt"
NGROK_BIN="$(command -v ngrok || true)"
NGROK_CFG="$HOME/.config/ngrok/ngrok.yml"

echo "🩺 [$(date -u)] Starting Infinity-X One self-healing cycle..." | tee -a "$LOG"

# --- Ensure ngrok tunnel ------------------------------------------------------
if [[ -n "$NGROK_BIN" ]]; then
  if ! pgrep -x ngrok >/dev/null; then
    echo "🌐 Starting ngrok tunnel..." | tee -a "$LOG"
    nohup "$NGROK_BIN" http 8080 --config "$NGROK_CFG" >"$HOME/ngrok.log" 2>&1 &
    sleep 10
  else
    echo "✅ ngrok already running." | tee -a "$LOG"
  fi
else
  echo "⚠️ ngrok binary not found; skipping tunnel startup." | tee -a "$LOG"
fi

# --- Health checks ------------------------------------------------------------
declare -A ENDPOINTS=(
  ["Local Agent"]="http://localhost:8080/health"
  ["Memory Gateway"]="https://memory-gateway-ru6asaa7vq-ue.a.run.app/health"
  ["Cloud Agent"]="https://infinity-agent-938446344277.us-east1.run.app/health"
)

for name in "${!ENDPOINTS[@]}"; do
  url="${ENDPOINTS[$name]}"
  if curl -fsS -m 10 "$url" >/dev/null; then
    echo "✅ $name healthy." | tee -a "$LOG"
  else
    echo "⚠️ $name unreachable — attempting recovery." | tee -a "$LOG"
    if [[ "$name" == "Memory Gateway" ]]; then
      bash "$HOME/infinity-x-one-swarm/scripts/memory_hydration.sh" || true
    elif [[ "$name" == "Local Agent" ]]; then
      systemctl restart infinity-agent.service 2>/dev/null || true
    elif [[ "$name" == "Cloud Agent" ]]; then
      echo "⚙️ Trigger cloud sync placeholder (manual or API)." | tee -a "$LOG"
    fi
  fi
done

# --- Verify state integrity ---------------------------------------------------
bash "$HOME/infinity-x-one-swarm/scripts/verify_system_state_integrity.sh" || true

# --- Sync memory if drift detected -------------------------------------------
if grep -q "mismatch" "$HOME/infinity-x-one-swarm/memory-gateway/STATE_INTEGRITY_LOG.txt"; then
  echo "🔁 Drift detected — re-syncing memory..." | tee -a "$LOG"
  bash "$HOME/infinity-x-one-swarm/scripts/sync_system_state.sh" || true
fi

echo "🧠 [$(date -u)] Self-healing cycle complete." | tee -a "$LOG"

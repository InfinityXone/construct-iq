#!/usr/bin/env bash
#
# sync_system_state.sh
# Syncs system_state.yaml with the Infinity-X One Memory Gateway
# and logs the result locally.
#
# ------------------------------------------------------------------

set -euo pipefail

# Configuration
STATE_FILE="$HOME/infinity-x-one-swarm/system_state.yaml"
MEMORY_GATEWAY_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
LOG_FILE="$HOME/infinity-x-one-swarm/memory-gateway/STATE_SYNC_LOG.txt"
AUTH_HEADER="Authorization: Bearer $(cat $HOME/.infinity-agent/.env 2>/dev/null | grep BASIC_AUTH_PASS | cut -d'=' -f2)"

echo "🔄 [$(date -u)] Starting system state sync..." | tee -a "$LOG_FILE"

if [ ! -f "$STATE_FILE" ]; then
  echo "❌ system_state.yaml not found at $STATE_FILE" | tee -a "$LOG_FILE"
  exit 1
fi

if curl -fsS -H "Content-Type: application/json" \
     -X POST \
     -d "{\"key\":\"system_state\",\"value\":\"$(base64 -w0 $STATE_FILE)\",\"agent_id\":\"infinity-x-one\"}" \
     "$MEMORY_GATEWAY_URL/memory/remember" > /dev/null; then
  echo "✅ [$(date -u)] State sync successful." | tee -a "$LOG_FILE"
else
  echo "⚠️ [$(date -u)] State sync failed!" | tee -a "$LOG_FILE"
fi

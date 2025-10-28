#!/usr/bin/env bash
#
# recall_system_state.sh
# Retrieves and verifies the stored system_state blueprint
# from the Infinity-X One Memory Gateway.
# -------------------------------------------------------------

set -euo pipefail

STATE_FILE="$HOME/infinity-x-one-swarm/system_state_restored.yaml"
MEMORY_GATEWAY_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
LOG_FILE="$HOME/infinity-x-one-swarm/memory-gateway/STATE_RECALL_LOG.txt"

echo "🧠 [$(date -u)] Requesting stored system_state..." | tee -a "$LOG_FILE"

# Fetch the encoded value
response=$(curl -fsS -H "Content-Type: application/json" \
  -X POST -d '{"key":"system_state"}' \
  "$MEMORY_GATEWAY_URL/memory/recall")

if [[ -z "$response" ]]; then
  echo "❌ No response or empty payload from Memory Gateway." | tee -a "$LOG_FILE"
  exit 1
fi

# Extract and decode the value
encoded_value=$(echo "$response" | jq -r '.value' 2>/dev/null || echo "")
if [[ "$encoded_value" == "null" || -z "$encoded_value" ]]; then
  echo "⚠️  system_state not found in Memory Gateway." | tee -a "$LOG_FILE"
  exit 1
fi

echo "$encoded_value" | base64 --decode > "$STATE_FILE"
echo "✅ [$(date -u)] State recalled and written to $STATE_FILE" | tee -a "$LOG_FILE"
echo "📦 Log saved to $LOG_FILE"

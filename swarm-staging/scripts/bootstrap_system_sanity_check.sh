#!/usr/bin/env bash
#
# bootstrap_system_sanity_check.sh
# Validates endpoints, service health, and manifest consistency for Infinity-X One.
# -------------------------------------------------------------

set -euo pipefail

MANIFEST="$HOME/infinity-x-one-swarm/infinity_system_manifest.yaml"
LOG="$HOME/infinity-x-one-swarm/memory-gateway/SYSTEM_SANITY_LOG.txt"

echo "🧠 [$(date -u)] Starting Infinity-X One system sanity check..." | tee -a "$LOG"

if [[ ! -f "$MANIFEST" ]]; then
  echo "❌ Manifest not found: $MANIFEST" | tee -a "$LOG"
  exit 1
fi

# Extract URLs and key info
CLOUD_URL=$(grep "cloud_agent:" -A 3 "$MANIFEST" | grep url | awk '{print $2}' | tr -d '"')
MEM_URL=$(grep "memory_gateway:" -A 3 "$MANIFEST" | grep url | awk '{print $2}' | tr -d '"')
LOCAL_URL=$(grep "local_agent:" -A 3 "$MANIFEST" | grep url | awk '{print $2}' | tr -d '"')

echo "🌐 Checking endpoints..." | tee -a "$LOG"

declare -A ENDPOINTS=(
  ["Local Agent"]="$LOCAL_URL/health"
  ["Cloud Agent"]="$CLOUD_URL/health"
  ["Memory Gateway"]="$MEM_URL/health"
)

for name in "${!ENDPOINTS[@]}"; do
  url="${ENDPOINTS[$name]}"
  echo "🔗 Testing $name → $url" | tee -a "$LOG"
  if curl -fsS -m 10 "$url" > /dev/null; then
    echo "✅ $name reachable." | tee -a "$LOG"
  else
    echo "⚠️  $name not reachable." | tee -a "$LOG"
  fi
done

echo "🧩 Checking local systemd units..." | tee -a "$LOG"
systemctl is-active --quiet memory-autonomy-cycle.service && echo "✅ memory-autonomy-cycle.service active" | tee -a "$LOG" || echo "⚠️ memory-autonomy-cycle.service inactive" | tee -a "$LOG"
systemctl is-active --quiet memory-autonomy-cycle.timer && echo "✅ memory-autonomy-cycle.timer active" | tee -a "$LOG" || echo "⚠️ memory-autonomy-cycle.timer inactive" | tee -a "$LOG"

echo "🧬 Verifying integrity hash..." | tee -a "$LOG"
HASH=$(grep "last_checksum" "$MANIFEST" | awk '{print $2}' | tr -d '"')
FILE="$HOME/infinity-x-one-swarm/system_state.yaml"
if [[ -f "$FILE" ]]; then
  CURRENT_HASH=$(sha256sum "$FILE" | awk '{print $1}')
  if [[ "$HASH" == "$CURRENT_HASH" ]]; then
    echo "✅ State file checksum matches manifest." | tee -a "$LOG"
  else
    echo "⚠️ State checksum mismatch! Possible drift." | tee -a "$LOG"
  fi
else
  echo "⚠️ State file missing!" | tee -a "$LOG"
fi

echo "🪶 [$(date -u)] Sanity check complete. Log: $LOG"

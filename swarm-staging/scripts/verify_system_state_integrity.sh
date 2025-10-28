#!/usr/bin/env bash
#
# verify_system_state_integrity.sh
# Compares the original system_state.yaml with the recalled copy
# to ensure data integrity and detect drift or corruption.
# -------------------------------------------------------------

set -euo pipefail

ORIGINAL="$HOME/infinity-x-one-swarm/system_state.yaml"
RESTORED="$HOME/infinity-x-one-swarm/system_state_restored.yaml"
LOG_FILE="$HOME/infinity-x-one-swarm/memory-gateway/STATE_INTEGRITY_LOG.txt"

echo "🔍 [$(date -u)] Verifying system state integrity..." | tee -a "$LOG_FILE"

# Check if both files exist
if [[ ! -f "$ORIGINAL" || ! -f "$RESTORED" ]]; then
  echo "❌ Missing one or both state files." | tee -a "$LOG_FILE"
  exit 1
fi

# Generate checksums
orig_sum=$(sha256sum "$ORIGINAL" | awk '{print $1}')
rest_sum=$(sha256sum "$RESTORED" | awk '{print $1}')

echo "Original checksum: $orig_sum" | tee -a "$LOG_FILE"
echo "Restored checksum: $rest_sum" | tee -a "$LOG_FILE"

# Compare
if [[ "$orig_sum" == "$rest_sum" ]]; then
  echo "✅ [$(date -u)] Integrity verified: system state files match perfectly." | tee -a "$LOG_FILE"
else
  echo "⚠️  [$(date -u)] Integrity check failed: drift or corruption detected!" | tee -a "$LOG_FILE"
  diff -u "$ORIGINAL" "$RESTORED" | tee -a "$LOG_FILE" || true
fi

echo "📦 Log saved to $LOG_FILE"

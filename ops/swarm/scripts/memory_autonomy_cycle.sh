#!/usr/bin/env bash
#
# memory_autonomy_cycle.sh
# Executes a full autonomous cognitive loop for Infinity-X One:
# 1. Sync current system state to Memory Gateway
# 2. Recall stored state
# 3. Verify integrity
# -------------------------------------------------------------

set -euo pipefail

CYCLE_LOG="$HOME/infinity-x-one-swarm/memory-gateway/MEMORY_AUTONOMY_CYCLE_LOG.txt"

echo "🌀 [$(date -u)] Starting Infinity Memory Autonomy Cycle..." | tee -a "$CYCLE_LOG"

# Step 1️⃣ Sync current state
echo "🧩 Step 1: Sync system state..." | tee -a "$CYCLE_LOG"
if "$HOME/infinity-x-one-swarm/scripts/sync_system_state.sh"; then
  echo "✅ Sync complete." | tee -a "$CYCLE_LOG"
else
  echo "⚠️  Sync failed. Exiting cycle." | tee -a "$CYCLE_LOG"
  exit 1
fi

# Step 2️⃣ Recall stored state
echo "🧠 Step 2: Recall system state..." | tee -a "$CYCLE_LOG"
if "$HOME/infinity-x-one-swarm/scripts/recall_system_state.sh"; then
  echo "✅ Recall complete." | tee -a "$CYCLE_LOG"
else
  echo "⚠️  Recall failed. Exiting cycle." | tee -a "$CYCLE_LOG"
  exit 1
fi

# Step 3️⃣ Verify integrity
echo "🔍 Step 3: Verify state integrity..." | tee -a "$CYCLE_LOG"
if "$HOME/infinity-x-one-swarm/scripts/verify_system_state_integrity.sh"; then
  echo "✅ Integrity verification complete." | tee -a "$CYCLE_LOG"
else
  echo "⚠️  Integrity verification failed!" | tee -a "$CYCLE_LOG"
fi

echo "🪶 [$(date -u)] Memory Autonomy Cycle complete." | tee -a "$CYCLE_LOG"
echo "📜 Log saved to $CYCLE_LOG"

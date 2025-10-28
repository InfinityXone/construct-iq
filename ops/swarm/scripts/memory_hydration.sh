#!/bin/bash
# ==========================================
# 🧠 Infinity-X One — Memory Hydration Script
# ==========================================

SNAPSHOT_FILE=~/infinity-x-one-swarm/memory-gateway/state_snapshot.json
GATEWAY_URL=http://localhost:8090/memory/restore

echo "🔄 Beginning memory hydration..."
if [ -f "$SNAPSHOT_FILE" ]; then
  curl -s -X POST "$GATEWAY_URL" \
       -H "Content-Type: application/json" \
       -d @"$SNAPSHOT_FILE" \
       && echo "✅ Memory hydration completed successfully."
else
  echo "⚠️  No memory snapshot found at $SNAPSHOT_FILE"
fi

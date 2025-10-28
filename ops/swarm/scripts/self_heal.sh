#!/bin/bash
set -e
PROJECT_DIR="$HOME/infinity-x-one-swarm"
LOG="$PROJECT_DIR/SELFHEAL_LOG.txt"

echo "🩺 Running Self-Heal at $(date)" | tee "$LOG"
for m in orchestrator memory-gateway langchain-runtime visionary-agent strategist-agent financial-agent dashboard; do
  if [ ! -d "$PROJECT_DIR/$m" ]; then
    echo "🔧 Re-creating module: $m" | tee -a "$LOG"
    mkdir -p "$PROJECT_DIR/$m"
    echo "# $m recovered" > "$PROJECT_DIR/$m/README.md"
  fi
done
echo "✅ Self-Heal completed." | tee -a "$LOG"

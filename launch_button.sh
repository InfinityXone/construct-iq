#!/usr/bin/env bash
# launch_button.sh — Full Infinity Swarm launch from construct-iq root

set -euo pipefail

SWARM_DIR="$HOME/infinity-x-one-swarm"
DOC_MOVE_SCRIPT="$HOME/construct-iq/move_docs.sh"
LAUNCH_SCRIPT="$SWARM_DIR/launch_swarm_stack.sh"

echo "🔁 Syncing dev docs..."
bash "$DOC_MOVE_SCRIPT"

echo "🚀 Launching Infinity Swarm Stack..."
cd "$SWARM_DIR"
bash "$LAUNCH_SCRIPT"

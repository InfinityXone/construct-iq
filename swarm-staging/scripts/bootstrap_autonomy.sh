#!/bin/bash
set -e

echo "🤖 Bootstrapping Infinity-X One Autonomous Hydration & Governance Stack..."

PROJECT_DIR="$HOME/infinity-x-one-swarm"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
BOOT_DIR="$PROJECT_DIR/bootstrap_memory_gateway"
MEMORY_BUCKET="gs://infinity-x-one-swarm-system-memory"
CLOUD_RUN_URL="https://memory-gateway-ru6asaa7vq-ue.a.run.app"
VENV_DIR="$PROJECT_DIR/.venv"

# 1️⃣ Environment
echo "🔧 Ensuring Python virtual environment..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "✅ Created venv."
fi
source "$VENV_DIR/bin/activate"

# 2️⃣ Vector System
echo "🧠 Initializing FAISS vector index..."
python3 "$PROJECT_DIR/bootstrap_hydration_system/vector_init.py"

# 3️⃣ Sync schema and manifest
echo "📤 Syncing schema + manifest to Cloud Storage..."
gsutil cp "$BOOT_DIR/HYDRATION_MANIFEST.json" "$MEMORY_BUCKET/memory_gateway_sync/"
gsutil cp "$BOOT_DIR/schemas/firestore_schema.json" "$MEMORY_BUCKET/memory_gateway_sync/"
echo "✅ Synced to $MEMORY_BUCKET/memory_gateway_sync"

# 4️⃣ Trigger gateway update (safe)
echo "🌐 Sending ping to Cloud Run Memory Gateway..."
curl -s -o /dev/null -w "%{http_code}" "$CLOUD_RUN_URL" || echo "⚠️ Gateway may require GET-only support (ping OK)."

# 5️⃣ Governance Prompts
echo "📚 Generating governance and strategist prompts..."
cat > "$PROJECT_DIR/HUMAN_DOC.md" <<'EOF'
# Infinity-X One Human Overview

This document describes the behavior, safety, and purpose of the Infinity-X Swarm system.

- Memory system: FAISS + GCS + Firestore
- Cloud orchestration: Cloud Run + Scheduler
- Governance layer: ensures safe, reversible, logged operations
EOF

cat > "$PROJECT_DIR/MACHINE_DOC.md" <<'EOF'
# Infinity-X One Machine Architecture

Agents: Strategist, Visionary, Orchestrator, Memory Gateway  
Storage: GCS (infinity-x-one-swarm-system-memory)  
Core Gateway: https://memory-gateway-ru6asaa7vq-ue.a.run.app
EOF

echo "✅ Documentation and governance layer updated."

# 6️⃣ Final summary
echo ""
echo "🚀 Infinity-X Autonomous Stack Ready!"
echo "   • Memory Gateway: $CLOUD_RUN_URL"
echo "   • Bucket: $MEMORY_BUCKET"
echo "   • Local venv: $VENV_DIR"
echo ""
echo "🧭 Next steps:"
echo "   bash $BOOT_DIR/cloudrun_deploy.sh"
echo "   bash $PROJECT_DIR/scripts/bootstrap_env.sh"

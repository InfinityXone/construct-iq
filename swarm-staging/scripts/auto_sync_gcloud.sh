#!/bin/bash
set -e

echo "☁️ Infinity-X One Swarm — Full Auto Cloud + Repo Sync"

PROJECT_ID="infinity-x-one-swarm-system"
BUCKET="gs://infinity-x-one-swarm-system-memory"
REPO_DIR="$HOME/infinity-x-one-swarm"
BRANCH="main"

# 🧠 1️⃣ Sync manifests and schemas to Cloud Storage
echo "📤 Syncing manifests to GCS..."
gsutil -m rsync -r "$REPO_DIR/bootstrap_memory_gateway" "$BUCKET/memory_gateway_sync" || echo "⚠️ GCS sync skipped (bucket not found)."

# 🧬 2️⃣ GitHub commit and push
echo "🔁 Syncing codebase with GitHub..."
cd "$REPO_DIR"
git add .
git commit -m "♻️ Auto-hydration sync $(date +%F_%H-%M-%S)" || echo "ℹ️ No changes to commit."
git push origin "$BRANCH" || echo "⚠️ Git push skipped (no changes)."

# 🌐 3️⃣ Ping Cloud Run gateway
echo "🌐 Pinging Cloud Run Memory Gateway..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://memory-gateway-ru6asaa7vq-ue.a.run.app)
echo "   → Gateway responded with HTTP $HTTP_STATUS"

# 🌳 4️⃣ Update local repo tree snapshot
if [ -f "$REPO_DIR/scripts/treemd.sh" ]; then
  bash "$REPO_DIR/scripts/treemd.sh"
else
  echo "⚠️ treemd.sh not found, skipping tree snapshot."
fi

echo "✅ Auto Sync Complete — $(date)"
echo "   • Cloud: $BUCKET"
echo "   • Repo:  $REPO_DIR"
echo "   • Gateway: https://memory-gateway-ru6asaa7vq-ue.a.run.app"
